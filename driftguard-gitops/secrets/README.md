# External Secret References

This directory contains only declarative references to external secret material. The actual secret values live in AWS Secrets Manager; Git stores the connection configuration and mapping definitions. Nothing in this directory should ever contain an actual secret value.

## What belongs here

- **SecretStore or ClusterSecretStore** provider configuration (tells ESO how to connect to the external store)
- **ExternalSecret** definitions with refresh interval, target metadata, remote key names, and selected properties
- **ServiceAccount references** whose IAM trust is managed separately by Terraform (IRSA)

## Required IRSA wiring

The `SecretStore` authenticates to AWS Secrets Manager with the `demo-service` ServiceAccount token (`auth.jwt.serviceAccountRef`). That ServiceAccount must map to an IAM role that can read the secrets. The Terraform `iam` module creates this role from the `irsa_workloads` variable, which each `live/<env>` root defaults to a `demo-service` entry granting `secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret` on `arn:aws:secretsmanager:*:*:secret:driftguard/*`. The role is named `driftguard-<env>-demo-service`.

After `terraform apply`, take the role ARN from the `irsa_role_arns` output and confirm the ServiceAccount annotation matches it. Each workload overlay already sets `eks.amazonaws.com/role-arn` to `arn:aws:iam::<account>:role/driftguard-<env>-demo-service`; replace the placeholder account id with your own. Without this role, ESO cannot authenticate and the ExternalSecret never materializes.

## What must never be here

Never commit: secret values, AWS access keys, private keys, bearer tokens, passwords, base64-encoded Secret data, or credentials inside Helm values. The `.gitignore` file helps prevent accidental local inclusion, but it is not a security control. The secret scanner and CI policy are the real safety nets.

## How failure works

In a healthy environment, ESO should materialize the requested Kubernetes Secret within 60 seconds. If the external store becomes unreachable, previously materialized values are preserved (workloads keep running) and the ExternalSecret status reports the failure. The correct response to a provider failure is to fix the connection, not to replace the reference with a plaintext value.

## Validation

```bash
# Run the secret scanner
python scripts/scan_no_plaintext_secrets.py .

# Run the full test suite
python -m pytest tests -q
```

For runtime validation, inspect ExternalSecret conditions, verify Secret data keys exist (without printing values), and check SecretStore provider error messages. This requires a cluster with ESO deployed and the external store accessible.

## Related documentation

- [Config Repo README (parent)](../README.md)
- [Platform requirements](../../.kiro/specs/gitops-platform/requirements.md)
- [Security and validation steering](../../.kiro/steering/30-security-validation.md)
- [Scripts (secret scanner)](../scripts/README.md)
- [IAM and IRSA module (Terraform)](../../driftguard-infra/modules/iam/README.md)
