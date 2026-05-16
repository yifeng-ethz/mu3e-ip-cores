#!/usr/bin/env python3
"""Generate and check FEB v3 generated-DUT SHA256 manifests.

The FEB build keeps two Qsys-generated RTL trees:
  * synthesis/       : DEBUG/DEBUG_LEVEL/DEBUG_LV = 0, used by firmware compile
  * synthesis_debug/ : DEBUG/DEBUG_LEVEL/DEBUG_LV = 2 where supported, used by tb_int

The manifest check catches stale or hand-edited generated DUT files before a
cosim build accidentally uses the wrong tree.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


RTL_SUFFIXES = {
    ".v",
    ".sv",
    ".svh",
    ".vhd",
    ".vhdl",
    ".qip",
    ".sdc",
    ".mif",
    ".hex",
    ".dat",
}
MANIFEST_NAME = ".qsys_dut_manifest.json"
DEBUG_PARAMETER_BY_KIND = {
    "arb_hit_type0": "DEBUG_LEVEL",
    "emulator_mutrig": "DEBUG_LEVEL",
    "feb_frame_assembly": "DEBUG",
    "firefly_xcvr_ctrl": "DEBUG",
    "hit_type0_readyless_mux4": "DEBUG_LEVEL",
    "histogram_statistics_v2": "DEBUG",
    "mts_preprocessor": "DEBUG",
    "mutrig_ctrl": "DEBUG",
    "mutrig_frame_deassembly": "DEBUG_LV",
    "ring_buffer_cam": "DEBUG",
    "runctl_mgmt_host": "DEBUG",
    "sc_hub_top": "DEBUG",
}
DEBUG_QSYS_RELATIVE_PATHS = (
    "quartus_systems/debug_sc_system_v3.qsys",
    "quartus_systems/scifi_datapath_system_v3.qsys",
    "quartus_systems/scifi_datapath_system_v3_pipe.qsys",
    "quartus_systems/scifi_datapath_system_v3_lat4.qsys",
    "quartus_systems/hit_stack_system.qsys",
    "quartus_systems/hit_stack_system_rbcam_snoop.qsys",
    "quartus_systems/mutrig_datapath_system_v3.qsys",
    "quartus_systems/upload_system_v3.qsys",
)
DEBUG_GENERIC_NAMES = {"DEBUG", "DEBUG_LEVEL", "DEBUG_LV"}


@dataclass(frozen=True)
class FileHash:
    path: str
    sha256: str
    size: int


def repo_root_from_script() -> Path:
    return Path(__file__).resolve().parents[4]


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def iter_manifest_files(dut_dir: Path) -> list[Path]:
    files: list[Path] = []
    for path in dut_dir.rglob("*"):
        if not path.is_file():
            continue
        if path.name == MANIFEST_NAME:
            continue
        if path.suffix.lower() in RTL_SUFFIXES:
            files.append(path)
    return sorted(files, key=lambda p: p.relative_to(dut_dir).as_posix())


def collect_file_hashes(dut_dir: Path) -> list[FileHash]:
    return [
        FileHash(
            path=path.relative_to(dut_dir).as_posix(),
            sha256=sha256_file(path),
            size=path.stat().st_size,
        )
        for path in iter_manifest_files(dut_dir)
    ]


def tree_sha256(files: list[FileHash]) -> str:
    h = hashlib.sha256()
    for entry in files:
        h.update(f"{entry.sha256}  {entry.path}\n".encode("utf-8"))
    return h.hexdigest()


def manifest_path_for(dut_dir: Path, manifest: Path | None) -> Path:
    return manifest if manifest is not None else dut_dir / MANIFEST_NAME


def write_manifest(args: argparse.Namespace) -> int:
    dut_dir = args.dut_dir.resolve()
    if not dut_dir.is_dir():
        print(f"ERROR: DUT directory does not exist: {dut_dir}", file=sys.stderr)
        return 2

    files = collect_file_hashes(dut_dir)
    qsys_hash = sha256_file(args.qsys.resolve()) if args.qsys and args.qsys.exists() else None
    data = {
        "schema": "feb-qsys-generated-dut-manifest-v1",
        "created_unix": int(time.time()),
        "variant": args.variant,
        "dut_dir": str(dut_dir),
        "qsys": str(args.qsys.resolve()) if args.qsys else None,
        "qsys_sha256": qsys_hash,
        "file_count": len(files),
        "tree_sha256": tree_sha256(files),
        "files": [entry.__dict__ for entry in files],
    }
    manifest = manifest_path_for(dut_dir, args.manifest)
    manifest.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"MANIFEST wrote {manifest} files={len(files)} tree_sha256={data['tree_sha256']}")
    return 0


def check_manifest(args: argparse.Namespace) -> int:
    dut_dir = args.dut_dir.resolve()
    manifest = manifest_path_for(dut_dir, args.manifest)
    if not manifest.exists():
        print(f"WARN: generated DUT manifest missing: {manifest}")
        return 0 if args.warn_only else 1
    if not dut_dir.is_dir():
        print(f"WARN: generated DUT directory missing: {dut_dir}")
        return 0 if args.warn_only else 1

    expected = json.loads(manifest.read_text(encoding="utf-8"))
    actual_files = {entry.path: entry for entry in collect_file_hashes(dut_dir)}
    expected_files = {
        entry["path"]: FileHash(entry["path"], entry["sha256"], int(entry["size"]))
        for entry in expected.get("files", [])
    }

    warnings: list[str] = []
    for rel in sorted(set(expected_files) - set(actual_files)):
        warnings.append(f"missing generated DUT file {rel}")
    for rel in sorted(set(actual_files) - set(expected_files)):
        warnings.append(f"unexpected generated DUT file {rel}")
    for rel in sorted(set(expected_files) & set(actual_files)):
        exp = expected_files[rel]
        act = actual_files[rel]
        if exp.sha256 != act.sha256:
            warnings.append(f"sha256 mismatch {rel}: manifest={exp.sha256} actual={act.sha256}")
        if exp.size != act.size:
            warnings.append(f"size mismatch {rel}: manifest={exp.size} actual={act.size}")

    actual_tree = tree_sha256([actual_files[rel] for rel in sorted(actual_files)])
    if expected.get("tree_sha256") != actual_tree:
        warnings.append(
            f"tree sha256 mismatch: manifest={expected.get('tree_sha256')} actual={actual_tree}"
        )

    warnings.extend(check_debug_contract(dut_dir, args.variant))

    if warnings:
        for warning in warnings:
            print(f"WARN: {warning}")
        print(f"WARN: generated DUT manifest check failed for {dut_dir}")
        return 0 if args.warn_only else 1

    print(f"PASS generated DUT manifest {manifest} files={len(actual_files)} tree_sha256={actual_tree}")
    return 0


def debug_generic_values(dut_dir: Path) -> list[tuple[Path, int, str, int]]:
    import re

    generic_re = re.compile(r"\b(DEBUG_LEVEL|DEBUG_LV|DEBUG)\s*=>\s*([0-9]+)\b")
    values: list[tuple[Path, int, str, int]] = []
    for path in sorted(dut_dir.rglob("*.vhd")):
        text = path.read_text(encoding="utf-8", errors="replace")
        for match in generic_re.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            values.append((path, line, match.group(1), int(match.group(2))))
    return values


def check_debug_contract(dut_dir: Path, variant: str) -> list[str]:
    warnings: list[str] = []
    values = debug_generic_values(dut_dir)
    if variant in {"synthesis", "normal", "compile"}:
        for path, line, name, value in values:
            if value != 0:
                warnings.append(f"{path}:{line} {name} => {value}; compile DUT must use 0")
    elif variant in {"synthesis_debug", "debug", "sim"}:
        if not any(value == 2 for _, _, name, value in values if name in DEBUG_GENERIC_NAMES):
            warnings.append("debug DUT has no generated DEBUG/DEBUG_LEVEL/DEBUG_LV generic set to 2")
        for path, line, name, value in values:
            if value not in {0, 2}:
                warnings.append(f"{path}:{line} {name} => {value}; debug DUT expects only 0 or 2")
    return warnings


def value_text(param: ET.Element) -> str:
    if param.get("value") is not None:
        return str(param.get("value"))
    return param.text or ""


def set_value_text(param: ET.Element, value: int) -> None:
    if param.get("value") is not None:
        param.set("value", str(value))
    else:
        param.text = str(value)


def debug_patch_qsys(src: Path, dst: Path, debug_level: int) -> int:
    tree = ET.parse(src)
    root = tree.getroot()
    changed = 0
    for module in root.findall("module"):
        kind = module.get("kind", "")
        expected_param = DEBUG_PARAMETER_BY_KIND.get(kind)
        if expected_param is None:
            continue
        for param in module.findall("parameter"):
            if param.get("name") == expected_param:
                if value_text(param).strip() != str(debug_level):
                    set_value_text(param, debug_level)
                    changed += 1
                break
    dst.parent.mkdir(parents=True, exist_ok=True)
    tree.write(dst, encoding="utf-8", xml_declaration=True, short_empty_elements=True)
    return changed


def make_debug_qsys_tree(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    out_dir = args.out_dir.resolve()
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    top_src = args.top_qsys.resolve()
    top_dst = out_dir / top_src.name
    changed = debug_patch_qsys(top_src, top_dst, args.debug_level)
    copied = 1
    for rel in DEBUG_QSYS_RELATIVE_PATHS:
        src = root / rel
        if not src.exists():
            continue
        dst = out_dir / rel
        changed += debug_patch_qsys(src, dst, args.debug_level)
        copied += 1

    summary = {
        "schema": "feb-qsys-debug-source-tree-v1",
        "created_unix": int(time.time()),
        "debug_level": args.debug_level,
        "top_qsys": str(top_dst),
        "copied_qsys_files": copied,
        "changed_parameters": changed,
    }
    (out_dir / "debug_qsys_tree.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(
        f"DEBUG_QSYS wrote {out_dir} copied_qsys={copied} changed_parameters={changed} top={top_dst}"
    )
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    common_manifest = argparse.ArgumentParser(add_help=False)
    common_manifest.add_argument("--dut-dir", required=True, type=Path)
    common_manifest.add_argument("--variant", required=True)
    common_manifest.add_argument("--manifest", type=Path)

    write = sub.add_parser("write", parents=[common_manifest])
    write.add_argument("--qsys", type=Path)
    write.set_defaults(func=write_manifest)

    check = sub.add_parser("check", parents=[common_manifest])
    check.add_argument("--warn-only", action="store_true")
    check.set_defaults(func=check_manifest)

    mkdbg = sub.add_parser("make-debug-qsys-tree")
    mkdbg.add_argument("--root", type=Path, default=repo_root_from_script())
    mkdbg.add_argument("--top-qsys", required=True, type=Path)
    mkdbg.add_argument("--out-dir", required=True, type=Path)
    mkdbg.add_argument("--debug-level", type=int, default=2)
    mkdbg.set_defaults(func=make_debug_qsys_tree)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
