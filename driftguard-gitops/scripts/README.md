# Config_Repo validation scripts

These scripts protect the pull-based GitOps boundary and the no-plaintext-secret rule.

## Secret scanner

Run from `driftguard-gitops/`:

```powershell
python scripts/scan_no_plaintext_secrets.py .
```

The scanner rejects AWS access keys, private-key PEM blocks, plaintext credential assignments, and high-entropy token-like values. It accepts ExternalSecret remote references, environment references, documented replacement markers, and ciphertext markers. A false positive must be resolved by using a reference/ciphertext design or a narrowly reviewed scanner exception; never paste a real secret into the repository.

## CI and hook usage

The Config_Repo workflow runs the scanner and tests. The `guard-secrets` Kiro hook should run it on file creation/edit events, especially under `secrets/`. Run the scanner before creating a commit and after changing `.yaml`, Helm values, examples, or documentation containing configuration snippets.

## Failure response

Stop the change, remove the value from the working tree and history if necessary, rotate any exposed credential, inspect CI logs, and replace the value with an ExternalSecret reference. `.gitignore` is only an accident-reduction measure and cannot undo a value already committed or uploaded.
