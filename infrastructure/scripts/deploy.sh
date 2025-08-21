#!/bin/bash
# MYCE EKS Demo Deployment Script

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
K8S_DIR="$SCRIPT_DIR/../k8s"

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check prerequisites
check_prereqs() {
    print_info "사전 요구사항 확인 중..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI가 설치되지 않았습니다. 먼저 AWS CLI를 설치해주세요."
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl이 설치되지 않았습니다. 먼저 kubectl을 설치해주세요."
    fi
    
    # Check terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform이 설치되지 않았습니다. 먼저 Terraform을 설치해주세요."
    fi
    
    # Check AWS credentials
    export AWS_PROFILE="likelion-terraform-current"
    if ! aws sts get-caller-identity --profile likelion-terraform-current &> /dev/null; then
        print_error "AWS 자격증명이 설정되지 않았습니다. likelion-terraform-current 프로필을 확인해주세요."
    fi
    
    print_status "모든 사전 요구사항이 충족되었습니다!"
}

# Deploy EKS infrastructure
deploy_infrastructure() {
    print_info "🏗️  EKS + Docker 하이브리드 인프라 배포 중..."
    print_info "구성: Docker Backend + 3-node EKS (자동 6노드로 확장 가능)"
    print_info "예상 소요시간: 8-12분"
    print_info "예상 비용: ~$6.36/일 (EKS: $2.40 + 노드: $2.88 + NAT: $1.08)"
    
    cd "$TERRAFORM_DIR"
    
    # Check Docker backend health
    print_info "Docker 백엔드 상태 확인 중..."
    if curl -s -f https://api.myce.live/actuator/health > /dev/null; then
        print_status "Docker 백엔드가 정상 작동 중입니다"
    else
        print_warning "Docker 백엔드가 응답하지 않습니다. 하이브리드 라우팅이 제한될 수 있습니다."
    fi
    
    # Initialize Terraform
    print_info "Terraform 초기화 중..."
    terraform init -upgrade
    terraform validate
    
    # Show what will be created
    print_info "인프라 배포 계획:"
    echo "  ✅ EKS Cluster (1.28)"
    echo "  ✅ 3x t3.medium Spot nodes (always-on)"
    echo "  ✅ NAT Gateway (private subnet internet access)"
    echo "  ✅ Hybrid Target Group (Docker + EKS pods)"
    echo "  ✅ ALB routing (equal traffic distribution)"
    
    # Apply infrastructure
    print_info "🚧 인프라 생성 중..."
    terraform apply -auto-approve
    
    # Get kubectl config
    print_info "kubectl 설정 업데이트 중..."
    CLUSTER_NAME=$(terraform output -raw cluster_id)
    aws eks --region ap-northeast-2 update-kubeconfig --name "$CLUSTER_NAME" --profile likelion-terraform-current
    
    print_status "🎯 하이브리드 인프라가 성공적으로 배포되었습니다!"
    
    # Show infrastructure status
    print_info "📊 인프라 상태:"
    echo "  • EKS Cluster: $(terraform output -raw cluster_id) ($(terraform output -raw node_group_status))"
    echo "  • Docker Backend: 등록됨 ($(terraform output -raw docker_registered))"
    echo "  • NAT Gateway IP: $(terraform output -raw nat_gateway_ip)"
    echo "  • Hybrid Target Group: $(terraform output -raw hybrid_target_group_arn)"
}

# Wait for nodes to be ready
wait_for_nodes() {
    print_info "EKS 노드가 준비될 때까지 대기 중..."
    
    while true; do
        READY_NODES=$(kubectl get nodes --no-headers | grep -c "Ready" || echo "0")
        if [ "$READY_NODES" -gt 0 ]; then
            print_status "$READY_NODES개의 노드가 준비되었습니다!"
            break
        fi
        print_info "노드 준비 중... 30초 후 다시 확인합니다."
        sleep 30
    done
}

