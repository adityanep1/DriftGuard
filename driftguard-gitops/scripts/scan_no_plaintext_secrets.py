"""Fail-closed scanner for plaintext credentials in the Config_Repo."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path

AWS_ACCESS_KEY = re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")
PEM_BLOCK = re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")
ASSIGNMENT = re.compile(
    r"(?im)\b(?:password|passwd|secret|token|private[_-]?key|access[_-]?key)\b"
    r"\s*[:=]\s*[\"']?([A-Za-z0-9+/=_-]{20,})"
)
REFERENCE_MARKERS = ("REPLACE_WITH", "${", "ENC[", "ref:", "remoteRef:", "secretKeyRef:")
IGNORED_NAMES = {".gitkeep", ".gitignore", "scan_no_plaintext_secrets.py", "test_no_plaintext_secrets.py"}


def shannon_entropy(value: str) -> float:
    if not value:
        return 0.0
    counts = {character: value.count(character) for character in set(value)}
    length = len(value)
    return -sum((count / length) * math.log2(count / length) for count in counts.values())


def scan_text(text: str, source: str = "<text>") -> list[str]:
    findings: list[str] = []
    if AWS_ACCESS_KEY.search(text):
        findings.append(f"{source}: AWS access key detected")
    if PEM_BLOCK.search(text):
        findings.append(f"{source}: private-key PEM block detected")
    for match in ASSIGNMENT.finditer(text):
        line = text[match.start() : text.find("\n", match.start()) if "\n" in text[match.start():] else len(text)]
        if not any(marker in line for marker in REFERENCE_MARKERS):
            findings.append(f"{source}: plaintext credential assignment detected")
    for token in re.findall(r"\b[A-Za-z0-9+/=_-]{40,}\b", text):
        if shannon_entropy(token) >= 4.5 and not any(marker in token for marker in ("REPLACE_WITH", "example", "EXAMPLE")):
            findings.append(f"{source}: high-entropy token detected")
            break
    return findings


def scan_tree(root: Path) -> list[str]:
    findings: list[str] = []
    for path in root.rglob("*"):
        if not path.is_file() or path.name in IGNORED_NAMES or ".git" in path.parts:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        findings.extend(scan_text(text, str(path.relative_to(root))))
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    findings = scan_tree(args.root)
    if findings:
        print("\n".join(findings))
        return 1
    print(f"No plaintext secrets found under {args.root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
