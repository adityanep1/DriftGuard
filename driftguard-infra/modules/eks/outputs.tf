output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_data" {
  description = "Base64-encoded Kubernetes API server certificate authority data."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN used for IRSA."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_issuer_url" {
  description = "EKS OIDC issuer URL used to construct IRSA trust conditions."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "node_group_names" {
  description = "Managed EKS node group names."
  value       = { for name, group in aws_eks_node_group.this : name => group.node_group_name }
}

output "cluster_encryption_key_arn" {
  description = "KMS key ARN used to encrypt EKS Kubernetes secrets at rest."
  value       = aws_kms_key.eks_secrets.arn
}

output "cluster_role_arn" {
  description = "IAM role ARN used by the EKS control plane."
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "IAM role ARN used by managed worker nodes."
  value       = aws_iam_role.nodes.arn
}
