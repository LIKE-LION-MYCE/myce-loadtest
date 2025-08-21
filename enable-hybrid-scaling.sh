#!/bin/bash
# Enable Hybrid Auto-scaling: Docker (fixed) + K8s (auto-scale)

echo "🔧 Configuring Hybrid Auto-scaling"
echo "=================================="

# Step 1: Expose K8s service via NodePort
echo "📡 Exposing K8s service on NodePort 30080..."
kubectl patch svc myce-service -p '{
  "spec": {
    "type": "NodePort",
    "ports": [{
      "port": 8080,
      "targetPort": 8080,
      "nodePort": 30080,
      "protocol": "TCP"
    }]
  }
}'

# Step 2: Verify service
echo ""
echo "✅ Service configuration:"
kubectl get svc myce-service

# Step 3: Get node IPs for ALB configuration
echo ""
echo "🎯 Add these targets to your ALB target group:"
echo "Docker target: [EC2-IP]:8080 (already exists)"
echo "K8s targets:"
kubectl get nodes -o wide | grep -v NAME | awk '{print "  - " $6 ":30080"}'

echo ""
echo "📊 Current scaling configuration:"
echo "- Docker: 1 instance (fixed)"
echo "- K8s: 3-20 pods (auto-scales with HPA)"
kubectl get hpa myce-server-hpa

echo ""
echo "⚡ Auto-scaling is ready!"
echo "1. Add the K8s NodePort targets to ALB in AWS Console"
echo "2. Set target weights (Docker: 20%, K8s: 80%)"
echo "3. K8s will auto-scale based on load"
echo "4. Docker provides stable baseline capacity"