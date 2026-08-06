# DriftGuard Architecture Diagrams

The DriftGuard architecture is large, so rather than one crowded picture it is
broken into five focused views. Each view stays close to fifteen nodes, shares
the same styling, and uses one consistent edge-color legend. The diagrams are
generated as code with the [`diagrams`](https://github.com/mingrammer/diagrams)
library, so they live in source control, diff cleanly, and regenerate with a
single command.

Every diagram is written as both PNG (for quick GitHub previews) and SVG (sharp,
selectable, and self-contained). The SVGs have their icons inlined as base64, so
they render correctly anywhere, including on GitHub and in slides.

## The five views

### 1. Two-layer control model

The defining decision of the platform: Terraform owns the imperative day 0/1
substrate and performs a one-time ArgoCD install, then ArgoCD owns declarative
day 2 reconciliation of everything inside the cluster. This is the boundary that
everything else follows.

![Two-layer control model](diagrams/01-two-layer-control.svg)

### 2. AWS infrastructure and network topology

The per-environment VPC: public subnets for the load balancer and NAT, private
subnets for the worker nodes, and the supporting services (ECR, Route53, ACM,
KMS, and the S3 plus DynamoDB state backend).

![AWS infrastructure](diagrams/02-aws-infrastructure.svg)

### 3. GitOps control plane

How the Root_Application fans out through AppProjects and ApplicationSets into
the add-on and workload Applications. This is the app-of-apps pattern that lets
adding or removing a service be a single Git change.

![GitOps control plane](diagrams/03-gitops-control-plane.svg)

### 4. CI/CD delivery

The pull-based delivery contract: CI builds, tests, scans, and publishes the
image using short-lived OIDC credentials, then commits the new tag to the
Config_Repo. ArgoCD reconciles from Git. CI never runs `kubectl apply`.

![CI/CD delivery](diagrams/04-cicd-delivery.svg)

### 5. In-cluster runtime and progressive delivery

The runtime picture: the ALB and ingress in front of the canary Rollout, metric
analysis against Prometheus with abort-and-rollback on breach, the LGTM
observability stack fed by the OpenTelemetry Collector, and External Secrets
pulling from AWS Secrets Manager.

![Runtime and progressive delivery](diagrams/05-runtime-delivery.svg)

## Edge-color legend

The same legend applies to every diagram so the flows read consistently:

| Color | Meaning |
|---|---|
| Dark gray | Imperative provisioning by Terraform (day 0/1) |
| Blue | Declarative reconciliation by ArgoCD (day 2) |
| Light gray dashed | Supporting, background, or optional flow |
| Green | Identity, secrets, and policy flow |
| Red dashed | Failure, abort, and rollback path |

## Regenerating the diagrams

You need the `diagrams` Python package and the Graphviz system binary (the
package shells out to `dot`).

```bash
pip install diagrams
# Graphviz: apt install graphviz  |  brew install graphviz  |  dnf install graphviz
python generate_architecture.py
```

The script writes both formats into `diagrams/` and then inlines every SVG icon
so the files stay portable. If you only need to make an existing SVG portable,
run the helper directly:

```bash
python embed_icons_in_svg.py diagrams/01-two-layer-control.svg
```

## Files

| File | Purpose |
|---|---|
| `generate_architecture.py` | The generator. Edit the `build_*` functions to change a view. |
| `embed_icons_in_svg.py` | Inlines SVG icons as base64 so the files render anywhere. |
| `diagrams/` | The rendered PNG and SVG output. |

## Related documentation

- Infrastructure layer: [driftguard-infra/README.md](../../driftguard-infra/README.md)
- GitOps layer: [driftguard-gitops/README.md](../../driftguard-gitops/README.md)
- Project overview: [root README](../../README.md)
