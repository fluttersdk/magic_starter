#!/usr/bin/env python3
"""
Audit translation completeness for a Magic Framework project.

Compares trans() keys used in Dart source code against a JSON translation
stub file and reports missing, orphan, and summary statistics.

Usage:
    python3 audit_locale.py <source_dir> <stub_file>

Example:
    python3 audit_locale.py lib/src assets/stubs/install/en.stub
"""

import json
import os
import re
import sys


def flatten_json(obj: dict, prefix: str = "") -> set[str]:
    """Flatten nested JSON to dot-notation keys."""
    keys: set[str] = set()
    for k, v in obj.items():
        key = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            keys.update(flatten_json(v, key))
        else:
            keys.add(key)
    return keys


def extract_trans_keys(source_dir: str) -> dict[str, list[str]]:
    """
    Extract all trans() keys from Dart source files.

    Returns a dict mapping each key to a list of file:line locations.
    """
    pattern = re.compile(r"trans\(\s*'([^']+)'", re.MULTILINE)
    keys: dict[str, list[str]] = {}

    for root, _, files in os.walk(source_dir):
        for filename in files:
            if not filename.endswith(".dart"):
                continue

            filepath = os.path.join(root, filename)
            with open(filepath, encoding="utf-8") as f:
                content = f.read()

            for match in pattern.finditer(content):
                key = match.group(1)
                # Calculate line number from match position.
                line_num = content[: match.start()].count("\n") + 1
                rel_path = os.path.relpath(filepath)
                location = f"{rel_path}:{line_num}"

                if key not in keys:
                    keys[key] = []
                keys[key].append(location)

    return keys


def main() -> None:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <source_dir> <stub_file>")
        sys.exit(1)

    source_dir = sys.argv[1]
    stub_file = sys.argv[2]

    # 1. Read and flatten the stub file.
    with open(stub_file, encoding="utf-8") as f:
        stub_data = json.load(f)
    stub_keys = flatten_json(stub_data)

    # 2. Extract all trans() keys from source.
    source_key_map = extract_trans_keys(source_dir)
    source_keys = set(source_key_map.keys())

    # 3. Compare.
    missing = sorted(source_keys - stub_keys)
    orphans = sorted(stub_keys - source_keys)

    # 4. Report.
    print(f"Source keys:  {len(source_keys)}")
    print(f"Stub keys:   {len(stub_keys)}")
    print()

    if missing:
        print(f"MISSING FROM STUB ({len(missing)}):")
        for key in missing:
            locations = ", ".join(source_key_map[key][:3])
            print(f"  {key}  ({locations})")
        print()
    else:
        print("MISSING FROM STUB: (none)")
        print()

    if orphans:
        print(f"ORPHAN KEYS ({len(orphans)}):")
        for key in orphans:
            print(f"  {key}")
        print()
    else:
        print("ORPHAN KEYS: (none)")
        print()

    # Exit with error code if missing keys found.
    if missing:
        print(f"RESULT: {len(missing)} missing key(s) — stub needs updating.")
        sys.exit(1)
    else:
        print("RESULT: All source keys present in stub. ✓")


if __name__ == "__main__":
    main()
