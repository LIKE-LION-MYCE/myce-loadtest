# MYCE 로드 테스트 도구

MYCE API 서버의 성능을 테스트하기 위한 k6 로드 테스트 도구입니다.

## 시작

```bash
# 1. SSH 키 설정 (아래 참조)
# 2. 테스트 실행
./run-tests.sh
```

## 테스트 종류

### 데모 스케일링 테스트 (15분)
- **목적**: 프레젠테이션용 점진적 부하 증가
- **패턴**: 1→10→25→50→100 VU
- **시간**: 15분
- **적합한 상황**: 데모, 발표, 시스템 스케일링 시나리오 보여주기

### 스모크 테스트 (30초)
- **목적**: 기본 상태 확인
- **패턴**: 1 VU
- **시간**: 30초
- **적합한 상황**: 배포 후 빠른 상태 확인, CI/CD 파이프라인

### 로드 테스트 (16분)
- **목적**: 본격적인 부하 테스트
- **패턴**: 1→100→200 VU
- **시간**: 16분
- **적합한 상황**: 성능 한계 파악, 용량 계획

### 스파이크 테스트 (4분)
- **목적**: 급격한 트래픽 증가 대응 능력
- **패턴**: 50→2000 VU 급증
- **시간**: 4분
- **적합한 상황**: 바이럴 콘텐츠, 플래시 세일 등 트래픽 폭증 대비

## SSH 키 설정

SSH 키는 `loadtest/keys/` 디렉토리에 포함되어 있습니다.

```bash
# SSH 키 권한 설정
chmod 600 loadtest/keys/k6-loadtest-key
```

## 대시보드 URL

### 실시간 모니터링
- **데모 대시보드**: https://api.myce.live/dashboard/demo
- **k6 전용**: https://api.myce.live/dashboard/performance  
- **시스템 모니터링**: https://api.myce.live/dashboard/ec2

### 직접 접속 (내부용)
- **Grafana**: http://15.164.128.42:3000 (admin/grafana123)
- **Prometheus**: http://15.164.128.42:9090

## 긴급 중단

테스트 중 시스템 부하가 과도하거나 문제가 발생할 경우:

### 명령행에서 즉시 중단
```bash
./run-tests.sh --kill
# 또는
./run-tests.sh -k
```

### 메뉴에서 중단
```bash
./run-tests.sh
# 메뉴에서 "7. 🚨 긴급 중단" 선택
```

### 수동 중단 (최후 수단)
```bash
# k6 서버에 직접 접속하여 프로세스 종료
ssh -i keys/k6-loadtest-key ubuntu@43.200.221.200
sudo pkill -f k6
```

## 사용 시나리오

### 개발자
```bash
# 코드 변경 후 빠른 확인
./run-tests.sh
# 메뉴에서 "2. 스모크 테스트" 선택
```

### QA 엔지니어
```bash
# 성능 검증
./run-tests.sh  
# 메뉴에서 "3. 로드 테스트" 선택
```

### 프로덕트 매니저/데모
```bash
# 스케일링 스토리 시연
./run-tests.sh
# 메뉴에서 "1. 데모 스케일링 테스트" 선택
# 브라우저에서 https://api.myce.live/dashboard/demo 열기
```

### DevOps/인프라 팀
```bash
# 시스템 한계 테스트
./run-tests.sh
# 메뉴에서 "4. 스파이크 테스트" 선택
```

## 📁 디렉토리 구조

```
loadtest/
├── scripts/           # k6 테스트 스크립트
│   ├── demo-scaling.js
│   ├── smoke-test.js
│   ├── load-test.js
│   └── spike-test.js
├── keys/              # SSH 키 (gitignore 처리됨)
│   └── k6-loadtest-key
├── run-tests.sh       # 메인 테스트 실행 스크립트
└── README.md         # 이 파일
```

## 문제 해결

### SSH 연결 실패
```bash
# 키 권한 확인
chmod 600 keys/k6-loadtest-key

# 연결 테스트
ssh -i keys/k6-loadtest-key ubuntu@43.200.221.200 "echo 'OK'"
```

### 대시보드 접속 안됨
- 브라우저에서 https://api.myce.live/dashboard/demo 직접 접속
- VPN 연결 상태 확인
- 네트워크 방화벽 설정 확인

### 테스트 결과가 안보임
```bash
# k6 서버에 직접 접속하여 확인
ssh -i keys/k6-loadtest-key ubuntu@43.200.221.200
cd k6-results
ls -la
```

## 메트릭 해석

### 응답 시간
- **p95**: 사용자의 95%가 경험하는 최대 응답 시간
- **p99**: 사용자의 99%가 경험하는 최대 응답 시간
- **평균**: 전체 요청의 평균 응답 시간

### 성공률
- **100%**: 모든 요청 성공 (이상적)
- **95% 이상**: 양호
- **90% 미만**: 문제 있음, 조사 필요

### Virtual Users (VU)
- **현재 활성 사용자 수**
- 실제 동시 접속자를 시뮬레이션

## 주의사항

1. **프로덕션 서버에 주의**: 현재 설정은 프로덕션 API(api.myce.live)를 대상으로 합니다.
2. **적절한 시간 선택**: 사용자가 많은 시간대는 피해주세요.
3. **리소스 모니터링**: 테스트 중 서버 리소스 사용량을 모니터링해주세요.
4. **SSH 키 보안**: SSH 키를 안전하게 관리하고 공유하지 마세요.

## 개선하기

새로운 테스트 시나리오가 필요하거나 개선사항이 있으면:
1. `scripts/` 디렉토리에 새로운 .js 파일 추가
2. `run-tests.sh`의 메뉴에 새 옵션 추가
3. 이 README.md 업데이트

---

**Made by Juan for MYCE Team**