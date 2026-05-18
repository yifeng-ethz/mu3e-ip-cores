#!/usr/bin/env python3
"""Apply the v4 SC-hub rewire to debug_sc_system_v4 and scifi_datapath_system_v4
in-place (XML-aware, NOT substring-matching) — drops legacy_firefly_bridge
and dbg_mm2runctrl_0, widens upload_mm_bridge, and rebases Region A/B slaves
to the addresses agreed in doc/V4_REWIRE_SPEC.md.

Why XML-aware: an earlier substring-based version of this script was
dropping unrelated connections whose body contained the dropped module's
name as a longer substring. This version uses ElementTree to parse the
.qsys file, walks every <connection> element, and only drops a connection
when its `start` or `end` attribute starts with `{module}.` or equals
`{module}`. ET preserves child ordering and whitespace acceptably for
Qsys reload.
"""

from __future__ import annotations

import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent
REPO_ROOT  = SYSTEM_DIR.resolve().parents[2]

DEBUG_SC        = REPO_ROOT / "quartus_systems" / "debug_sc_system_v4.qsys"
SCIFI_DP_GLOBAL = REPO_ROOT / "quartus_systems" / "scifi_datapath_system_v4.qsys"
SCIFI_DP_LOCAL  = SYSTEM_DIR / "generated" / "qsys" / "scifi_datapath_system_v4.qsys"

# Region A rebases — applied to debug_sc_system_v4.qsys
REGION_A_REBASE = {
    ("scratch_pad_ram",                "s1"):         0x00000,
    ("max10_prog_avmm_0",              "csr_avmm"):   0x01000,
    ("on_die_temp_sense_ctrl",         "csr"):        0x02000,
    ("onewire_master_controller_0",    "csr"):        0x03000,
    ("firefly_xcvr_ctrl_0",            "firefly"):    0x04000,
    ("mutrig_cfg_ctrl_0",              "avmm_csr"):   0x05000,
    # bridges (sc_hub_cmd_pipe.m0 sees them at these absolute byte addresses)
    ("mm_bridge",                      "s0"):         0x10000,
    ("upload_mm_bridge",               "s0"):         0x30000,
}

# Region B rebases — applied to scifi_datapath_system_v4.qsys (local + global)
REGION_B_REBASE = {
    ("lvds_rx_controller_pro_0",       "csr"):        0x00000,
    ("emulator_mutrig_qsys_inst",      "csr"):        0x01000,
    ("arb_hit_type0_supercore_0",      "csr_0"):      0x02000,
    ("arb_hit_type0_supercore_0",      "csr_1"):      0x02080,
    ("arb_hit_type0_supercore_0",      "csr_2"):      0x02100,
    ("arb_hit_type0_supercore_0",      "csr_3"):      0x02180,
    ("arb_hit_type0_supercore_0",      "csr_4"):      0x02200,
    ("arb_hit_type0_supercore_0",      "csr_5"):      0x02280,
    ("arb_hit_type0_supercore_0",      "csr_6"):      0x02300,
    ("arb_hit_type0_supercore_0",      "csr_7"):      0x02380,
    ("mts_preprocessor_0",             "csr"):        0x03000,
    ("mts_preprocessor_1",             "csr"):        0x04000,
    ("hit_stack_subsystem_0",          "feb_frame_assembly_csr"): 0x05000,
    ("hit_stack_subsystem_0",          "ring_buffer_cam_0_csr"):  0x05100,
    ("hit_stack_subsystem_0",          "ring_buffer_cam_1_csr"):  0x05200,
    ("hit_stack_subsystem_0",          "ring_buffer_cam_2_csr"):  0x05300,
    ("hit_stack_subsystem_0",          "ring_buffer_cam_3_csr"):  0x05400,
    ("hit_stack_subsystem_1",          "feb_frame_assembly_csr"): 0x06000,
    ("hit_stack_subsystem_1",          "ring_buffer_cam_0_csr"):  0x06100,
    ("hit_stack_subsystem_1",          "ring_buffer_cam_1_csr"):  0x06200,
    ("hit_stack_subsystem_1",          "ring_buffer_cam_2_csr"):  0x06300,
    ("hit_stack_subsystem_1",          "ring_buffer_cam_3_csr"):  0x06400,
    ("histogram_statistics_0",         "csr"):        0x07000,
    ("histogram_statistics_0",         "hist_bin"):   0x08000,
    ("mutrig_reset_controller_0",      "reconfig_mgmt"): 0x09000,
    ("mutrig_injector_0",              "csr"):        0x0A000,
}

