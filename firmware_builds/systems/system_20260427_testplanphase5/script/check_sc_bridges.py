#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import (
    DEFAULT_JTAG_FALLBACK_PATTERN,
    DEFAULT_JTAG_MASTER_PATTERN,
    _default_jdi,
    _default_project_dir,
    _default_sc_tool,
    _default_system_console,
    jtag_rw,
    sc_read,
    sc_write,
)
from svd_inventory_lib import REPO_ROOT, SYN_DIR, collect_manifest, load_svd_metadata


BOARD_TEST_DIR = SCRIPT_DIR.parent

HISTOGRAM_SVD = REPO_ROOT / "histogram_statistics" / "histogram_statistics.svd"
HISTOGRAM_INGRESS_SVD = REPO_ROOT / "histogram_statistics" / "histogram_ingress_bridge.svd"
RUNCTL_SVD = REPO_ROOT / "run-control_mgmt" / "runctl_mgmt_host.svd"


def fmt_hex(value: int) -> str:
    return f"0x{value:08X}"


def load_uid_reset_value(svd_path: Path) -> int:
    root = ET.parse(svd_path).getroot()
    for reg_name in ("UID", "ID"):
        reg = root.find(f".//register[name='{reg_name}']")
        if reg is None:
            continue
        reset_value = reg.findtext("resetValue")
        if reset_value:
            return int(reset_value, 0)
    raise RuntimeError(f"failed to locate UID/ID resetValue in {svd_path}")


def load_address_map(path: Path) -> dict[str, int]:
    text = path.read_text(encoding="utf-8")
    match = re.search(
        r'name="AUTO_AVMM_PORT_ADDRESS_MAP".*?<!\[CDATA\[(<address-map>.*?</address-map>)\]\]>',
        text,
        flags=re.DOTALL,
    )
    if not match:
        raise RuntimeError(f"AUTO_AVMM_PORT_ADDRESS_MAP not found in {path}")

    inner_root = ET.fromstring(match.group(1))
    result: dict[str, int] = {}
    for node in inner_root.findall("./slave"):
        name = node.attrib.get("name")
        start = node.attrib.get("start")
        if not name or start is None:
            continue
        result[name] = int(start, 0)
    return result


def load_downstream_map(sopcinfo_path: Path, qsys_path: Path) -> dict[str, int]:
    errors: list[str] = []
    for path in (sopcinfo_path, qsys_path):
        try:
            return load_address_map(path)
        except Exception as exc:
            errors.append(f"{path}: {exc}")
    raise RuntimeError(" ; ".join(errors))


def get_manifest_entry(manifest: dict[str, Any], instance: str) -> dict[str, Any]:
    for entry in manifest["instances"]:
        if entry["instance"] == instance:
            return entry
    raise RuntimeError(f"instance {instance} not found in {manifest['qsys_path']}")


def run_check(
    results: list[dict[str, Any]],
    name: str,
    fn,
) -> None:
    try:
        details = fn()
        results.append({"name": name, "status": "PASS", "details": details})
    except Exception as exc:
        results.append({"name": name, "status": "FAIL", "details": str(exc)})


