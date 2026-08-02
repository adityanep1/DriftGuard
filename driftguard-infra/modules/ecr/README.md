# ECR Module

This module creates exactly one private Amazon ECR repository per deployable service in the target environment. Each repository is configured with encryption at rest, scan-on-push, required tags, immutable environment-specific naming, and lifecycle expiration for untagged images.

## Inputs

| Variable | What it controls |
|---|---|
| `name_prefix` | Prefix for repository naming |
| `environment` | Environment label (dev, staging, prod) |
| `project` | Project tag value |
| `services` | A non-empty set of service names (one repository per service) |
| `untagged_image_retention_days` | How long to keep untagged images before cleanup (default: 14 days) |
| `encryption_type` | `AES256` or `KMS` |
| KMS key ARN | Required when using KMS encryption |

## Outputs

`repository_names`, `repository_urls`, and `repository_arns`, all keyed by service name.

## Security and operations

Repositories are private and do not allow anonymous or public pull access. The expected workflow for CI is:

1. Build the container image
2. Tag it with the full commit SHA (not `latest`)
3. Scan it for vulnerabilities
4. Push only if the scan passes

Untagged-image expiration limits storage cost over time. Review the retention period before changing it, especially in environments where you might need to roll back to older images.

## Validation

Run ECR plan conformance checks, required-tag verification, encryption checks, scan-on-push checks, lifecycle-policy checks, and the negative security fixture. The Python tests in `test_security_modules.py` verify that the module source declares the expected security shape (encryption, scan-on-push, lifecycle rules, no force-delete, required tags).
