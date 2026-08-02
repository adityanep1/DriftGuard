package driftguard.tags

import rego.v1

required_tags := {"Environment", "Project", "ManagedBy"}

taggable_types := {
  "aws_vpc", "aws_subnet", "aws_internet_gateway", "aws_nat_gateway",
  "aws_eip", "aws_route_table", "aws_vpc_dhcp_options", "aws_network_acl",
  "aws_network_acl_rule", "aws_route_table_association", "aws_security_group",
  "aws_s3_bucket", "aws_dynamodb_table", "aws_eks_cluster", "aws_eks_node_group",
  "aws_ecr_repository", "aws_iam_role", "aws_kms_key", "aws_iam_openid_connect_provider",
}

deny contains msg if {
  resource := input.resource_changes[_]
  taggable_types[resource.type]
  not resource.change.after.tags
  msg := sprintf("%s is taggable but has no tags", [resource.address])
}

deny contains msg if {
  resource := input.resource_changes[_]
  taggable_types[resource.type]
  required := required_tags[_]
  not resource.change.after.tags[required]
  msg := sprintf("%s is missing required tag %s", [resource.address, required])
}

deny contains msg if {
  resource := input.resource_changes[_]
  taggable_types[resource.type]
  required := required_tags[_]
  resource.change.after.tags[required] == ""
  msg := sprintf("%s has an empty required tag %s", [resource.address, required])
}
