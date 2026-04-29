#!/usr/bin/env python3
"""Extract a full SC-visible address map with SVD register/field details."""

from __future__ import annotations

import argparse
from pathlib import Path

from svd_inventory_lib import SYN_DIR, main_dump_full_address_map


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract the Phase-5 SC-visible address map with SVD details.")
    parser.add_argument(
        "--debug-qsys",
        type=Path,
        default=SYN_DIR / "debug_sc_system_v3.qsys",
        help="Control-path Qsys file that supplies sc_hub base addresses.",
    )
    parser.add_argument(
        "--datapath-qsys",
        type=Path,
        default=SYN_DIR / "scifi_datapath_system_v3_pipe.qsys",
        help="Datapath Qsys file behind debug_sc_system_v3.mm_bridge.",
    )
    parser.add_argument(
        "--upload-qsys",
        type=Path,
        default=SYN_DIR / "upload_system_v3.qsys",
        help="Upload/run-control Qsys file behind debug_sc_system_v3.upload_mm_bridge.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Optional JSON output path. Default: stdout.",
    )
    args = parser.parse_args()

    main_dump_full_address_map(
        args.debug_qsys.resolve(),
        args.datapath_qsys.resolve(),
        args.upload_qsys.resolve(),
        args.output.resolve() if args.output else None,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
