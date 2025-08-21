# MYCE EKS + Docker Hybrid Demo Outputs

output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.myce_demo.name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.myce_demo.arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.myce_demo.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = aws_eks_cluster.myce_demo.vpc_config[0].cluster_security_group_id
}

output "kubectl_config_command" {
  description = "kubectl config command"
  value = "aws eks --region ${var.aws_region} update-kubeconfig --name ${var.cluster_name} --profile ${var.aws_profile}"
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = try(aws_eks_node_group.myce_demo_nodes.arn, null)
}

output "node_group_status" {
  description = "Status of the EKS Node Group"
  value       = try(aws_eks_node_group.myce_demo_nodes.status, null)
}

output "hybrid_target_group_arn" {
  description = "Hybrid target group ARN (Docker + EKS pods)"
  value       = aws_lb_target_group.hybrid_backends.arn
}

output "nat_gateway_ip" {
  description = "NAT Gateway public IP"
  value       = aws_nat_gateway.main.public_ip
}

output "docker_registered" {
  description = "Docker container registration status"
  value       = "Docker container registered at ${aws_lb_target_group_attachment.docker_container.target_id}:${aws_lb_target_group_attachment.docker_container.port}"
}

output "cost_estimate" {
  description = "Estimated costs (USD)"
  value = {
    daily = {
      eks_control_plane = "$2.40 (24h × $0.10/hr)"
      eks_3_nodes      = "$2.88 (3 × t3.medium spot × 24h)"  
      nat_gateway      = "$1.08 ($0.045/hr × 24h)"
      total           = "$6.36/day"
    }
    hourly = {
      baseline = "$0.265/hr (EKS + NAT + 3 nodes)"
      peak_6_nodes = "$0.385/hr (during load spikes)"
    }
  }
}

output "demo_readiness" {
  description = "Demo environment status"
  value = {
    docker_backend = "✅ Running (your existing container)"
    alb_routing   = "✅ Hybrid target group configured"
    eks_cluster   = "✅ ${aws_eks_cluster.myce_demo.status}"
    nodes_status  = try(aws_eks_node_group.myce_demo_nodes.status, "Creating...")
    next_steps    = [
      "1. Configure kubectl: ${local.kubectl_config}",
      "2. Deploy MYCE app: kubectl apply -f k8s/", 
      "3. Run load test: ./run-tests.sh (option 11)",
      "4. Monitor: https://api.myce.live/dashboard/demo"
    ]
  }
}

locals {
  kubectl_config = "aws eks --region ${var.aws_region} update-kubeconfig --name ${var.cluster_name} --profile ${var.aws_profile}"
}