#!/usr/bin/env python3
"""Swap the OLD lvds_rx_28nm_0 + lvds_rx_controller_pro_0 pair for
the NEW mu3e_lvds_controller_0 (which folds the PHY HIP into the
controller) in scifi_datapath_system_v4.qsys.

The new IP exposes the same interface contract as the old controller
plus a `serial` conduit (the LVDS pad pair previously on the PHY) and
an `inclock` sink (the refclk previously on the PHY). Internal coupling
ports `parallel` and `ctrl` between the old PHY and old controller go
away because the new IP folds both.

Rename map (start/end attribute substitution on every connection):
    lvds_rx_28nm_0.outclock          -> mu3e_lvds_controller_0.outclock
    lvds_rx_28nm_0.serial            -> mu3e_lvds_controller_0.serial
    lvds_rx_28nm_0.inclock           -> mu3e_lvds_controller_0.inclock
    lvds_rx_controller_pro_0.csr        -> mu3e_lvds_controller_0.csr
    lvds_rx_controller_pro_0.decoded%d  -> mu3e_lvds_controller_0.decoded%d  (0..8)
    lvds_rx_controller_pro_0.control_clock  -> mu3e_lvds_controller_0.control_clock
    lvds_rx_controller_pro_0.control_reset  -> mu3e_lvds_controller_0.control_reset
    lvds_rx_controller_pro_0.data_reset     -> mu3e_lvds_controller_0.data_reset
    lvds_rx_controller_pro_0.redriver       -> mu3e_lvds_controller_0.redriver

Connections dropped (no longer needed; data_clock/parallel/ctrl are
folded internally on the new IP):
    lvds_rx_28nm_0.outclock     -> lvds_rx_controller_pro_0.data_clock
    lvds_rx_controller_pro_0.ctrl     <-> lvds_rx_28nm_0.ctrl
    lvds_rx_28nm_0.parallel           <-> lvds_rx_controller_pro_0.parallel

Exported interfaces (`<interface name="..." internal="...">`) get the
same rename applied to their `internal` attribute.

Old modules dropped. New module inserted with the right parameters
(N_LANE=9, SYNC_PATTERN=0x0FA, DECODED_USE_CHANNEL is implicit in the
new IP — the new IP always emits the channel field).
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

OLD_PHY   = "lvds_rx_28nm_0"
OLD_CTRL  = "lvds_rx_controller_pro_0"
NEW_IP    = "mu3e_lvds_controller_0"
NEW_KIND  = "mu3e_lvds_controller"
NEW_VER   = "26.2.1.506"   # matches the new IP hw.tcl VERSION_STRING


def rename_endpoint(s: str) -> str:
    """Map an old start/end string to the new endpoint. Returns the
    original string if no rename rule matches."""
    if not s or "." not in s:
        return s
    mod, port = s.split(".", 1)
    if mod == OLD_PHY:
        if port in ("outclock", "serial", "inclock"):
            return f"{NEW_IP}.{port}"
        # parallel/ctrl conduits are gone; signal caller to drop
        if port in ("parallel", "ctrl"):
            return ""
        return s
    if mod == OLD_CTRL:
        if port in ("csr", "control_clock", "control_reset", "data_reset",
                    "redriver"):
            return f"{NEW_IP}.{port}"
        if port.startswith("decoded"):
            return f"{NEW_IP}.{port}"
        if port == "data_clock":
            # absorbed; drop the connection
            return ""
        if port in ("parallel", "ctrl"):
            return ""
        return s
    return s


def transform_connections(root: ET.Element) -> tuple[int, int]:
    """Rename or drop connections. Returns (renamed_count, dropped_count)."""
    renamed = dropped = 0
    for conn in list(root.findall("connection")):
        start_old = conn.get("start", "")
        end_old   = conn.get("end", "")
        start_new = rename_endpoint(start_old)
        end_new   = rename_endpoint(end_old)
        if start_new == "" or end_new == "":
            # internal PHY<->controller coupling no longer needed
            root.remove(conn)
            dropped += 1
            continue
        changed = False
        if start_new != start_old:
            conn.set("start", start_new)
            changed = True
        if end_new != end_old:
            conn.set("end", end_new)
            changed = True
        if changed:
            renamed += 1
            # also update the auto-generated `name` attr if present
            n = conn.get("name", "")
            if n and ("/" in n) and (OLD_PHY in n or OLD_CTRL in n):
                conn.set("name", f"{start_new}/{end_new}")
    return renamed, dropped


def transform_interfaces(root: ET.Element) -> int:
    """Rename `<interface internal="...">` exports to the new IP."""
    n = 0
    for itf in root.findall("interface"):
        old = itf.get("internal", "")
        new = rename_endpoint(old)
        if new and new != old:
            itf.set("internal", new)
            n += 1
        elif new == "" and old:
            # this would be a parallel/ctrl interface — shouldn't exist at top,
            # but if it did we'd drop it
            root.remove(itf)
            n += 1
    return n


def drop_old_modules(root: ET.Element) -> int:
    n = 0
    for child in list(root):
        if child.tag == "module" and child.get("name") in (OLD_PHY, OLD_CTRL):
            root.remove(child)
            n += 1
    return n


def add_new_module(root: ET.Element, n_lane: int) -> None:
    """Insert the mu3e_lvds_controller_0 module element."""
    mod = ET.Element("module", {
        "name":    NEW_IP,
        "kind":    NEW_KIND,
        "version": NEW_VER,
        "enabled": "1",
    })
    params = [
        ("N_LANE",          str(n_lane)),
        ("N_ENGINE",        "1"),
        ("ROUTING_TOPOLOGY","1"),
        ("SCORE_WINDOW_W",  "10"),
        ("SCORE_ACCEPT",    "8"),
        ("SCORE_REJECT",    "2"),
        ("STEER_QUEUE_DEPTH","4"),
        ("SYNC_PATTERN",    "0x0FA"),
        ("DEBUG_LEVEL",     "0"),
        ("IP_UID",          "0x4C564453"),
        ("INSTANCE_ID",     "0"),
        ("VERSION_MAJOR",   "26"),
        ("VERSION_MINOR",   "2"),
        ("VERSION_PATCH",   "1"),
        ("BUILD",           "0x506"),
        ("VERSION_DATE",    "0x20260506"),
        ("VERSION_GIT",     "0"),
    ]
    for name, val in params:
        ET.SubElement(mod, "parameter", {"name": name, "value": val})
    # Insert near the spot where old PHY was (append at the end is fine for Qsys)
    root.append(mod)


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
    # 1) rename / drop connections
    r, d = transform_connections(root)
    print(f"  connections: renamed={r}  dropped={d}")
    # 2) rename interface exports
    i = transform_interfaces(root)
    print(f"  exported interfaces: renamed={i}")
    # 3) drop old modules
    m = drop_old_modules(root)
    print(f"  old modules dropped: {m}")
    # 4) insert new module (only if not already present)
    has_new = any(
        c.tag == "module" and c.get("name") == NEW_IP for c in root)
    if not has_new:
        add_new_module(root, n_lane=9)
        print(f"  new module `{NEW_IP}` inserted (kind={NEW_KIND}, N_LANE=9)")
    else:
        print(f"  new module already present, no-op")
    serialize(tree, path)


def main() -> int:
    for p in (SCIFI_DP_GLOBAL, SCIFI_DP_LOCAL):
        apply(p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
