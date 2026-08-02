# Live environment roots

Each directory under `live/` is an isolated Terraform root for one DriftGuard Environment: `dev`, `staging`, or `prod`. Every root has its own backend key, variables, provider configuration, and module composition.

## Isolation contract

| Environment | Backend key | NAT policy | Intended use |
|---|---|---|---|
| `dev` | `env/dev/terraform.tfstate` | Cost-conscious unless overridden | Development and ephemeral validation |
| `staging` | `env/staging/terraform.tfstate` | Explicit staging choice | Pre-production integration |
| `prod` | `env/prod/terraform.tfstate` | NAT gateway per AZ | Production availability |

Never run Terraform from the wrong root. Use `terraform -chdir=live/<env>` or change into the exact directory and verify the backend key before initialization.

## Review before apply

Inspect `terraform.tfvars` for Kubernetes version, API access CIDRs, node groups, maximum node count, availability zones, NAT mode, ECR services, and optional DNS. Confirm the target AWS account and region. Confirm `max_node_count` is a whole number from 1 through 1000 and that node-group maxima do not exceed it.

## Environment workflow

```powershell
Set-Location driftguard-infra
terraform -chdir=live/dev init
terraform -chdir=live/dev plan -out=plans/dev.tfplan
terraform -chdir=live/dev show plans/dev.tfplan
# Apply only after explicit plan review:
terraform -chdir=live/dev apply plans/dev.tfplan
```

The commands above are mutating at `apply`. Use the matching environment path for staging or production; never reuse a plan between environments.

## Failure and recovery

A failed plan must cause no infrastructure mutation. A failed apply requires inspection of the failing resource and state lock before retrying. Do not change another environment's backend or state to repair a failed run. Use the teardown wrapper only for an explicitly approved environment and account.
