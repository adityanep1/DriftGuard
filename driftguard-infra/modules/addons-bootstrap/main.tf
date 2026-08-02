resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.argocd_namespace
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  atomic           = true
  cleanup_on_fail  = true
  wait             = true
  wait_for_jobs    = true
  timeout          = var.installation_timeout_seconds
}

resource "kubernetes_manifest" "root_application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "root-application"
      namespace = var.argocd_namespace
      labels = {
        "app.kubernetes.io/part-of" = "driftguard-gitops"
      }
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.config_repo_url
        targetRevision = var.config_repo_revision
        path           = var.root_application_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.argocd_namespace
      }
      syncPolicy = {
        automated = {
          selfHeal = true
          prune    = false
        }
        syncOptions = ["CreateNamespace=true"]
        retry = {
          limit = 5
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}
