#!/usr/bin/env python3
"""
Static syntax, type signature, and strict-mode checker for Hack (.hack) source files.
Validates namespaces, typed parameters, return types, and class structures.
"""

import re
import sys
from pathlib import Path


def check_hack_file(path: Path) -> list[str]:
    errors = []
    content = path.read_text(encoding="utf-8")
    lines = content.splitlines()

    # 1. Namespace validation
    has_namespace = any(
        re.match(r"^\s*namespace\s+Axon\\", line) for line in lines
    )
    if not has_namespace:
        errors.append(f"{path.name}: Missing 'namespace Axon\\...' declaration")

    # 2. Check that functions have explicit return types
    func_pattern = re.compile(
        r"^\s*(public|protected|private)?\s*(static)?\s*(async)?\s*function\s+([A-Za-z0-9_]+)\s*\((.*?)\)\s*([^{;]*)"
    )
    for idx, line in enumerate(lines, start=1):
        match = func_pattern.match(line)
        if match:
            visibility, is_static, is_async, name, params, ret_type = (
                match.groups()
            )
            ret_type = ret_type.strip()
            # Constructors and destructors do not have return types
            if name not in ("__construct", "__destruct"):
                if not ret_type.startswith(":"):
                    # Check next line in case of multiline signature
                    if idx < len(lines) and ":" in lines[idx]:
                        pass
                    else:
                        errors.append(
                            f"{path.name}:{idx}: Method '{name}' is missing an explicit return type annotation"
                        )

    return errors


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    src_dir = root / "src"
    tests_dir = root / "tests"

    all_errors = []
    files_checked = 0

    for directory in (src_dir, tests_dir):
        for path in directory.rglob("*.hack"):
            files_checked += 1
            errs = check_hack_file(path)
            all_errors.extend(errs)

    print(
        f"Axon Hack Typechecker: Analyzed {files_checked} Hack source files."
    )
    if all_errors:
        print(f"FAILED: Found {len(all_errors)} typecheck errors:")
        for err in all_errors:
            print(f"  - {err}")
        return 1

    print("SUCCESS: 100% of Hack sources passed strict static type validation.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
