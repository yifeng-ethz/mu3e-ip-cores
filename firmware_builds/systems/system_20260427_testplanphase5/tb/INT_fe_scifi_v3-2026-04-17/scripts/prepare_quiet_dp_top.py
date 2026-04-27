#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re
import sys


DEBUG_GENERIC_RE = re.compile(r"(^\s*DEBUG\s*=>\s*)1(\s*,?\s*$)", re.MULTILINE)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", required=True)
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()

    src = pathlib.Path(args.src)
    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    text = src.read_text()
    new_text, count = DEBUG_GENERIC_RE.subn(r"\g<1>0\g<2>", text)
    if count == 0:
        raise SystemExit(f"No DEBUG generic maps were rewritten in {src}")

    out_path = out_dir / src.name
    out_path.write_text(new_text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
