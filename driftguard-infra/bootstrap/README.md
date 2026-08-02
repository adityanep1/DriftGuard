# Terraform state backend bootstrap

This root has **no backend block by design**. It must be inspected and applied once with local state by an operator who has explicitly approved AWS provisioning. After creation, migrate each `live/<environment>` root to the bucket and its environment-specific key.

## Safe inspection

```text
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -var='state_bucket_name=REPLACE_WITH_UNIQUE_BUCKET_NAME'
```

Do not run `terraform apply` from automated validation. The bucket enforces TLS, blocks public access, enables versioning, and uses server-side encryption. DynamoDB uses on-demand billing and the standard `LockID` hash key for Terraform locking.

Each live root uses a distinct key: `env/dev/terraform.tfstate`, `env/staging/terraform.tfstate`, or `env/prod/terraform.tfstate`.
