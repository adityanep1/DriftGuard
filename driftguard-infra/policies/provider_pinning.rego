package driftguard.provider_pinning

import rego.v1

deny contains msg if {
  provider := input.required_providers[_]
  not provider.version_constraint
  msg := sprintf("provider %s has no version constraint", [provider.name])
}

deny contains msg if {
  provider := input.configuration.provider_config[_]
  not provider.version_constraint
  msg := sprintf("provider %s has no version constraint", [provider.name])
}

deny contains msg if {
  provider := input.required_providers[_]
  provider.name == "aws"
  not startswith(provider.version_constraint, "~> 5.")
  msg := sprintf("AWS provider must use ~> 5.0, got %s", [provider.version_constraint])
}
