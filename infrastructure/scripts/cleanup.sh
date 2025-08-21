#!/bin/bash
# MYCE EKS Demo Cleanup Script
# Destroys EKS cluster to save costs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Confirmation prompt
confirm_deletion() {
    echo -e "${RED}"
    echo "⚠️  경고: EKS 클러스터를 완전히 삭제합니다!"
    echo "================================="
    echo "이 작업은 다음을 삭제합니다:"
    echo "- EKS 클러스터"
    echo "- 모든 워커 노드"
    echo "- 로드 밸런서"
    echo "- VPC 및 네트워킹 리소스"
    echo -e "${NC}"
    
    echo ""
    read -p "정말로 삭제하시겠습니까? (yes/no): " -r
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "작업이 취소되었습니다."
        exit 0
    fi
}

# Show current cluster status
show_current_status() {
    print_info "현재 EKS 클러스터 상태 확인 중..."
    
    cd "$TERRAFORM_DIR"
    
    if [ ! -f "terraform.tfstate" ]; then
        print_warning "Terraform 상태 파일을 찾을 수 없습니다. 클러스터가 이미 삭제되었을 수 있습니다."
        exit 0
    fi
    
    # Check if cluster exists
    CLUSTER_NAME=$(terraform output -raw cluster_id 2>/dev/null || echo "")
    if [ -z "$CLUSTER_NAME" ]; then
        print_warning "활성 클러스터를 찾을 수 없습니다."
        exit 0
    fi
    
    print_info "삭제할 클러스터: $CLUSTER_NAME"
    
    # Show current cost estimate
    echo ""
    print_info "💰 현재 시간당 예상 비용:"
    echo "   - EKS 제어판: $0.10/hour"
    echo "   - 워커 노드: ~$0.04-0.08/hour per node"
    echo "   - 로드 밸런서: ~$0.025/hour"
    echo ""
}

# Clean up Kubernetes resources first
cleanup_k8s_resources() {
    print_info "Kubernetes 리소스 정리 중..."
    
    # Update kubeconfig if needed
    CLUSTER_NAME=$(cd "$TERRAFORM_DIR" && terraform output -raw cluster_id 2>/dev/null || echo "")
    if [ -n "$CLUSTER_NAME" ]; then
        aws eks --region ap-northeast-2 update-kubeconfig --name "$CLUSTER_NAME" 2>/dev/null || true
        
        # Delete services (to remove load balancers)
        print_info "로드 밸런서 삭제 중..."
        kubectl delete services --all 2>/dev/null || true
        
        # Wait for load balancers to be deleted
        print_info "로드 밸런서 삭제 완료 대기 중..."
        sleep 30
    fi
    
    print_status "Kubernetes 리소스가 정리되었습니다!"
}

# Destroy Terraform infrastructure
destroy_infrastructure() {
    print_info "EKS 인프라 삭제 중... (약 10-15분 소요)"
    
    cd "$TERRAFORM_DIR"
    
    # Destroy infrastructure
    print_info "Terraform destroy 실행 중..."
    terraform destroy -auto-approve
    
    # Clean up terraform files
    print_info "Terraform 상태 파일 정리 중..."
    rm -f terraform.tfstate*
    rm -f .terraform.lock.hcl
    rm -rf .terraform/
    
    print_status "EKS 인프라가 완전히 삭제되었습니다!"
}

# Calculate cost savings
calculate_savings() {
    local hours_saved=${1:-24}
    local estimated_hourly_cost=0.15
    local daily_savings=$(echo "$estimated_hourly_cost * $hours_saved" | bc -l)
    
    echo ""
    print_status "💰 비용 절약 완료!"
    printf "   - 시간당 절약: $%.2f\n" $estimated_hourly_cost
    printf "   - 일일 절약 (24시간): $%.2f\n" $(echo "$estimated_hourly_cost * 24" | bc -l)
    printf "   - 주간 절약 (7일): $%.2f\n" $(echo "$estimated_hourly_cost * 24 * 7" | bc -l)
    echo ""
}

# Remove kubectl context
cleanup_kubectl() {
    print_info "kubectl 설정 정리 중..."
    
    # Remove cluster from kubeconfig
    CLUSTER_NAME="myce-demo-eks"
    kubectl config delete-context "arn:aws:eks:ap-northeast-2:*:cluster/$CLUSTER_NAME" 2>/dev/null || true
    kubectl config delete-cluster "arn:aws:eks:ap-northeast-2:*:cluster/$CLUSTER_NAME" 2>/dev/null || true
    kubectl config unset "users.arn:aws:eks:ap-northeast-2:*:cluster/$CLUSTER_NAME" 2>/dev/null || true
    
    print_status "kubectl 설정이 정리되었습니다!"
}

# Main cleanup process
main() {
    echo -e "${BLUE}"
    echo "🗑️  MYCE EKS 데모 클러스터 삭제"
    echo "================================"
    echo -e "${NC}"
    
    show_current_status
    confirm_deletion
    cleanup_k8s_resources
    destroy_infrastructure
    cleanup_kubectl
    calculate_savings
    
    echo ""
    print_status "🎉 EKS 클러스터가 완전히 삭제되었습니다!"
    echo ""
    print_info "다시 사용하려면:"
    echo "   ./deploy.sh"
    echo ""
    print_info "로드 테스트는 기존 EC2에서 계속 사용 가능합니다:"
    echo "   ./run-tests.sh"
}

# Check if bc is available for calculations
if ! command -v bc &> /dev/null; then
    print_warning "bc 계산기가 설치되지 않았습니다. 비용 계산을 건너뜁니다."
    calculate_savings() { echo ""; }
fi

# Run main function
main "$@"