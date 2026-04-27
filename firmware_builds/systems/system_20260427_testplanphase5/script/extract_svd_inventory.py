#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path

from svd_inventory_lib import SYN_DIR, main_dump


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract Qsys-to-SVD inventory for board_test bring-up.")
    parser.add_argument(
        "--qsys",
        type=Path,
        default=SYN_DIR / "debug_sc_system_v3.qsys",
        help="Qsys file to inspect.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Optional JSON output path. Default: stdout.",
    )
    args = parser.parse_args()

    main_dump(args.qsys.resolve(), args.output.resolve() if args.output else None)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
