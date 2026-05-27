#!/usr/bin/env python3
"""Post-LVDS-swap address rebase: the new mu3e_lvds_controller CSR
aperture is 0x1000 bytes (1024 words, 10-bit address) instead of the
OLD lvds_rx_controller_pro's 0x40 (16 words / 4-bit address). Slaves
that previously sat inside the OLD LVDS window now overlap.

Conflicts found by qsys-syn after the swap:
    master_datapath.master / mm_pipeline_lvds_csr_low.m0:
        mutrig_datapath_subsystem_0.backpressure_fifo_csr  was 0x0860
    mm_pipeline_lvds_csr_low.m0:
        mm_pipeline_jtagmaster2rstctrl.s0                  was 0x0200

Both are moved out of the new LVDS window (0x0000..0x0FFF). Lane 1..7
backpressure_fifos at 0x1860, 0x2860, ..., 0x7860 are unaffected, so
the lane-N pattern is preserved by parking lane-0 in the previously
unused slot 0x8860 on master_datapath and 0x2000 on
mm_pipeline_lvds_csr_low (still inside the pipeline bridge's 32 KB
window).
"""

from __future__ import annotations

import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent
REPO_ROOT  = SYSTEM_DIR.resolve().parents[2]

SCIFI_DP_GLOBAL = REPO_ROOT / "quartus_systems" / "scifi_datapath_system_v4.qsys"
SCIFI_DP_LOCAL  = SYSTEM_DIR / "generated" / "qsys" / "scifi_datapath_system_v4.qsys"

# (start_master, end_slave_full, new_base)
#
# Pack everything on `mm_pipeline_lvds_csr_low` within 0x2000 so the
# pipeline-side rounded span stays 8 KiB and doesn't push out the next
# bridge `mm_pipeline_lvds_csr_emu_dbg` at 0x2000 on the upstream
# mm_clock_crossing_bridge:
#     LVDS      0x0000..0x0FFF (4 KiB)
#     bp_fifo_0 0x1000..0x103F (64 B)
#     jtagmaster 0x1080..0x117F (256 B)
#     bp_fifo_1 0x1860..0x189F (64 B, unchanged)
# On `master_datapath`, bp_fifo_N is at N*0x1000 + 0x860; lane 0's
# old slot (0x0860) is inside the new LVDS window so move it past
# lane 7 to 0x8860 (next free per-lane slot).
REBASE = [
    ("master_datapath.master",
     "mutrig_datapath_subsystem_0.backpressure_fifo_csr",
     0x00008860),
    ("mm_pipeline_lvds_csr_low.m0",
     "mutrig_datapath_subsystem_0.backpressure_fifo_csr",
     0x00001000),
    ("mm_pipeline_lvds_csr_low.m0",
     "mm_pipeline_jtagmaster2rstctrl.s0",
     0x00001100),
]


def rebase(root: ET.Element) -> int:
    n = 0
    for conn in root.findall("connection"):
        if conn.get("kind") != "avalon":
            continue
        s = conn.get("start", "")
        e = conn.get("end", "")
        for ms, es, new_base in REBASE:
            if s == ms and e == es:
                for p in conn.findall("parameter"):
                    if p.get("name") == "baseAddress":
                        p.set("value", f"0x{new_base:08x}")
                        n += 1
                        break
    return n


def serialize(tree: ET.ElementTree, path: Path) -> None:
    os.chmod(path, 0o644)
    tree.write(path, encoding="utf-8", xml_declaration=True)


def apply(path: Path) -> None:
    if not path.is_file():
        print(f"  SKIP (not a file): {path}")
        return
    print(f"=== {path} ===")
    tree = ET.parse(path)
    root = tree.getroot()
    n = rebase(root)
    print(f"  rebased {n} baseAddress values")
    serialize(tree, path)


def main() -> int:
    for p in (SCIFI_DP_GLOBAL, SCIFI_DP_LOCAL):
        apply(p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
