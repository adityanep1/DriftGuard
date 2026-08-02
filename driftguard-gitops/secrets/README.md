# External secret references

This directory contains only declarative references to external secret material. AWS Secrets Manager is the source of secret values; Git stores the SecretStore connection reference and ExternalSecret mapping.

## Allowed content

- SecretStore or ClusterSecretStore provider configuration.
- ExternalSecret refresh interval, target metadata, remote key names, and selected properties.
- ServiceAccount references whose IAM trust is separately managed by Terraform.

## Prohibited content

Never commit secret values, access keys, private keys, bearer tokens, passwords, base64 values copied from a Secret, or credentials inside Helm values. `.gitignore` reduces accidental local inclusion but is not a security control; the scanner and CI policy remain mandatory.

## Failure behavior

ESO must materialize the requested Secret within 60 seconds in a healthy test environment. If the external store is unreachable, previously materialized values must be preserved and the ExternalSecret status must report the failure. Do not fix a provider failure by replacing the reference with plaintext.

## Validation

Run `python scripts/scan_no_plaintext_secrets.py .`, repository tests, YAML schema/conformance checks, and the ESO integration script against a dedicated cluster. Inspect ExternalSecret conditions, Secret data keys without printing values, and SecretStore provider errors.
