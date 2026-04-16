#!/usr/bin/env python3
"""Compile once, then run all documented DV cases through the UVM doc-case test."""

from __future__ import annotations

import argparse
from collections import OrderedDict
import re
import subprocess
import sys
from pathlib import Path


BUCKET_FILES = ("DV_BASIC.md", "DV_EDGE.md", "DV_PROF.md", "DV_ERROR.md")
ENGINE_MARKER = "DOC_CASE_ENGINE_V2"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ip-root", required=True, type=Path)
    parser.add_argument("--uvm-dir", required=True, type=Path)
    parser.add_argument("--test", required=True)
    parser.add_argument("--rtl-variant", default="after")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--refresh-all", action="store_true")
    return parser.parse_args()


def parse_doc_cases(doc_path: Path) -> list[str]:
    cases: list[str] = []
    for line in doc_path.read_text().splitlines():
        table_match = re.match(r"^\|\s*([BEPX]\d{3}[A-Za-z0-9_]*)\s*\|", line)
        if table_match:
            case_id = table_match.group(1)
            if case_id != "ID":
                cases.append(case_id)
            continue
        bullet_match = re.match(r"^-\s*`([BEPX]\d{3})\s*\|\s*([^`]+)`", line)
        if bullet_match:
            cases.append(bullet_match.group(2).strip())
    return cases


def case_list(ip_root: Path) -> list[str]:
    tb_root = ip_root / "tb"
    cases: list[str] = []
    for filename in BUCKET_FILES:
        cases.extend(parse_doc_cases(tb_root / filename))
    return cases


def case_build(case_id: str) -> dict[str, str | int]:
    low = case_id.lower()

    channel_width = 4
    csr_addr_width = 2
    mode_halt = 0
    debug_lv = 0
    build_tag = "CFG_A"

    if "cfgg" in low or "debuglv2" in low:
        debug_lv = 2
        build_tag = "CFG_G"
    elif "cfgf" in low or "addrwidth8" in low or "csr_addr_width8" in low:
        csr_addr_width = 8
        build_tag = "CFG_F"
    elif "cfge" in low or "addrwidth1" in low or "csr_addr_width1" in low:
        csr_addr_width = 1
        build_tag = "CFG_E"
    elif "cfgd" in low or "channel_width8" in low or "wide_channel" in low:
        channel_width = 8
        build_tag = "CFG_D"
    elif "cfgc" in low or "channel_width1" in low or "channel1" in low or "width1" in low:
        channel_width = 1
        build_tag = "CFG_C"
    elif "cfgb" in low or "mode_halt1" in low or "modehalt1" in low or "mode1" in low:
        mode_halt = 1
        build_tag = "CFG_B"

    return {
        "build_tag": build_tag,
        "channel_width": channel_width,
        "csr_addr_width": csr_addr_width,
        "mode_halt": mode_halt,
        "debug_lv": debug_lv,
    }


def passed_case(uvm_dir: Path, case_id: str, rtl_variant: str, seed: int) -> bool:
    log_path = uvm_dir / "logs" / f"{case_id}_{rtl_variant}_s{seed}.log"
    ucdb_path = uvm_dir / f"cov_{rtl_variant}" / f"{case_id}_s{seed}.ucdb"
    if not log_path.exists() or not ucdb_path.exists():
        return False
    log_text = log_path.read_text(errors="ignore")
    return ENGINE_MARKER in log_text and "*** TEST PASSED ***" in log_text


