package driftguard.iam

import rego.v1

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_iam_role_policy"
  policy := json.unmarshal(resource.change.after.policy)
  statement := policy.Statement[_]
  wildcard_action(statement)
  wildcard_resource(statement)
  msg := sprintf("%s combines wildcard IAM actions with wildcard resources", [resource.address])
}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_iam_policy"
  policy := json.unmarshal(resource.change.after.policy)
  statement := policy.Statement[_]
  wildcard_action(statement)
  wildcard_resource(statement)
  msg := sprintf("%s combines wildcard IAM actions with wildcard resources", [resource.address])
}

wildcard_action(statement) if {
  statement.Action == "*"
}

wildcard_action(statement) if {
  is_array(statement.Action)
  statement.Action[_] == "*"
}

wildcard_resource(statement) if {
  statement.Resource == "*"
}

wildcard_resource(statement) if {
  is_array(statement.Resource)
  statement.Resource[_] == "*"
}

deny contains msg if {
  resource := input.resource_changes[_]
  resource.type == "aws_iam_role"
  is_irsa_role(resource)
  policy := json.unmarshal(resource.change.after.assume_role_policy)
  not trust_policy_is_scoped(policy)
  msg := sprintf("%s IRSA trust policy must bind exactly one concrete service account", [resource.address])
}

is_irsa_role(resource) if {
  policy := json.unmarshal(resource.change.after.assume_role_policy)
  statement := policy.Statement[_]
  web_identity_action(statement)
}

trust_policy_is_scoped(policy) if {
  statements := [statement | statement := policy.Statement[_]]
  count(statements) == 1
  statement := statements[0]
  statement.Effect == "Allow"
  web_identity_action(statement)
  trust_statement_is_scoped(statement)
}

web_identity_action(statement) if {
  statement.Action == "sts:AssumeRoleWithWebIdentity"
}

web_identity_action(statement) if {
  is_array(statement.Action)
  statement.Action[_] == "sts:AssumeRoleWithWebIdentity"
}

trust_statement_is_scoped(statement) if {
  principal := statement.Principal.Federated
  single_federated_principal(principal)
  subjects := trust_subjects(statement)
  count(subjects) == 1
  subject := subjects[_]
  regex.match(`^system:serviceaccount:[^:*\s]+:[^:*\s]+$`, subject)
}

single_federated_principal(principal) if {
  is_string(principal)
  principal != "*"
}

single_federated_principal(principal) if {
  is_array(principal)
  count(principal) == 1
  principal[_] != "*"
}

trust_subjects(statement) := subjects if {
  subjects := {subject |
    condition := statement.Condition.StringEquals
    key := object.keys(condition)[_]
    endswith(key, ":sub")
    value := condition[key]
    is_string(value)
    subject := value
  } | {subject |
    condition := statement.Condition.StringEquals
    key := object.keys(condition)[_]
    endswith(key, ":sub")
    value := condition[key]
    is_array(value)
    subject := value[_]
  }
}
