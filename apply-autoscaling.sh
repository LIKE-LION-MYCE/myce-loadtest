#!/bin/bash
# Script to apply auto-scaling configuration to your EKS cluster

echo "🚀 Applying Auto-scaling Configuration to EKS Cluster"
echo "=================================================="

# Check if kubectl is accessible
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check current deployment
echo "📊 Current deployment status:"
kubectl get deployment myce-server -o wide

echo ""
echo "📈 Applying HPA configuration..."
kubectl apply -f k8s-hpa-config.yaml

# Verify HPA is created
echo ""
echo "✅ HPA Status:"
kubectl get hpa myce-server-hpa

# Show current metrics
echo ""
echo "📊 Current metrics:"
kubectl top pods -l app=myce-server

# Monitor HPA
echo ""
echo "👀 Monitoring HPA (Ctrl+C to stop):"
echo "Tip: Run your load test now and watch pods auto-scale!"
kubectl get hpa myce-server-hpa --watch