# ArgoCD bootstrap module

Installs the pinned ArgoCD Helm chart with `wait`, `atomic`, and a maximum 600-second
readiness timeout. The Root_Application is a dependent `kubernetes_manifest`, so Terraform
will not create it when the Helm release fails to become ready. The seeded application points
at `bootstrap/children` in the Config_Repo; the seed manifest itself is
`bootstrap/root-app.yaml`. This avoids an invalid ArgoCD file path while keeping the bootstrap
manifest as the single operator-visible entrypoint.

The root module must configure and pass the Helm and Kubernetes providers against the newly
created EKS cluster. This module does not manage any day-2 add-on through Terraform.