def add_pass(results: list[dict[str, Any]], name: str, details: Any) -> None:
    results.append({"name": name, "status": "PASS", "details": details})


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Audit the SC-exposed datapath and upload bridge apertures for FEB SciFi v3."
    )
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument("--system-console", type=Path, default=_default_system_console())
    parser.add_argument("--jdi", type=Path, default=_default_jdi())
    parser.add_argument("--project-dir", type=Path, default=_default_project_dir())
    parser.add_argument(
        "--debug-qsys",
        type=Path,
        default=SYN_DIR / "debug_sc_system_v3.qsys",
    )
    parser.add_argument(
        "--feb-qsys",
        type=Path,
        default=SYN_DIR / "feb_system_v3_pipe.qsys",
    )
    parser.add_argument(
        "--sopcinfo",
        type=Path,
        default=SYN_DIR / "feb_system_v3_pipe.sopcinfo",
    )
    parser.add_argument("--skip-jtag", action="store_true")
    parser.add_argument(
        "--jtag-master-pattern",
        default=os.environ.get("BOARD_TEST_JTAG_MASTER_PATTERN", DEFAULT_JTAG_MASTER_PATTERN),
        help="Primary System Console master-service glob for JTAG bridge reads.",
    )
    parser.add_argument(
        "--jtag-fallback-pattern",
        default=os.environ.get("BOARD_TEST_JTAG_FALLBACK_PATTERN", DEFAULT_JTAG_FALLBACK_PATTERN),
        help="Comma-separated fallback System Console master-service globs.",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of human-readable lines.")
    args = parser.parse_args()

    manifest = collect_manifest(args.debug_qsys.resolve())
    mm_bridge = get_manifest_entry(manifest, "mm_bridge")
    upload_bridge = get_manifest_entry(manifest, "upload_mm_bridge")

    mm_bridge_sc_base = int(mm_bridge["transports"]["sc"]["base_word"])
    upload_bridge_sc_base = int(upload_bridge["transports"]["sc"]["base_word"])
    upload_bridge_jtag_base = int(upload_bridge["transports"]["jtag"]["base_byte"])

    downstream_map = load_downstream_map(args.sopcinfo.resolve(), args.feb_qsys.resolve())

    histogram_svd = load_svd_metadata(HISTOGRAM_SVD)
    histogram_ingress_svd = load_svd_metadata(HISTOGRAM_INGRESS_SVD)
    runctl_svd = load_svd_metadata(RUNCTL_SVD)
    if histogram_svd is None or histogram_ingress_svd is None or runctl_svd is None:
        raise RuntimeError("required SVD metadata could not be loaded")

    histogram_uid_expected = load_uid_reset_value(HISTOGRAM_SVD)
    histogram_ingress_uid_expected = load_uid_reset_value(HISTOGRAM_INGRESS_SVD)
    runctl_uid_expected = load_uid_reset_value(RUNCTL_SVD)
    runctl_version_expected = runctl_svd["packed_device_version"]
    if runctl_version_expected is None:
        raise RuntimeError("runctl_mgmt_host SVD is missing a packed device version")

    checks: list[dict[str, Any]] = []

    def hist_uid_check(instance_name: str) -> dict[str, Any]:
        offset = downstream_map[f"{instance_name}.csr"] // 4
        addr = mm_bridge_sc_base + offset
        value = sc_read(args.sc_tool, args.link, addr, 1)[0]
        if value != histogram_uid_expected:
            raise RuntimeError(
                f"{instance_name} UID mismatch: got {fmt_hex(value)}, expected {fmt_hex(histogram_uid_expected)}"
            )
        return {"sc_addr": f"0x{addr:05X}", "uid": fmt_hex(value)}

    def emulator_probe() -> dict[str, Any]:
        base = mm_bridge_sc_base + downstream_map["data_path_subsystem_emulator_mutrig_0.csr"] // 4
        words = sc_read(args.sc_tool, args.link, base, 2)
        return {
            "sc_addr": f"0x{base:05X}",
            "uid_raw": fmt_hex(words[0]),
            "version_raw": fmt_hex(words[1]),
        }

    def dbg_mm2runctrl_probe() -> dict[str, Any]:
        base = mm_bridge_sc_base + downstream_map["data_path_subsystem_dbg_mm2runctrl_0.csr"] // 4
        value = sc_read(args.sc_tool, args.link, base, 1)[0]
        return {"sc_addr": f"0x{base:05X}", "word0": fmt_hex(value)}

    def histogram_ingress_probe() -> dict[str, Any]:
        base = mm_bridge_sc_base + downstream_map["data_path_subsystem_histogram_ingress_bridge_0.csr"] // 4
        uid = sc_read(args.sc_tool, args.link, base, 1)[0]
        if uid != histogram_ingress_uid_expected:
            raise RuntimeError(
                "histogram_ingress_bridge_0 UID mismatch: "
                f"got {fmt_hex(uid)}, expected {fmt_hex(histogram_ingress_uid_expected)}"
            )
        status = sc_read(args.sc_tool, args.link, base + histogram_ingress_svd["registers"]["STATUS"] // 4, 1)[0]
        return {
            "uid_addr": f"0x{base:05X}",
            "status_addr": f"0x{base + histogram_ingress_svd['registers']['STATUS'] // 4:05X}",
            "uid": fmt_hex(uid),
            "status": fmt_hex(status),
        }

    def runctl_sc_check() -> dict[str, Any]:
        uid_addr = upload_bridge_sc_base + runctl_svd["registers"]["UID"] // 4
        meta_addr = upload_bridge_sc_base + runctl_svd["registers"]["META"] // 4
        status_addr = upload_bridge_sc_base + runctl_svd["registers"]["STATUS"] // 4
        last_cmd_addr = upload_bridge_sc_base + runctl_svd["registers"]["LAST_CMD"] // 4
        rx_cmd_count_addr = upload_bridge_sc_base + runctl_svd["registers"]["RX_CMD_COUNT"] // 4
        local_cmd_addr = upload_bridge_sc_base + runctl_svd["registers"]["LOCAL_CMD"] // 4

        uid = sc_read(args.sc_tool, args.link, uid_addr, 1)[0]
        if uid != runctl_uid_expected:
            raise RuntimeError(f"runctl UID mismatch: got {fmt_hex(uid)}, expected {fmt_hex(runctl_uid_expected)}")

        sc_write(args.sc_tool, args.link, meta_addr, [0])
        version = sc_read(args.sc_tool, args.link, meta_addr, 1)[0]
        if version != runctl_version_expected:
            raise RuntimeError(
                f"runctl META/version mismatch: got {fmt_hex(version)}, expected {fmt_hex(runctl_version_expected)}"
            )

        status = sc_read(args.sc_tool, args.link, status_addr, 1)[0]
        last_cmd = sc_read(args.sc_tool, args.link, last_cmd_addr, 1)[0]
        rx_cmd_count = sc_read(args.sc_tool, args.link, rx_cmd_count_addr, 1)[0]
        local_cmd = sc_read(args.sc_tool, args.link, local_cmd_addr, 1)[0]
        return {
            "uid_addr": f"0x{uid_addr:05X}",
            "meta_addr": f"0x{meta_addr:05X}",
            "status_addr": f"0x{status_addr:05X}",
            "last_cmd_addr": f"0x{last_cmd_addr:05X}",
            "rx_cmd_count_addr": f"0x{rx_cmd_count_addr:05X}",
            "local_cmd_addr": f"0x{local_cmd_addr:05X}",
            "uid": fmt_hex(uid),
            "version": fmt_hex(version),
            "status": fmt_hex(status),
            "last_cmd": fmt_hex(last_cmd),
            "rx_cmd_count": fmt_hex(rx_cmd_count),
            "local_cmd": fmt_hex(local_cmd),
        }

    def runctl_jtag_check() -> dict[str, Any]:
        uid_offset = int(runctl_svd["registers"]["UID"])
        meta_offset = int(runctl_svd["registers"]["META"])
        status_offset = int(runctl_svd["registers"]["STATUS"])
        last_cmd_offset = int(runctl_svd["registers"]["LAST_CMD"])
        local_cmd_offset = int(runctl_svd["registers"]["LOCAL_CMD"])

        uid = jtag_rw(
            args.system_console,
            args.jdi,
            args.project_dir,
            "read",
            upload_bridge_jtag_base + uid_offset,
            count=1,
            master_pattern=args.jtag_master_pattern,
            fallback_pattern=args.jtag_fallback_pattern,
        )[0]
        if uid != runctl_uid_expected:
            raise RuntimeError(f"JTAG runctl UID mismatch: got {fmt_hex(uid)}, expected {fmt_hex(runctl_uid_expected)}")

        jtag_rw(
            args.system_console,
            args.jdi,
            args.project_dir,
            "write",
            upload_bridge_jtag_base + meta_offset,
            data=[0],
            master_pattern=args.jtag_master_pattern,
            fallback_pattern=args.jtag_fallback_pattern,
        )
        version = jtag_rw(
            args.system_console,
            args.jdi,
            args.project_dir,
            "read",
            upload_bridge_jtag_base + meta_offset,
            count=1,
            master_pattern=args.jtag_master_pattern,
            fallback_pattern=args.jtag_fallback_pattern,
        )[0]
        if version != runctl_version_expected:
            raise RuntimeError(
                f"JTAG runctl META/version mismatch: got {fmt_hex(version)}, expected {fmt_hex(runctl_version_expected)}"
            )

        status = jtag_rw(
            args.system_console,
            args.jdi,
            args.project_dir,
            "read",
            upload_bridge_jtag_base + status_offset,
            count=1,
            master_pattern=args.jtag_master_pattern,
            fallback_pattern=args.jtag_fallback_pattern,
        )[0]
        last_cmd = jtag_rw(
            args.system_console,
            args.jdi,
            args.project_dir,
            "read",
            upload_bridge_jtag_base + last_cmd_offset,
            count=1,
            master_pattern=args.jtag_master_pattern,
            fallback_pattern=args.jtag_fallback_pattern,
        )[0]
        local_cmd = jtag_rw(
            args.system_console,
            args.jdi,
            args.project_dir,
            "read",
            upload_bridge_jtag_base + local_cmd_offset,
            count=1,
            master_pattern=args.jtag_master_pattern,
            fallback_pattern=args.jtag_fallback_pattern,
        )[0]
        return {
            "uid_addr": fmt_hex(upload_bridge_jtag_base + uid_offset),
            "meta_addr": fmt_hex(upload_bridge_jtag_base + meta_offset),
            "status_addr": fmt_hex(upload_bridge_jtag_base + status_offset),
            "last_cmd_addr": fmt_hex(upload_bridge_jtag_base + last_cmd_offset),
            "local_cmd_addr": fmt_hex(upload_bridge_jtag_base + local_cmd_offset),
            "uid": fmt_hex(uid),
            "version": fmt_hex(version),
            "status": fmt_hex(status),
            "last_cmd": fmt_hex(last_cmd),
            "local_cmd": fmt_hex(local_cmd),
        }

    run_check(checks, "mm_bridge.histogram_statistics_0.uid", lambda: hist_uid_check("data_path_subsystem_histogram_statistics_0"))
    if "data_path_subsystem_histogram_statistics_1.csr" in downstream_map:
        run_check(checks, "mm_bridge.histogram_statistics_1.uid", lambda: hist_uid_check("data_path_subsystem_histogram_statistics_1"))
    else:
        add_pass(
            checks,
            "mm_bridge.histogram_statistics_1.uid",
            {
                "note": "not present in current downstream map",
                "topology": "single histogram_statistics_0 instance fed by histogram_ingress_bridge_0",
            },
        )
    run_check(checks, "mm_bridge.histogram_ingress_bridge_0.uid_status", histogram_ingress_probe)
    run_check(checks, "mm_bridge.emulator_mutrig_0.reachability", emulator_probe)
    run_check(checks, "mm_bridge.dbg_mm2runctrl_0.reachability", dbg_mm2runctrl_probe)
    run_check(checks, "upload_mm_bridge.runctl.sc", runctl_sc_check)
    if not args.skip_jtag:
        run_check(checks, "upload_mm_bridge.runctl.jtag", runctl_jtag_check)

    failures = [item for item in checks if item["status"] != "PASS"]
    payload = {
        "debug_qsys": str(args.debug_qsys),
        "feb_qsys": str(args.feb_qsys),
        "sopcinfo": str(args.sopcinfo),
        "mm_bridge_sc_base": f"0x{mm_bridge_sc_base:05X}",
        "upload_bridge_sc_base": f"0x{upload_bridge_sc_base:05X}",
        "upload_bridge_jtag_base": fmt_hex(upload_bridge_jtag_base),
        "jtag_master_pattern": args.jtag_master_pattern,
        "jtag_fallback_pattern": args.jtag_fallback_pattern,
        "checks": checks,
    }

    if args.json:
        json.dump(payload, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
    else:
        for item in checks:
            print(f"{item['status']} {item['name']}")
            if isinstance(item["details"], dict):
                for key, value in item["details"].items():
                    print(f"  {key}: {value}")
            else:
                print(f"  {item['details']}")
        print(f"SUMMARY pass={len(checks) - len(failures)} fail={len(failures)}")

    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
