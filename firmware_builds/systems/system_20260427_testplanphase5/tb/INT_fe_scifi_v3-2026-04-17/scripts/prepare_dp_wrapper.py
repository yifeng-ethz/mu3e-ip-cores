#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", required=True)
    parser.add_argument("--target-entity", required=True)
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()

    src = pathlib.Path(args.src)
    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    text = src.read_text()
    old = "entity work.scifi_datapath_system_v3"
    new = f"entity work.{args.target_entity}"
    if old not in text:
        raise SystemExit(f"Expected wrapper bind point not found in {src}")

    out_path = out_dir / src.name
    out_path.write_text(text.replace(old, new, 1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
