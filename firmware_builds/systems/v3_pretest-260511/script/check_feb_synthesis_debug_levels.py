#!/usr/bin/env python3
"""Check FEB v3 synthesis systems use the DEBUG=0 hardware contract.

Simulation regressions may elevate DEBUG_LEVEL/DEBUG_LV/DEBUG to 2 for
per-hit scoreboards. The synthesis Qsys systems must stay at 0 by default.
Use --allow-debug1 only for a deliberately marked debug-variant image.
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


DEBUG_PARAMETERS = {"DEBUG", "DEBUG_LEVEL", "DEBUG_LV"}
ZERO_ONLY_PARAMETERS = {"N_DEBUG_INTERFACE"}
BYTE_STREAM_PARAMETER = "BYTE_STREAM_ENABLE"
REQUIRED_DEBUG_PARAMETERS_BY_KIND = {
    "arb_hit_type0": "DEBUG_LEVEL",
    "emulator_mutrig": "DEBUG_LEVEL",
    "histogram_statistics_v2": "DEBUG",
    "hit_type0_readyless_mux4": "DEBUG_LEVEL",
    "mts_preprocessor": "DEBUG",
    "mutrig_frame_deassembly": "DEBUG_LV",
    "mutrig_reset_controller": "DEBUG",
}
FORBIDDEN_DEBUG_CONNECTION_PATTERNS = (
    "debug_hit_metadata",
    "hit_debug_metadata",
    "hit_type0_debug",
    "real_hit_debug",
    "emu_hit_debug",
    "selected_hit_debug",
    "selected_metadata",
    "hit_type0_sidecar",
    "hit_type1_sidecar",
)


@dataclass(frozen=True)
class Failure:
    path: Path
    where: str
    detail: str


def value_text(param: ET.Element) -> str:
    if param.get("value") is not None:
        return str(param.get("value")).strip()
    return (param.text or "").strip()


def parse_int(value: str) -> int | None:
    value = value.strip()
    if not value:
        return None
    try:
        return int(value, 0)
    except ValueError:
        return None


def check_qsys(path: Path, allowed_debug: set[int]) -> list[Failure]:
    failures: list[Failure] = []
    root = ET.parse(path).getroot()

    for module in root.findall("module"):
        inst = module.get("name", "<unnamed>")
        kind = module.get("kind", "<unknown>")
        seen_parameters = set()
        for param in module.findall("parameter"):
            name = param.get("name", "")
            seen_parameters.add(name)
            value = value_text(param)
            where = f"{inst} ({kind}) parameter {name}"
            if name in DEBUG_PARAMETERS:
                level = parse_int(value)
                if level not in allowed_debug:
                    failures.append(
                        Failure(path, where, f"value {value!r} not in allowed set {sorted(allowed_debug)}")
                    )
            elif name in ZERO_ONLY_PARAMETERS:
                level = parse_int(value)
                if level != 0:
                    failures.append(Failure(path, where, f"value {value!r} must be 0"))
            elif name == BYTE_STREAM_PARAMETER and value.lower() != "false":
                failures.append(Failure(path, where, f"value {value!r} must be false"))

        required_debug_param = REQUIRED_DEBUG_PARAMETERS_BY_KIND.get(kind)
        if required_debug_param and required_debug_param not in seen_parameters:
            failures.append(
                Failure(
                    path,
                    f"{inst} ({kind})",
                    f"missing top-down synthesis debug parameter {required_debug_param}",
                )
            )

    for connection in root.findall("connection"):
        start = connection.get("start", "")
        end = connection.get("end", "")
        combined = f"{start}/{end}"
        for pattern in FORBIDDEN_DEBUG_CONNECTION_PATTERNS:
            if pattern in combined:
                failures.append(
                    Failure(path, "connection", f"forbidden synthesis debug sidecar connection {combined!r}")
                )
                break

    return failures


VHDL_GENERIC_RE = re.compile(r"\b(DEBUG_LEVEL|DEBUG_LV|DEBUG)\s*=>\s*([0-9]+)\b")
VHDL_N_DEBUG_RE = re.compile(r"\bN_DEBUG_INTERFACE\s*=>\s*([0-9]+)\b")
VHDL_BYTE_STREAM_RE = re.compile(r"\bBYTE_STREAM_ENABLE\s*=>\s*(true|false)\b", re.IGNORECASE)
def check_vhdl(path: Path, allowed_debug: set[int]) -> list[Failure]:
    failures: list[Failure] = []
    text = path.read_text(encoding="utf-8", errors="replace")

    for match in VHDL_GENERIC_RE.finditer(text):
        name, value = match.groups()
        level = int(value)
        if level not in allowed_debug:
            line = text.count("\n", 0, match.start()) + 1
            failures.append(Failure(path, f"line {line} generic {name}", f"value {level} not allowed"))

    for match in VHDL_N_DEBUG_RE.finditer(text):
        level = int(match.group(1))
        if level != 0:
            line = text.count("\n", 0, match.start()) + 1
            failures.append(Failure(path, f"line {line} generic N_DEBUG_INTERFACE", f"value {level} must be 0"))

    for match in VHDL_BYTE_STREAM_RE.finditer(text):
        value = match.group(1).lower()
        if value != "false":
            line = text.count("\n", 0, match.start()) + 1
            failures.append(Failure(path, f"line {line} generic BYTE_STREAM_ENABLE", "must be false"))

    return failures


def default_paths(root: Path) -> list[Path]:
    return [
        root / "quartus_systems" / "mutrig_datapath_system_v3.qsys",
        root / "quartus_systems" / "scifi_datapath_system_v3.qsys",
        root / "quartus_systems" / "scifi_datapath_system_v3_pipe.qsys",
        root / "quartus_systems" / "scifi_datapath_system_v3_lat4.qsys",
        root / "quartus_systems" / "hit_stack_system.qsys",
        root / "quartus_systems" / "hit_stack_system_rbcam_snoop.qsys",
        root / "firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem.vhd",
        root / "firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem_hit_stack_subsystem_0.vhd",
        root / "firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3/synthesis/submodules/feb_system_v3_data_path_subsystem_hit_stack_subsystem_1.vhd",
    ]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[4],
        help="mu3e-ip-cores root; defaults to this script's repository root",
    )
    parser.add_argument(
        "--allow-debug1",
        action="store_true",
        help="Permit DEBUG/DEBUG_LEVEL/DEBUG_LV values of 1 for a debug-variant synthesis image",
    )
    parser.add_argument("paths", nargs="*", type=Path, help="Optional explicit .qsys/.vhd files to check")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = args.root.resolve()
    allowed_debug = {0, 1} if args.allow_debug1 else {0}
    paths = [p if p.is_absolute() else root / p for p in (args.paths or default_paths(root))]
    failures: list[Failure] = []
    checked = 0

    for path in paths:
        if not path.exists():
            print(f"SKIP missing {path}")
            continue
        checked += 1
        if path.suffix == ".qsys":
            failures.extend(check_qsys(path, allowed_debug))
        elif path.suffix in {".vhd", ".vhdl"}:
            failures.extend(check_vhdl(path, allowed_debug))
        else:
            failures.append(Failure(path, "file type", "unsupported suffix"))

    if failures:
        for failure in failures:
            print(f"FAIL {failure.path}: {failure.where}: {failure.detail}")
        print(f"checked={checked} failures={len(failures)} allowed_debug={sorted(allowed_debug)}")
        return 1

    print(f"PASS checked={checked} allowed_debug={sorted(allowed_debug)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
