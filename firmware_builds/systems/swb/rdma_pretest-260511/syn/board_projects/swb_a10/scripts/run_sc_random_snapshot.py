#!/usr/bin/env python3
"""Random SC write stress with final full scratchpad snapshot compare."""

from __future__ import annotations

import argparse
import importlib.util
import json
import random
import types
from pathlib import Path


ROOT_DIR = Path("/home/yifeng/packages/online_sc/online")
SWEEP_TOOL = ROOT_DIR / "switching_pc/tools/sc_scratchpad_sweep.py"


def load_sweep_module():
    spec = importlib.util.spec_from_file_location("sc_sweep", SWEEP_TOOL)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def pick_test_bin(root_dir: Path) -> Path:
    for cand in (
        root_dir / "build-codex/switching_pc/tools/test_slowcontrol",
        root_dir / "build/switching_pc/tools/test_slowcontrol",
        root_dir / "install/bin/test_slowcontrol",
    ):
        if cand.exists():
            return cand
    raise FileNotFoundError("test_slowcontrol binary not found")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--root", type=Path, default=ROOT_DIR)
    p.add_argument("--link", type=int, default=2)
    p.add_argument("--seed", type=lambda x: int(x, 0), default=0xC0FFEE)
    p.add_argument("--ops", type=int, default=64)
    p.add_argument("--cmd-timeout", type=float, default=12.0)
    p.add_argument("--retries", type=int, default=1)
    p.add_argument("--read-chunk", type=int, default=32)
    p.add_argument(
        "--out-json",
        type=Path,
        default=Path("/home/yifeng/packages/online_sc/online/switching_pc/a10_board/output_files/sc_random_snapshot.json"),
    )
    return p


def main() -> int:
    args = build_parser().parse_args()
    scs = load_sweep_module()
    test_bin = pick_test_bin(args.root)

    sc_args = types.SimpleNamespace(
        root=args.root,
        test_bin=test_bin,
        link=args.link,
        cmd_timeout=args.cmd_timeout,
        retries=args.retries,
    )

    random.seed(args.seed)
    def read_region_chunked():
        out = []
        cur = scs.SCRATCHPAD_BASE
        rem = scs.SCRATCHPAD_WORDS
        while rem > 0:
            n = min(args.read_chunk, rem)
            out.extend(scs.sc_read(sc_args, cur, n))
            cur += n
            rem -= n
        return out

    mirror = read_region_chunked()

    writes = []
    for i in range(args.ops):
        addr = random.randint(0, scs.SCRATCHPAD_WORDS - 1)
        value = random.getrandbits(32)
        scs.sc_write_word(sc_args, addr, value)
        mirror[addr] = value
        writes.append({"iter": i, "addr": addr, "value": value})

    final_snapshot = read_region_chunked()
    mismatches = [
        {"addr": i, "expected": exp, "got": got}
        for i, (exp, got) in enumerate(zip(mirror, final_snapshot))
        if exp != got
    ]

    result = {
        "ok": len(mismatches) == 0,
        "link": args.link,
        "seed": args.seed,
        "ops": args.ops,
        "writes": writes,
        "mismatches": mismatches,
    }
    args.out_json.write_text(json.dumps(result, indent=2))

    print(f"seed=0x{args.seed:X} ops={args.ops}")
    for rec in writes[:8]:
        print(f"write[{rec['iter']}] addr=0x{rec['addr']:04X} val=0x{rec['value']:08X}")
    print(f"final_mismatches={len(mismatches)}")
    print(f"json={args.out_json}")

    return 0 if result["ok"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
