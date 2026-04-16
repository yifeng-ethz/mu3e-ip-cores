#!/usr/bin/env python3
"""Run signoff baselines for isolated, bucket-frame, all-buckets-frame, and curated cross tests."""

from __future__ import annotations

import argparse
from collections import OrderedDict
import subprocess
import sys
from pathlib import Path
import re


BUCKET_FILES = OrderedDict(
    [
        ("BASIC", "DV_BASIC.md"),
        ("EDGE", "DV_EDGE.md"),
        ("PROF", "DV_PROF.md"),
        ("ERROR", "DV_ERROR.md"),
    ]
)
LIST_MARKER = "DOC_CASE_LIST_ENGINE_V1"
CROSS_MARKER = "FRCV_CROSS_ENGINE_V1"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ip-root", required=True, type=Path)
    parser.add_argument("--uvm-dir", required=True, type=Path)
    parser.add_argument("--rtl-variant", default="after")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--no-isolated-refresh", action="store_true")
    parser.add_argument("--refresh-all", action="store_true")
    return parser.parse_args()


def parse_doc_cases(doc_path: Path) -> list[str]:
    cases: list[str] = []
    for line in doc_path.read_text().splitlines():
        match = re.match(r"^\|\s*([BEPX]\d{3}[A-Za-z0-9_]*)\s*\|", line)
        if match:
            case_id = match.group(1)
            if case_id != "ID":
                cases.append(case_id)
    return cases


def load_case_lists(ip_root: Path) -> OrderedDict[str, list[str]]:
    tb_root = ip_root / "tb"
    case_lists: OrderedDict[str, list[str]] = OrderedDict()
    for bucket, filename in BUCKET_FILES.items():
        case_lists[bucket] = parse_doc_cases(tb_root / filename)
    return case_lists


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


def run_cmd(cmd: list[str], cwd: Path) -> None:
    result = subprocess.run(cmd, cwd=cwd)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def passed_run(uvm_dir: Path, run_id: str, rtl_variant: str, seed: int, marker: str) -> bool:
    log_path = uvm_dir / "logs" / f"{run_id}_{rtl_variant}_s{seed}.log"
    ucdb_path = uvm_dir / f"cov_{rtl_variant}" / f"{run_id}_s{seed}.ucdb"
    if not log_path.exists() or not ucdb_path.exists():
        return False
    log_text = log_path.read_text(errors="ignore")
    return marker in log_text and "*** TEST PASSED ***" in log_text


def clear_run_artifacts(uvm_dir: Path, run_id: str, rtl_variant: str, seed: int) -> None:
    log_path = uvm_dir / "logs" / f"{run_id}_{rtl_variant}_s{seed}.log"
    ucdb_path = uvm_dir / f"cov_{rtl_variant}" / f"{run_id}_s{seed}.ucdb"
    if log_path.exists():
        log_path.unlink()
    if ucdb_path.exists():
        ucdb_path.unlink()


def compile_build(uvm_dir: Path, rtl_variant: str, build: dict[str, str | int]) -> None:
    run_cmd(
        [
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
        ],
        uvm_dir,
    )


def run_named_test(
    uvm_dir: Path,
    rtl_variant: str,
    seed: int,
    build: dict[str, str | int],
    test: str,
    run_id: str,
    extra_plusargs: str,
) -> None:
    run_cmd(
        [
            "make",
            "-C",
            str(uvm_dir),
            "run_sim",
            f"TEST={test}",
            f"RTL_VARIANT={rtl_variant}",
            f"CHANNEL_WIDTH={build['channel_width']}",
            f"CSR_ADDR_WIDTH={build['csr_addr_width']}",
            f"MODE_HALT={build['mode_halt']}",
            f"DEBUG_LV={build['debug_lv']}",
            f"BUILD_TAG={build['build_tag']}",
            f"SEED={seed}",
            f"RUN_ID_OVERRIDE={run_id}",
            f"EXTRA_PLUSARGS={extra_plusargs}",
        ],
        uvm_dir,
    )


def maybe_run_named_test(
    uvm_dir: Path,
    rtl_variant: str,
    seed: int,
    build: dict[str, str | int],
    test: str,
    run_id: str,
    extra_plusargs: str,
    marker: str,
    refresh_all: bool,
) -> None:
    if not refresh_all and passed_run(uvm_dir, run_id, rtl_variant, seed, marker):
        print(f"[dv-signoff] skip {run_id}", flush=True)
        return
    clear_run_artifacts(uvm_dir, run_id, rtl_variant, seed)
    print(f"[dv-signoff] run  {run_id}", flush=True)
    run_named_test(uvm_dir, rtl_variant, seed, build, test, run_id, extra_plusargs)


