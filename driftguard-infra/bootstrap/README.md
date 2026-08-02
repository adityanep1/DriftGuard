# Terraform State Backend Bootstrap

This directory sets up the remote state infrastructure that all other Terraform roots depend on. It creates an S3 bucket for state storage and a DynamoDB table for state locking. Because it creates the backend itself, this root has **no backend block by design** and must be applied with local state.

This is a one-time operation. An operator inspects the plan, applies it manually, and then migrates each `live/<environment>` root to use the new bucket.

## Safe inspection

You can safely inspect what this will create without changing anything:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -var='state_bucket_name=REPLACE_WITH_UNIQUE_BUCKET_NAME'
```

Do not run `terraform apply` from automated validation or CI. This is always a manual, deliberate action.

## What gets created

The state bucket is configured with:
- TLS enforcement (no unencrypted connections)
- Public access blocked
- Versioning enabled (so you can recover from accidental state corruption)
- Server-side encryption at rest

The DynamoDB table uses on-demand billing and the standard `LockID` hash key that Terraform expects for state locking.

## Backend keys

After the bucket exists, each environment root uses a distinct key so their state files never collide:

| Environment | Backend key |
|---|---|
| dev | `env/dev/terraform.tfstate` |
| staging | `env/staging/terraform.tfstate` |
| prod | `env/prod/terraform.tfstate` |
