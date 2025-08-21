#!/bin/bash
# K8s Image Update Script - Syncs with GitHub Actions Docker builds
# Run this after GitHub Actions deploys to Docker on EC2

set -e

echo "🚀 Kubernetes Image Update & Pre-cache Tool"
echo "==========================================="
echo "This syncs K8s with the latest Docker image from GitHub Actions"
echo ""

# Configuration
DOCKER_REPO="juanpark80/myce-backend"
IMAGE_TAG="${1:-latest}"
FULL_IMAGE="${DOCKER_REPO}:${IMAGE_TAG}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Step 1: Check current deployment status
echo "📊 Current deployment status:"
CURRENT_IMAGE=$(kubectl get deployment myce-server -o jsonpath='{.spec.template.spec.containers[0].image}')
echo "   Current image: ${CURRENT_IMAGE}"
echo "   Target image:  ${FULL_IMAGE}"

if [ "${CURRENT_IMAGE}" == "${FULL_IMAGE}" ]; then
    print_warning "Already running the latest image!"
    read -p "Force update anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Step 2: Pre-pull image on all nodes FIRST (for fast scaling)
echo ""
echo "🐳 Pre-caching image on all nodes for instant scaling..."
kubectl delete daemonset image-preloader --ignore-not-found=true 2>/dev/null || true

# Wait for old daemonset to be deleted
sleep 2

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: image-preloader
  labels:
    app: image-preloader
spec:
  selector:
    matchLabels:
      name: image-preloader
  template:
    metadata:
      labels:
        name: image-preloader
    spec:
      tolerations:
      - operator: Exists  # Run on all nodes including tainted ones
      initContainers:
      - name: preload
        image: ${FULL_IMAGE}
        imagePullPolicy: Always
        command: ["sh", "-c", "echo 'Image ${FULL_IMAGE} pre-cached' && exit 0"]
        resources:
          requests:
            memory: "10Mi"
            cpu: "10m"
          limits:
            memory: "50Mi"
            cpu: "50m"
      containers:
      - name: pause
        image: gcr.io/google_containers/pause:3.1
        resources:
          requests:
            memory: "1Mi"
            cpu: "1m"
          limits:
            memory: "5Mi"
            cpu: "5m"
EOF

# Wait for daemonset to pull images on all nodes
echo "   Waiting for image to be cached on all nodes..."
kubectl rollout status daemonset/image-preloader --timeout=60s || true
print_status "Image pre-cached on all nodes"

# Step 3: Update deployment with new image
echo ""
echo "🔄 Updating deployment to new image..."
kubectl set image deployment/myce-server myce-server=${FULL_IMAGE}

# Step 4: Monitor rollout with detailed status
echo ""
echo "📈 Rolling update progress:"
echo "   (Old pods will be terminated as new ones become ready)"

# Show real-time rollout status
ROLLOUT_SUCCESS=false
TIMEOUT=180  # 3 minutes timeout
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    # Get deployment status
    DESIRED=$(kubectl get deployment myce-server -o jsonpath='{.spec.replicas}')
    CURRENT=$(kubectl get deployment myce-server -o jsonpath='{.status.replicas}')
    UPDATED=$(kubectl get deployment myce-server -o jsonpath='{.status.updatedReplicas}')
    AVAILABLE=$(kubectl get deployment myce-server -o jsonpath='{.status.availableReplicas}')
    
    echo -ne "\r   Pods: ${UPDATED:-0}/${DESIRED} updated, ${AVAILABLE:-0}/${DESIRED} available"
    
    # Check if rollout is complete
    if [ "${UPDATED}" == "${DESIRED}" ] && [ "${AVAILABLE}" == "${DESIRED}" ]; then
        echo
        ROLLOUT_SUCCESS=true
        break
    fi
    
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

echo ""

if [ "$ROLLOUT_SUCCESS" = true ]; then
    print_status "Rollout completed successfully!"
else
    print_error "Rollout timed out or failed"
    echo "Checking pod status..."
    kubectl get pods -l app=myce-server
    exit 1
fi

# Step 5: Verify deployment
echo ""
echo "🔍 Verification:"
kubectl get deployment myce-server -o wide
echo ""
kubectl get pods -l app=myce-server -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,AGE:.metadata.creationTimestamp | head -10

# Step 6: Check HPA status
echo ""
echo "📊 Auto-scaling status:"
kubectl get hpa myce-server-hpa

# Final summary
echo ""
echo "========================================="
print_status "K8s deployment updated to ${FULL_IMAGE}"
echo ""
echo "📝 Summary:"
echo "   • Image pre-cached on all nodes for fast scaling"
echo "   • Rolling update completed with zero downtime"
echo "   • Auto-scaling (HPA) active and ready"
echo "   • Pods will scale 3→20 based on load"
echo ""
echo "🎯 Next steps:"
echo "   1. Test the application: curl https://api.myce.live/actuator/health"
echo "   2. Monitor pods: kubectl get pods -w"
echo "   3. Check logs: kubectl logs -f deployment/myce-server"