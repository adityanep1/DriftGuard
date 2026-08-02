# External Secret References

This directory contains only declarative references to external secret material. The actual secret values live in AWS Secrets Manager; Git stores the connection configuration and mapping definitions. Nothing in this directory should ever contain an actual secret value.

## What belongs here

- **SecretStore or ClusterSecretStore** provider configuration (tells ESO how to connect to the external store)
- **ExternalSecret** definitions with refresh interval, target metadata, remote key names, and selected properties
- **ServiceAccount references** whose IAM trust is managed separately by Terraform (IRSA)

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
