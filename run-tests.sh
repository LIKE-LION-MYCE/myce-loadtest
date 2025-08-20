#!/bin/bash
# MYCE 서버 로드테스트 도구
# k6 로드 제너레이터를 사용하여 성능 테스트 실행

set -e

# 색상 설정
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# k6 서버 설정
K6_SERVER="43.200.221.200"
SSH_KEY="keys/k6-loadtest-key"
SSH_USER="ubuntu"

# 스크립트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}"
echo "███╗   ███╗██╗   ██╗ ██████╗███████╗    ██╗      ██████╗  █████╗ ██████╗     ████████╗███████╗███████╗████████╗"
echo "████╗ ████║╚██╗ ██╔╝██╔════╝██╔════╝    ██║     ██╔═══██╗██╔══██╗██╔══██╗    ╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝"
echo "██╔████╔██║ ╚████╔╝ ██║     █████╗      ██║     ██║   ██║███████║██║  ██║       ██║   █████╗  ███████╗   ██║   "
echo "██║╚██╔╝██║  ╚██╔╝  ██║     ██╔══╝      ██║     ██║   ██║██╔══██║██║  ██║       ██║   ██╔══╝  ╚════██║   ██║   "
echo "██║ ╚═╝ ██║   ██║   ╚██████╗███████╗    ███████╗╚██████╔╝██║  ██║██████╔╝       ██║   ███████╗███████║   ██║   "
echo "╚═╝     ╚═╝   ╚═╝    ╚═════╝╚══════╝    ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝        ╚═╝   ╚══════╝╚══════╝   ╚═╝   "
echo -e "${NC}"
echo -e "${GREEN}MYCE API 성능 테스트 도구${NC}"
echo "========================================"

# 함수들
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# SSH 키 확인
check_ssh_key() {
    if [ ! -f "$SSH_KEY" ]; then
        print_error "SSH 키를 찾을 수 없습니다: $SSH_KEY"
        echo "README.md를 확인하여 SSH 키 설정을 완료해주세요."
        exit 1
    fi
    
    if [ ! -r "$SSH_KEY" ]; then
        print_error "SSH 키에 읽기 권한이 없습니다: $SSH_KEY"
        echo "chmod 600 $SSH_KEY 명령을 실행해주세요."
        exit 1
    fi
}

# k6 서버 연결 테스트
test_connection() {
    echo -n "k6 서버 연결 확인 중... "
    if ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$SSH_USER@$K6_SERVER" "echo 'OK'" > /dev/null 2>&1; then
        echo -e "${GREEN}연결됨${NC}"
        return 0
    else
        echo -e "${RED}연결 실패${NC}"
        print_error "k6 서버에 연결할 수 없습니다."
        echo "네트워크 연결과 SSH 키 설정을 확인해주세요."
        return 1
    fi
}

# 긴급 중단 함수
emergency_stop() {
    echo
    echo -e "${RED}🚨 긴급 중단 실행 중...${NC}"
    echo "모든 k6 프로세스를 종료합니다..."
    
    # k6 서버의 모든 k6 프로세스 강제 종료
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$K6_SERVER" "sudo pkill -f k6 || true"
    
    # 진행 중인 테스트가 있는지 확인
    local remaining=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$K6_SERVER" "pgrep -f k6 | wc -l" 2>/dev/null || echo "0")
    
    if [ "$remaining" -eq 0 ]; then
        print_status "모든 테스트가 성공적으로 중단되었습니다!"
        echo -e "${GREEN}💡 시스템 상태가 정상으로 돌아갑니다.${NC}"
    else
        print_warning "$remaining 개의 프로세스가 아직 실행 중입니다. 잠시 후 다시 시도해주세요."
    fi
}

# 테스트 실행 함수
run_test() {
    local test_script="$1"
    local description="$2"
    
    echo
    echo -e "${BLUE}🚀 $description 실행 중...${NC}"
    echo "스크립트: $test_script"
    echo "서버: $K6_SERVER"
    echo
    echo -e "${RED}⚠️  긴급 중단이 필요한 경우: 다른 터미널에서 './run-tests.sh --kill' 실행${NC}"
    echo
    
    # 실시간 대시보드 URL 표시
    echo -e "${PURPLE}📊 실시간 대시보드:${NC}"
    echo "   https://api.myce.live/dashboard/demo"
    echo
    
    # k6 서버에서 테스트 실행 (Grafana 통합 스크립트 사용)
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$K6_SERVER" "/home/ubuntu/run-test-grafana.sh $test_script"
    
    if [ $? -eq 0 ]; then
        print_status "테스트가 성공적으로 완료되었습니다!"
        echo
        echo -e "${BLUE}📈 결과 확인 방법:${NC}"
        echo "  • 실시간 대시보드: https://api.myce.live/dashboard/demo"
        echo "  • k6 전용 대시보드: https://api.myce.live/dashboard/performance"
        echo "  • 시스템 모니터링: https://api.myce.live/dashboard/ec2"
    else
        print_error "테스트 실행 중 오류가 발생했습니다."
    fi
}

