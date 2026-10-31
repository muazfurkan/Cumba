#!/usr/bin/env python3
"""Lists user-facing strings used in code that are missing from Localizable.xcstrings.

Xcode adds new strings to the catalog only when building in the IDE. Command line and CI
builds don't, so this compares the keys the compiler extracted (*.stringsdata) with the
catalog. Run it after a build:

    python3 scripts/check-strings.py build

Exits with 1 when keys are missing.
"""
import json
import pathlib
import sys

build_dir = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build")
catalog_path = pathlib.Path("ljaspNotch/Resources/Localizable.xcstrings")
catalog = json.loads(catalog_path.read_text(encoding="utf-8"))["strings"]

used = {}
for path in build_dir.rglob("*.stringsdata"):
    if "ljaspNotchTests" in str(path):
        continue
    data = json.loads(path.read_text(encoding="utf-8"))
    source = pathlib.Path(data.get("source", "")).name
    for entry in data.get("tables", {}).get("Localizable", []):
        used.setdefault(entry["key"], source)

missing = sorted(key for key in used if key not in catalog)
for key in missing:
    print(f"{used[key]}: {key!r}")
sys.exit(1 if missing else 0)
