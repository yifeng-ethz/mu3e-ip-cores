#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re
import sys


NOISY_BASENAME_RE = re.compile(r"(timing_adapter_[0-9]+\.sv|timing_adt\.sv)$")
NOISY_BLOCK_RE = re.compile(
    r"(?ms)^   // synthesis translate_off\n(?:.*?\$display.*?\n)+?.*?^   // synthesis translate_on\s*\n?"
)


def iter_qip_files(qip_path: pathlib.Path, synth_dir: pathlib.Path) -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for line in qip_path.read_text().splitlines():
        if "VERILOG_FILE" not in line and "SYSTEMVERILOG_FILE" not in line:
            continue
        parts = line.split('"')
        if len(parts) < 5:
            continue
        rel = parts[3]
        files.append((synth_dir / rel).resolve())
    return files


def quiet_copy(src: pathlib.Path, out_dir: pathlib.Path) -> pathlib.Path:
    text = src.read_text()
    new_text, count = NOISY_BLOCK_RE.subn(
        """   // synthesis translate_off
   // Quiet INT harness copy: drop per-cycle backpressure transcript spam.
   // synthesis translate_on
""",
        text,
    )
    if count == 0:
        new_text = text

    out_path = out_dir / src.name
    out_path.write_text(new_text)
    return out_path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--qip", required=True)
    parser.add_argument("--synth-dir", required=True)
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()

    qip_path = pathlib.Path(args.qip)
    synth_dir = pathlib.Path(args.synth_dir)
    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    copied = 0
    for src in iter_qip_files(qip_path, synth_dir):
        if not NOISY_BASENAME_RE.search(src.name):
            continue
        quiet_copy(src, out_dir)
        copied += 1

    if copied == 0:
        raise SystemExit("No timing-adapter sources matched for quiet-copy generation")

    return 0


if __name__ == "__main__":
    sys.exit(main())
