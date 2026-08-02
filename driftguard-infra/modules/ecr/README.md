# ECR module

Creates exactly one private Amazon ECR repository per deployable service in the target environment. Repositories use encryption at rest, scan-on-push, required tags, immutable environment-specific naming, and lifecycle expiration for untagged images.

## Inputs

Provide `name_prefix`, `environment`, `project`, a non-empty `services` set, `untagged_image_retention_days`, `encryption_type` (`AES256` or `KMS`), and a KMS key ARN when using KMS.

## Outputs

`repository_names`, `repository_urls`, and `repository_arns`, keyed by service.

## Security and operations

The repository is private and does not enable anonymous/public pull. CI should tag images with the full commit identifier, scan before push, and update the Config_Repo only after a successful push. Untagged-image expiration limits storage cost; review retention before changing it.

## Validation

Run ECR plan conformance, required-tag checks, encryption checks, scan-on-push checks, lifecycle-policy checks, and the negative security fixture. Do not treat a source-shape test as a substitute for plan JSON when providers are available.
