package driftguard.argocd

import rego.v1

# Pruning is always disabled unless a specific application carries an explicit review marker.
deny contains msg if {
  input.kind == "Application"
  input.spec.syncPolicy.automated.prune == true
  input.metadata.annotations["driftguard.io/prune-approved"] != "true"
  msg := sprintf("%s enables pruning without the per-application approval marker", [input.metadata.name])
}

# Every non-bootstrap application must bind to one of the default-deny projects.
deny contains msg if {
  input.kind == "Application"
  not bootstrap_application[input.metadata.name]
  not allowed_project[input.spec.project]
  msg := sprintf("%s is not bound to an approved AppProject", [input.metadata.name])
}

# Root bootstrap resources are the only resources allowed to use ArgoCD's built-in default project.
bootstrap_application := {
  "root-application",
  "argocd-projects",
  "driftguard-application-sets",
}

allowed_project contains project if {
  project := {"platform-addons", "observability", "security", "workloads"}[_]
}