# Deploy MYCE application
deploy_application() {
    print_info "MYCE 애플리케이션 배포 중..."
    
    cd "$K8S_DIR"
    
    # Install AWS Load Balancer Controller via Helm
    print_info "📦 AWS Load Balancer Controller 설치 중..."
    
    # Add EKS Helm repo if not exists
    helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
    helm repo update
    
    # Install AWS Load Balancer Controller
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
      -n kube-system \
      --set clusterName=myce-demo-eks \
      --set serviceAccount.create=true \
      --set serviceAccount.name=aws-load-balancer-controller \
      --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::155669502936:role/myce-aws-load-balancer-controller" \
      --wait
    
    # Apply Kubernetes manifests
    print_info "Kubernetes 매니페스트 적용 중..."
    kubectl apply -f myce-deployment.yaml
    kubectl apply -f myce-hpa.yaml
    
    # Apply Prometheus monitoring (if ServiceMonitor CRD exists)
    if kubectl get crd servicemonitors.monitoring.coreos.com &> /dev/null; then
        print_info "ServiceMonitor CRD 발견됨 - Prometheus auto-discovery 설정 중..."
        kubectl apply -f prometheus-servicemonitor.yaml
    else
        print_warning "ServiceMonitor CRD가 없습니다. 수동 Prometheus 설정이 필요합니다."
        print_info "설정 파일: infrastructure/k8s/prometheus-k8s-config.yml 참조"
    fi
    
    # Wait for controller to be ready, then apply TargetGroupBinding
    sleep 10
    kubectl apply -f aws-load-balancer-controller.yaml
    
    print_status "MYCE 애플리케이션이 배포되었습니다!"
}

# Wait for application to be ready
wait_for_application() {
    print_info "MYCE 애플리케이션이 준비될 때까지 대기 중..."
    
    kubectl wait --for=condition=available --timeout=600s deployment/myce-server
    
    # Get Load Balancer URL
    print_info "로드 밸런서 URL 확인 중..."
    while true; do
        LB_URL=$(kubectl get service myce-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$LB_URL" ]; then
            print_status "로드 밸런서 URL: http://$LB_URL"
            echo -e "${GREEN}🌐 애플리케이션 접속: http://$LB_URL${NC}"
            break
        fi
        print_info "로드 밸런서 생성 중... 30초 후 다시 확인합니다."
        sleep 30
    done
}

# Show cluster status
show_status() {
    print_info "EKS 클러스터 상태:"
    echo ""
    
    echo "📋 노드 상태:"
    kubectl get nodes -o wide
    echo ""
    
    echo "🚀 파드 상태:"
    kubectl get pods -o wide
    echo ""
    
    echo "⚖️  HPA 상태:"
    kubectl get hpa
    echo ""
    
    echo "🌐 서비스 상태:"
    kubectl get services
    echo ""
    
    print_status "EKS 클러스터가 성공적으로 실행 중입니다!"
    echo ""
    echo -e "${YELLOW}📊 대시보드에서 실시간 모니터링:${NC}"
    echo "   https://api.myce.live/dashboard/demo"
    echo ""
    echo -e "${YELLOW}🧪 로드 테스트 실행:${NC}"
    echo "   ./run-tests.sh"
    echo "   메뉴에서 '11. EKS 점진적 데모' 선택"
}

# Main deployment process
main() {
    echo -e "${BLUE}"
    echo "🚀 MYCE EKS 데모 클러스터 배포"
    echo "=================================="
    echo -e "${NC}"
    
    check_prereqs
    deploy_infrastructure
    wait_for_nodes
    deploy_application
    wait_for_application
    show_status
    
    echo ""
    print_status "🎉 EKS 데모 환경이 완전히 준비되었습니다!"
    echo -e "${YELLOW}💰 비용 절약 tip: 사용 후 './cleanup.sh'로 클러스터를 삭제하세요!${NC}"
}

# Run main function
main "$@"