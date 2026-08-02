# Config Repo Validation Scripts

These scripts protect the pull-based GitOps boundary and enforce the no-plaintext-secret rule. They are your first line of defense against accidentally committing sensitive material to the repository.

## Secret scanner

The main tool here is the plaintext secret scanner. Run it from `driftguard-gitops/`:

```bash
python scripts/scan_no_plaintext_secrets.py .
```

The scanner detects:
- AWS access keys (the `AKIA...` pattern)
- PEM private key blocks
- Plaintext credential assignments (like `password: actual-value`)
- High-entropy token-like values that look like real secrets

It intentionally accepts:
- ExternalSecret remote references
- Environment variable references (like `${SECRET_REF}`)
- Documented replacement markers (like `REPLACE_WITH_COMMIT_SHA`)
- Ciphertext markers (like `ENC[AES256,...]`)

If you get a false positive, the correct fix is to use a reference/ciphertext design or add a narrowly reviewed scanner exception. Never paste a real secret into the repository to work around a detection issue.

## CI and hook usage

The Config Repo CI workflow runs the scanner and tests automatically on every pull request. The `guard-secrets` Kiro hook should also run the scanner on file creation and edit events, especially for files under `secrets/`.

As a good habit, run the scanner before creating a commit and after changing `.yaml` files, Helm values, examples, or documentation that contains configuration snippets.

## What to do when a secret is detected

If the scanner catches something real:

1. Stop the change immediately.
2. Remove the value from the working tree and Git history if it was already committed.
3. Rotate any exposed credential (assume it is compromised the moment it hits Git).
4. Inspect CI logs to confirm the detection.
5. Replace the value with an ExternalSecret reference.

Remember that `.gitignore` only reduces the chance of accidental inclusion. It cannot undo a value that has already been committed or pushed.
