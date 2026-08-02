package driftguard.eks

import rego.v1

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_eks_cluster"
  version := resource.change.after.version
  not regex.match(`^1\.[0-9]{2}$`, version)
  msg := sprintf("%s must pin an explicit Kubernetes minor version", [resource.address])
}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_eks_cluster"
  config := resource.change.after.encryption_config
  not config
  msg := sprintf("%s must enable EKS Secrets encryption", [resource.address])
}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_eks_cluster"
  config := resource.change.after.encryption_config[0]
  not _encrypts_secrets(config)
  msg := sprintf("%s EKS encryption config must include Secrets", [resource.address])
}

_encrypts_secrets(config) if {
  config.resources[_] == "secrets"
}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_eks_cluster"
  config := resource.change.after.encryption_config[0]
  not config.provider[0].key_arn
  msg := sprintf("%s EKS Secrets encryption must use a KMS key", [resource.address])
}

public_subnet_ids contains id if {
  resource := input.resource_changes[_]
  resource.type == "aws_subnet"
  resource.change.after.tags["kubernetes.io/role/elb"] == "1"
  id := resource.change.after.id
}

private_subnet_ids contains id if {
  resource := input.resource_changes[_]
  resource.type == "aws_subnet"
  resource.change.after.tags["kubernetes.io/role/internal-elb"] == "1"
  id := resource.change.after.id
}

private_subnet_ids contains id if {
  id := input.private_subnet_ids[_]
}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_eks_node_group"
  subnet := resource.change.after.subnet_ids[_]
  public_subnet_ids[subnet]
  msg := sprintf("%s places a node group in a public subnet", [resource.address])
}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_eks_node_group"
  subnet := resource.change.after.subnet_ids[_]
  count(private_subnet_ids) > 0
  not private_subnet_ids[subnet]
  msg := sprintf("%s places a node group outside the private subnet allowlist", [resource.address])
}
