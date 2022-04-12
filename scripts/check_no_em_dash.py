#!/usr/bin/env python3
"""
Lint check script to strictly enforce: NO em dashes in comments, docs, or code.
Exits with 0 if clean, 1 if any forbidden dash is encountered.
"""

import sys
from pathlib import Path

FORBIDDEN_CHARS = {
    "\u2014": "Em dash (U+2014)",
    "\u2013": "En dash (U+2013)",
}

EXCLUDE_DIRS = {".git", ".system_generated", "build", "dist"}


def scan_file(filepath: Path) -> list[tuple[int, str, str]]:
    violations = []
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            for idx, line in enumerate(f, start=1):
                for char, desc in FORBIDDEN_CHARS.items():
                    if char in line:
                        violations.append((idx, desc, line.strip()))
    except Exception as e:
        print(f"Error reading {filepath}: {e}", file=sys.stderr)
    return violations


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    total_violations = 0

    for path in root.rglob("*"):
        if any(part in EXCLUDE_DIRS for part in path.parts):
            continue
        if path.is_file() and path.suffix in {
            ".hack",
            ".php",
            ".md",
            ".json",
            ".py",
            ".cpp",
            ".hpp",
            ".txt",
            ".sh",
            ".yaml",
            ".yml",
        }:
            violations = scan_file(path)
            if violations:
                total_violations += len(violations)
                for line_no, desc, snippet in violations:
                    print(
                        f"VIOLATION: {path.relative_to(root)}:{line_no} contains {desc}"
                    )
                    print(f"  > {snippet}")

    if total_violations > 0:
        print(f"\nFailed: Found {total_violations} forbidden dash violations.")
        return 1
    print("Pass: Zero em-dash violations found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
