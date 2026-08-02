package driftguard.ecr

import rego.v1

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_ecr_repository"
  config := resource.change.after.encryption_configuration[0]
  not config.encryption_type
  msg := sprintf("%s must enable ECR encryption at rest", [resource.address])
}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_ecr_repository"
  config := resource.change.after.encryption_configuration[0]
  config.encryption_type != "AES256"
  config.encryption_type != "KMS"
  msg := sprintf("%s uses an unsupported ECR encryption type", [resource.address])
}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_ecr_repository"
  not resource.change.after.image_scanning_configuration[0].scan_on_push
  msg := sprintf("%s must enable ECR scan-on-push", [resource.address])
}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_ecr_lifecycle_policy"
  policy := json.unmarshal(resource.change.after.policy)
  not _has_untagged_rule(policy)
  msg := sprintf("%s must expire untagged ECR images", [resource.address])
}

_has_untagged_rule(policy) if {
  policy.rules[_].selection.tagStatus == "untagged"
}

required_tags := {"Environment", "Project", "ManagedBy"}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_ecr_repository"
  tag := required_tags[_]
  not resource.change.after.tags[tag]
  msg := sprintf("%s is missing required ECR tag %s", [resource.address, tag])
}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_ecr_repository"
  tag := required_tags[_]
  resource.change.after.tags[tag] == ""
  msg := sprintf("%s has an empty required ECR tag %s", [resource.address, tag])
}
