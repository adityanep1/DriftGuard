package driftguard.security_group

import rego.v1

admin_ports := {22, 3389}
world_sources := {"0.0.0.0/0", "::/0"}

deny contains msg if {
  rule := input.security_group_rules[_]
  rule.type == "ingress"
  source := rule.cidr_blocks[_]
  world_sources[source]
  port := admin_ports[_]
  rule.from_port <= port
  rule.to_port >= port
  msg := sprintf("security-group rule %s exposes administrative port %d to the world", [rule.address, port])
}

deny contains msg if {
  rule := input.security_group_rules[_]
  rule.type == "ingress"
  source := rule.ipv6_cidr_blocks[_]
  world_sources[source]
  port := admin_ports[_]
  rule.from_port <= port
  rule.to_port >= port
  msg := sprintf("security-group rule %s exposes administrative port %d to the world", [rule.address, port])
}