def run_cmd(cmd: list[str], cwd: Path) -> tuple[int, str]:
    result = subprocess.run(
        cmd,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    return result.returncode, result.stdout


def compile_uvm(uvm_dir: Path, rtl_variant: str, build: dict[str, str | int]) -> None:
    cmd = [
        "make",
        "-C",
        str(uvm_dir),
        "compile",
        f"RTL_VARIANT={rtl_variant}",
        f"CHANNEL_WIDTH={build['channel_width']}",
        f"CSR_ADDR_WIDTH={build['csr_addr_width']}",
        f"MODE_HALT={build['mode_halt']}",
        f"DEBUG_LV={build['debug_lv']}",
        f"BUILD_TAG={build['build_tag']}",
    ]
    rc, out = run_cmd(cmd, uvm_dir)
    if rc != 0:
      sys.stdout.write(out)
      raise SystemExit(rc)


def run_case(
    uvm_dir: Path,
    case_id: str,
    test: str,
    rtl_variant: str,
    seed: int,
    build: dict[str, str | int],
) -> tuple[int, str]:
    cmd = [
        "make",
        "-C",
        str(uvm_dir),
        "run_sim",
        f"TEST={test}",
        f"CASE_ID={case_id}",
        f"RTL_VARIANT={rtl_variant}",
        f"CHANNEL_WIDTH={build['channel_width']}",
        f"CSR_ADDR_WIDTH={build['csr_addr_width']}",
        f"MODE_HALT={build['mode_halt']}",
        f"DEBUG_LV={build['debug_lv']}",
        f"BUILD_TAG={build['build_tag']}",
        f"SEED={seed}",
    ]
    return run_cmd(cmd, uvm_dir)


def clean_case_artifacts(uvm_dir: Path, case_ids: list[str], rtl_variant: str, seed: int) -> None:
    for case_id in case_ids:
        log_path = uvm_dir / "logs" / f"{case_id}_{rtl_variant}_s{seed}.log"
        ucdb_path = uvm_dir / f"cov_{rtl_variant}" / f"{case_id}_s{seed}.ucdb"
        if log_path.exists():
            log_path.unlink()
        if ucdb_path.exists():
            ucdb_path.unlink()


def main() -> None:
    args = parse_args()
    ip_root = args.ip_root.resolve()
    uvm_dir = args.uvm_dir.resolve()
    cases = case_list(ip_root)
    build_groups: OrderedDict[tuple[int, int, int, int, str], list[str]] = OrderedDict()

    for case_id in cases:
        build = case_build(case_id)
        key = (
            int(build["channel_width"]),
            int(build["csr_addr_width"]),
            int(build["mode_halt"]),
            int(build["debug_lv"]),
            str(build["build_tag"]),
        )
        build_groups.setdefault(key, []).append(case_id)

    if args.refresh_all:
        clean_case_artifacts(uvm_dir, cases, args.rtl_variant, args.seed)

    total = len(cases)
    failures: list[str] = []
    executed = 0
    skipped = 0

    for key, group_cases in build_groups.items():
        build = {
            "channel_width": key[0],
            "csr_addr_width": key[1],
            "mode_halt": key[2],
            "debug_lv": key[3],
            "build_tag": key[4],
        }
        print(
            f"[dv-batch] compile {uvm_dir} variant={args.rtl_variant} build={build['build_tag']} "
            f"cw={build['channel_width']} aw={build['csr_addr_width']} mh={build['mode_halt']} dl={build['debug_lv']}",
            flush=True,
        )
        compile_uvm(uvm_dir, args.rtl_variant, build)

        for case_id in group_cases:
            idx = cases.index(case_id) + 1
            if not args.refresh_all and passed_case(uvm_dir, case_id, args.rtl_variant, args.seed):
                skipped += 1
                print(f"[dv-batch] skip {idx}/{total} {case_id}", flush=True)
                continue

            print(
                f"[dv-batch] run  {idx}/{total} {case_id} build={build['build_tag']}",
                flush=True,
            )
            rc, out = run_case(uvm_dir, case_id, args.test, args.rtl_variant, args.seed, build)
            executed += 1
            if rc != 0:
                failures.append(case_id)
                tail = "\n".join(out.splitlines()[-40:])
                print(f"[dv-batch] fail {case_id}\n{tail}", flush=True)

    print(
        f"[dv-batch] done total={total} executed={executed} skipped={skipped} failures={len(failures)}",
        flush=True,
    )
    if failures:
        print("[dv-batch] failing cases:", flush=True)
        for case_id in failures:
            print(case_id, flush=True)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
