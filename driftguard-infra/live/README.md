# Live Environment Roots

Each directory under `live/` is a fully isolated Terraform root for one DriftGuard environment. Every root has its own backend key, variable values, provider configuration, and module composition. They share the same modules but never share state.

## Environment isolation

| Environment | Backend key | NAT policy | Intended use |
|---|---|---|---|
| `dev` | `env/dev/terraform.tfstate` | Cost-conscious (single NAT unless overridden) | Development and ephemeral validation |
| `staging` | `env/staging/terraform.tfstate` | Explicit staging choice | Pre-production integration testing |
| `prod` | `env/prod/terraform.tfstate` | NAT gateway per AZ (forced for availability) | Production workloads |

The most important rule: never run Terraform from the wrong root. Use `terraform -chdir=live/<env>` or change into the exact directory and verify the backend key before running `terraform init`.

## What to review before applying

Before running any mutating command, inspect `terraform.tfvars` and confirm:

- Kubernetes version
- API access CIDRs (who can reach the cluster API)
- Node group definitions and maximum node count
- Availability zones
- NAT mode (cost vs. availability trade-off)
- ECR service list
- Optional DNS configuration
- Target AWS account and region

Confirm that `max_node_count` is a whole number between 1 and 1000, and that individual node-group maximums do not exceed it.

## Typical workflow

```bash
cd driftguard-infra
terraform -chdir=live/dev init
terraform -chdir=live/dev plan -out=plans/dev.tfplan
terraform -chdir=live/dev show plans/dev.tfplan
# Apply only after explicit plan review:
terraform -chdir=live/dev apply plans/dev.tfplan
```

The `apply` step is mutating. Use the matching path for staging or production; never reuse a plan across environments.

## Failure and recovery

A failed `plan` causes no infrastructure changes. A failed `apply` requires inspecting the failing resource and checking the state lock before retrying. Do not change another environment's backend or state to repair a failed run. Use the teardown wrapper only for an explicitly approved environment and account.

## Related documentation

- [Infrastructure README (parent)](../README.md)
- [Module catalog](../modules/README.md)
- [State backend bootstrap](../bootstrap/README.md)
- [Validation scripts](../scripts/README.md)
- [Platform requirements](../../.kiro/specs/gitops-platform/requirements.md)
- [Terraform and AWS steering](../../.kiro/steering/10-terraform-aws.md)