# 결과 조회 함수
view_results() {
    echo -e "${BLUE}📊 최근 테스트 결과 조회 중...${NC}"
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$K6_SERVER" "cd /home/ubuntu/k6-results && ls -lt *.json 2>/dev/null | head -5 && echo && echo '📈 최신 결과:' && ls -lt *summary.json 2>/dev/null | head -1 | awk '{print \$NF}' | xargs cat 2>/dev/null | jq '.metrics.http_req_duration, .metrics.http_req_failed, .metrics.checks' 2>/dev/null || echo '결과 파일을 찾을 수 없습니다.'"
}

# 메인 메뉴
show_menu() {
    while true; do
        echo
        echo -e "${BLUE} 테스트 메뉴를 선택하세요:${NC}"
        echo
        echo -e "${GREEN}=== REALISTIC TESTS (인증 + 실제 사용자 시나리오) ===${NC}"
        echo "1. Realistic 스모크 테스트 (JWT 인증 + API 테스트, 30초)"
        echo "   └─ VU: 1명 | 시간: 30초 | 패턴: 로그인→프로필→헬스체크→박람회목록"
        echo "   └─ 임계값: 실패율<10%, 95%<1초, 체크성공률>95%"
        echo
        echo "2. Realistic 데모 테스트 (혼합 사용자 여정, 15분)"
        echo "   └─ VU: 5→15→25→35→0명 점진적 | 시간: 15분"
        echo "   └─ 패턴: 브라우저(40%), 회원(35%), 헤비유저(20%), 관리자체크(5%)"
        echo "   └─ 임계값: 실패율<15%, 95%<3초, 체크성공률>85%"
        echo
        echo "3. Realistic 로드 테스트 (지속적 인증 사용자, 20분)"
        echo "   └─ VU: 20→50→100→150→0명 점진적 | 시간: 20분"
        echo "   └─ 패턴: JWT 토큰 캐싱, 다중페이지 브라우징, 시스템 모니터링"
        echo "   └─ 임계값: 실패율<20%, 95%<4초, 체크성공률>80%"
        echo
        echo "4. Realistic 스파이크 테스트 (인증 스트레스, 4분)"
        echo "   └─ VU: 20→200(10배 급증)→20명 | 시간: 4분"
        echo "   └─ 패턴: 인증 부하테스트, 코어 엔드포인트 집중, 보호된 API 접근"
        echo "   └─ 임계값: 실패율<40%, 90%<5초, 체크성공률>60%"
        echo
        echo -e "${YELLOW}=== BASIC TESTS (단순 헬스체크용) ===${NC}"
        echo "5. Basic 스케일링 테스트 (헬스체크만, 15분)"
        echo "   └─ VU: 1→10→25→50→100→0명 점진적 | 시간: 15분"
        echo "   └─ 패턴: /actuator/health, /info, /metrics 엔드포인트만"
        echo "   └─ 임계값: 실패율<10%, 95%<2초"
        echo
        echo "6. Basic 스파이크 테스트 (헬스체크만, 4분)"
        echo "   └─ VU: 50→2000(40배 급증)→50명 | 시간: 4분"
        echo "   └─ 패턴: /actuator/health 단일 엔드포인트, 최소 대기시간(0.1초)"
        echo "   └─ 임계값: 실패율<30%, 90%<3초"
        echo
        echo -e "${BLUE}=== 도구 ===${NC}"
        echo "7. 📊 실시간 대시보드 열기"
        echo "8. 📈 최근 테스트 결과 보기"
        echo "9. 🚨 긴급 중단 (모든 테스트 강제 종료)"
        echo "10. ❌ 종료"
        echo
        read -p "선택하세요 (1-10): " choice
        
        case $choice in
            1)
                run_test "realistic-smoke.js" "Realistic 스모크 테스트 (JWT 인증)"
                ;;
            2)
                run_test "realistic-demo.js" "Realistic 데모 테스트 (혼합 사용자 시나리오)"
                ;;
            3)
                run_test "realistic-load.js" "Realistic 로드 테스트 (인증된 사용자들)"
                ;;
            4)
                run_test "realistic-spike.js" "Realistic 스파이크 테스트 (인증 스트레스)"
                ;;
            5)
                run_test "demo-scaling.js" "Basic 스케일링 테스트 (헬스체크)"
                ;;
            6)
                run_test "spike-test.js" "Basic 스파이크 테스트 (헬스체크)"
                ;;
            7)
                echo -e "${PURPLE}📊 브라우저에서 다음 URL을 열어주세요:${NC}"
                echo "   https://api.myce.live/dashboard/demo"
                echo
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            8)
                view_results
                ;;
            9)
                emergency_stop
                ;;
            10)
                echo -e "${GREEN}테스트 도구를 종료합니다.${NC}"
                exit 0
                ;;
            *)
                print_warning "올바른 번호를 선택해주세요 (1-10)."
                ;;
        esac
    done
}

# 메인 실행
main() {
    # 명령행 파라미터 처리
    if [ "$1" == "--kill" ] || [ "$1" == "-k" ]; then
        check_ssh_key
        emergency_stop
        exit 0
    fi
    
    # 사전 확인
    check_ssh_key
    
    echo -e "${YELLOW}시스템 상태 확인 중...${NC}"
    if ! test_connection; then
        exit 1
    fi
    
    print_status "모든 시스템이 정상입니다!"
    
    # 메뉴 표시
    show_menu
}

# 스크립트 실행
main "$@"
