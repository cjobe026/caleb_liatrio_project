output "region" {
  description = "AWS region"
  value       = var.region
}

output "load_balancer_hostname" {
  value = kubernetes_service.kube_LoadBalancer.load_balancer_ingress[0].hostname
}
