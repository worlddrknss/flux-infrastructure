output "cluster_name" {
  description = "EKS Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS Cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "oidc_provider" {
  description = "OIDC provider for IRSA"
  value       = module.eks.oidc_provider
}

output "kubeconfig" {
  description = "Raw kubeconfig to access the EKS cluster"
  value       = module.eks.kubeconfig
  sensitive   = true
}
