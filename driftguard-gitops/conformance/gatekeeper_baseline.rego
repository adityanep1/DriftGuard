package driftguard.gatekeeper_baseline

import rego.v1

privileged_container(request) if {
  request.review.object.spec.containers[_].securityContext.privileged == true
}

host_namespace(request) if {
  request.review.object.spec.hostPID == true
}

host_namespace(request) if {
  request.review.object.spec.hostIPC == true
}

host_namespace(request) if {
  request.review.object.spec.hostNetwork == true
}

missing_required_label(request, required) if {
  not request.review.object.metadata.labels[required]
}

violation contains "privileged containers are not permitted" if {
  privileged_container(input)
}

violation contains "host namespaces are not permitted" if {
  host_namespace(input)
}

violation contains message if {
  required := input.parameters.requiredLabels[_]
  missing_required_label(input, required)
  message := sprintf("required label %s is missing", [required])
}
