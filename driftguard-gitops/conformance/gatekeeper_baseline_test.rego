package driftguard.gatekeeper_baseline

import rego.v1

compliant := {
  "review": {
    "object": {
      "metadata": {"labels": {"Environment": "dev", "Project": "DriftGuard", "ManagedBy": "ArgoCD"}},
      "spec": {"containers": [{"securityContext": {"privileged": false}}]}
    }
  },
  "parameters": {"requiredLabels": ["Environment", "Project", "ManagedBy"]}
}

privileged := {
  "review": {
    "object": {
      "metadata": {"labels": {"Environment": "dev", "Project": "DriftGuard", "ManagedBy": "ArgoCD"}},
      "spec": {"containers": [{"securityContext": {"privileged": true}}]}
    }
  },
  "parameters": compliant.parameters
}

host_network := {
  "review": {
    "object": {
      "metadata": {"labels": {"Environment": "dev", "Project": "DriftGuard", "ManagedBy": "ArgoCD"}},
      "spec": {"hostNetwork": true, "containers": [{"securityContext": {"privileged": false}}]}
    }
  },
  "parameters": compliant.parameters
}

missing_label := {
  "review": {
    "object": {
      "metadata": {"labels": {"Environment": "dev", "Project": "DriftGuard"}},
      "spec": {"containers": [{"securityContext": {"privileged": false}}]}
    }
  },
  "parameters": compliant.parameters
}

test_compliant_workload if {
  not privileged_container(compliant)
  not host_namespace(compliant)
  not missing_required_label(compliant, "Environment")
  not missing_required_label(compliant, "Project")
  not missing_required_label(compliant, "ManagedBy")
}

test_privileged_workload_denied if {
  privileged_container(privileged)
}

test_host_namespace_denied if {
  host_namespace(host_network)
}

test_missing_label_denied if {
  missing_required_label(missing_label, "ManagedBy")
}
