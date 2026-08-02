package driftguard.backend_isolation

import rego.v1

deny contains msg if {
  environment := input.environments[_]
  expected := sprintf("env/%s/terraform.tfstate", [environment.name])
  environment.backend_key != expected
  msg := sprintf("%s must use backend key %s", [environment.name, expected])
}

deny contains msg if {
  keys := [environment.backend_key | environment := input.environments[_]]
  count(keys) != count({key | key := keys[_]})
  msg := "environment backend keys must be distinct"
}

deny contains msg if {
  environment := input.environments[_]
  not environment.backend_key
  msg := sprintf("%s has no backend key", [environment.name])
}