def main() -> None:
    args = parse_args()
    ip_root = args.ip_root.resolve()
    if not (ip_root / "tb").exists() and (ip_root / "mutrig_frame_deassembly" / "tb").exists():
        ip_root = ip_root / "mutrig_frame_deassembly"
    uvm_dir = args.uvm_dir.resolve()
    case_lists = load_case_lists(ip_root)

    if not args.no_isolated_refresh:
      isolated_cmd = [
          sys.executable,
          str(Path(__file__).resolve().with_name("dv_batch_run_cases.py")),
          "--ip-root",
          str(ip_root),
          "--uvm-dir",
          str(uvm_dir),
          "--test",
          "frcv_doc_case_test",
          "--rtl-variant",
          args.rtl_variant,
          "--seed",
          str(args.seed),
      ]
      if args.refresh_all:
          isolated_cmd.append("--refresh-all")
      run_cmd(isolated_cmd, ip_root)

    build_groups: OrderedDict[tuple[int, int, int, int, str], list[str]] = OrderedDict()
    for bucket_cases in case_lists.values():
        for case_id in bucket_cases:
            build = case_build(case_id)
            key = (
                int(build["channel_width"]),
                int(build["csr_addr_width"]),
                int(build["mode_halt"]),
                int(build["debug_lv"]),
                str(build["build_tag"]),
            )
            build_groups.setdefault(key, []).append(case_id)

    for key, build_cases in build_groups.items():
        build = {
            "channel_width": key[0],
            "csr_addr_width": key[1],
            "mode_halt": key[2],
            "debug_lv": key[3],
            "build_tag": key[4],
        }
        pending_runs: list[tuple[str, str, str, str]] = []

        for bucket, bucket_cases in case_lists.items():
            selected = [case_id for case_id in bucket_cases if case_build(case_id)["build_tag"] == build["build_tag"]]
            if not selected:
                continue
            run_id = f"bucket_frame_{bucket.lower()}_{str(build['build_tag']).lower()}"
            case_list = ",".join(selected)
            extra = f"+FRCV_EXEC_MODE=bucket_frame +FRCV_CASE_LIST={case_list} +FRCV_SEQUENCE_NAME={bucket}_{build['build_tag']}"
            if args.refresh_all or not passed_run(uvm_dir, run_id, args.rtl_variant, args.seed, LIST_MARKER):
                pending_runs.append(("frcv_doc_case_list_test", run_id, extra, LIST_MARKER))

        all_cases = [case_id for case_id in build_cases]
        run_id = f"all_buckets_frame_{str(build['build_tag']).lower()}"
        extra = (
            f"+FRCV_EXEC_MODE=all_buckets_frame +FRCV_CASE_LIST={','.join(all_cases)} "
            f"+FRCV_SEQUENCE_NAME=ALL_{build['build_tag']}"
        )
        if args.refresh_all or not passed_run(uvm_dir, run_id, args.rtl_variant, args.seed, LIST_MARKER):
            pending_runs.append(("frcv_doc_case_list_test", run_id, extra, LIST_MARKER))

        if build["build_tag"] == "CFG_A":
            for cross_run_id, cross_extra in (
                ("cross_good_error_good_cfg_a", "+FRCV_EXEC_MODE=cross +FRCV_CROSS_PLAN=GOOD_ERROR_GOOD"),
                ("cross_interleave_mix_cfg_a", "+FRCV_EXEC_MODE=cross +FRCV_CROSS_PLAN=INTERLEAVE_MIX"),
            ):
                if args.refresh_all or not passed_run(uvm_dir, cross_run_id, args.rtl_variant, args.seed, CROSS_MARKER):
                    pending_runs.append(("frcv_cross_bucket_test", cross_run_id, cross_extra, CROSS_MARKER))

        if not pending_runs:
            print(f"[dv-signoff] skip build {build['build_tag']} (all signoff runs already passed)", flush=True)
            continue

        print(
            f"[dv-signoff] compile build={build['build_tag']} "
            f"cw={build['channel_width']} aw={build['csr_addr_width']} "
            f"mh={build['mode_halt']} dl={build['debug_lv']}",
            flush=True,
        )
        compile_build(uvm_dir, args.rtl_variant, build)

        for test, run_id, extra, marker in pending_runs:
            maybe_run_named_test(
                uvm_dir,
                args.rtl_variant,
                args.seed,
                build,
                test,
                run_id,
                extra,
                marker,
                args.refresh_all,
            )


if __name__ == "__main__":
    main()