DROP_DEBUG_SC = ["legacy_firefly_bridge"]
DROP_SCIFI_DP = ["dbg_mm2runctrl_0"]


def conn_touches(conn: ET.Element, module: str) -> bool:
    """True iff this <connection> has start= or end= = `{module}` or starts
    with `{module}.` (i.e. exact instance match, never a substring of a
    longer instance name)."""
    for attr in ("start", "end"):
        v = conn.get(attr, "")
        if v == module or v.startswith(module + "."):
            return True
    return False


def drop_module(root: ET.Element, module: str) -> int:
    """Remove the <module name="..."> child and every <connection> that
    references it. Returns count of dropped elements."""
    n = 0
    # 1) drop the module
    for child in list(root):
        if child.tag == "module" and child.get("name") == module:
            root.remove(child)
            n += 1
    # 2) drop matching connections
    for child in list(root):
        if child.tag == "connection" and conn_touches(child, module):
            root.remove(child)
            n += 1
    return n


def rebase_connections(root: ET.Element, table: dict[tuple[str,str], int],
                        only_masters: set[str] | None = None) -> int:
    """For each <connection> whose `end` matches an entry in `table`,
    update the inner `<parameter name="baseAddress" value="0xNNNN"/>` to
    the requested value. If `only_masters` is given, only connections
    whose `start` is in that set are updated — this lets us rebase the
    TOP-level master view (sc_hub / data master / jtag master) without
    perturbing the internal LVDS-CSR pipeline bridges or other private
    routing whose offsets are fixed by their addressSpan. Returns count
    of updates."""
    n = 0
    for conn in root.findall("connection"):
        end = conn.get("end", "")
        start = conn.get("start", "")
        if only_masters is not None and start not in only_masters:
            continue
        if "." not in end:
            continue
        inst, port = end.split(".", 1)
        key = (inst, port)
        if key not in table:
            continue
        new_base = table[key]
        for p in conn.findall("parameter"):
            if p.get("name") == "baseAddress":
                p.set("value", f"0x{new_base:08x}")
                n += 1
                break
    return n


def widen_upload_mm_bridge(root: ET.Element) -> int:
    """Set upload_mm_bridge ADDRESS_WIDTH to 14 (= 64 KB)."""
    for mod in root.findall("module"):
        if mod.get("name") != "upload_mm_bridge":
            continue
        for p in mod.findall("parameter"):
            if p.get("name") == "ADDRESS_WIDTH":
                p.set("value", "14")
                return 1
    return 0


def serialize(tree: ET.ElementTree, path: Path) -> None:
    """Write back the .qsys, preserving the XML declaration. Qsys is
    tolerant of whitespace changes; the only fields it cares about are
    attribute values which ET preserves."""
    os.chmod(path, 0o644)
    tree.write(path, encoding="utf-8", xml_declaration=True)


def apply_file(path: Path, drops: list[str], rebase: dict, only_masters: set[str],
               widen: bool, label: str) -> None:
    print(f"=== {label}: {path.name} ===")
    tree = ET.parse(path)
    root = tree.getroot()
    for d in drops:
        n = drop_module(root, d)
        print(f"  dropped `{d}`: {n} elements removed")
    nb = rebase_connections(root, rebase, only_masters)
    print(f"  rebase: {nb} baseAddress values updated")
    if widen:
        nw = widen_upload_mm_bridge(root)
        print(f"  upload_mm_bridge widen: {nw} (ADDRESS_WIDTH->14)")
    serialize(tree, path)


# Masters whose view we rebase. Anything else (internal LVDS pipeline
# bridges, JTAG-to-rstctrl pipeline, etc.) keeps its existing baseAddress
# because its addressSpan is fixed to a small window.
DEBUG_SC_MASTERS = {
    "sc_hub_cmd_pipe.m0",
    "jtag_master.master",
    "mutrig_cfg_ctrl_0.avmm_cnt",      # cross-subsystem master into mm_bridge
}
SCIFI_DP_MASTERS = {
    "master_datapath.master",
}


def main() -> int:
    apply_file(DEBUG_SC, DROP_DEBUG_SC, REGION_A_REBASE, DEBUG_SC_MASTERS,
               widen=True, label="debug_sc_system_v4")
    for p in (SCIFI_DP_LOCAL, SCIFI_DP_GLOBAL):
        apply_file(p, DROP_SCIFI_DP, REGION_B_REBASE, SCIFI_DP_MASTERS,
                   widen=False, label="scifi_datapath_system_v4")
    return 0


if __name__ == "__main__":
    sys.exit(main())
