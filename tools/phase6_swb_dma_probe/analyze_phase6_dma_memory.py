#!/usr/bin/env python3
"""Tools/ entry point for the Phase-6 DMA frame reducer."""

from __future__ import annotations

import runpy
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
IMPLEMENTATION = (
    REPO_ROOT
    / "firmware_builds"
    / "systems"
    / "system_20260427_testplanphase5"
    / "script"
    / "analyze_phase6_dma_memory.py"
)


def main() -> int:
    sys.argv[0] = str(IMPLEMENTATION)
    runpy.run_path(str(IMPLEMENTATION), run_name="__main__")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
