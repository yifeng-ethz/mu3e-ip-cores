#!/usr/bin/env python3
"""Generate simulation runtime init aliases from Quartus .mif files.

The Intel memory models in QuestaOne first look for Intel HEX files and then
convert them to Verilog readmem files. Some generated FEB blocks only ship .mif
images, so this helper materializes matching .hex/.ver files in the simulation
work directory without touching the source tree.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
from typing import Iterable


RADIX_BASE = {
    "BIN": 2,
    "OCT": 8,
    "DEC": 10,
    "UNS": 10,
    "HEX": 16,
}


def strip_comments(text: str) -> str:
    text = re.sub(r"%.*?%", "", text, flags=re.S)
    text = re.sub(r"--.*$", "", text, flags=re.M)
    return text


def parse_scalar(token: str, radix: str) -> int:
    token = token.strip()
    if not token:
        raise ValueError("empty scalar")
    return int(token, RADIX_BASE[radix])


def parse_mif(path: pathlib.Path) -> tuple[int, int, list[int]]:
    raw = strip_comments(path.read_text(encoding="utf-8"))

    width_match = re.search(r"\bWIDTH\s*=\s*(\d+)\s*;", raw, flags=re.I)
    depth_match = re.search(r"\bDEPTH\s*=\s*(\d+)\s*;", raw, flags=re.I)
    addr_radix_match = re.search(r"\bADDRESS_RADIX\s*=\s*([A-Z]+)\s*;", raw, flags=re.I)
    data_radix_match = re.search(r"\bDATA_RADIX\s*=\s*([A-Z]+)\s*;", raw, flags=re.I)
    body_match = re.search(r"\bCONTENT\s+BEGIN(.*)\bEND\s*;", raw, flags=re.I | re.S)

    if not all((width_match, depth_match, addr_radix_match, data_radix_match, body_match)):
        raise ValueError(f"{path}: invalid or incomplete MIF header")

    width = int(width_match.group(1))
    depth = int(depth_match.group(1))
    addr_radix = addr_radix_match.group(1).upper()
    data_radix = data_radix_match.group(1).upper()

    if addr_radix not in RADIX_BASE or data_radix not in RADIX_BASE:
        raise ValueError(f"{path}: unsupported radix ({addr_radix}, {data_radix})")

    words = [0] * depth
    assigned: set[int] = set()
    others_value: int | None = None

    for statement in body_match.group(1).split(";"):
      stmt = statement.strip()
      if not stmt:
          continue

      if ":" not in stmt:
          raise ValueError(f"{path}: malformed statement {stmt!r}")
      lhs, rhs = (part.strip() for part in stmt.split(":", 1))
      value = parse_scalar(rhs, data_radix)

      if lhs.upper() == "OTHERS":
          others_value = value
          continue

      range_match = re.fullmatch(r"\[\s*([^\]]+?)\s*\.\.\s*([^\]]+?)\s*\]", lhs)
      if range_match:
          start = parse_scalar(range_match.group(1), addr_radix)
          end = parse_scalar(range_match.group(2), addr_radix)
      else:
          start = end = parse_scalar(lhs, addr_radix)

      if start > end:
          raise ValueError(f"{path}: descending address range {lhs!r}")
      if start < 0 or end >= depth:
          raise ValueError(f"{path}: address range {lhs!r} exceeds depth {depth}")

      for addr in range(start, end + 1):
          words[addr] = value
          assigned.add(addr)

    if others_value is not None:
        for addr in range(depth):
            if addr not in assigned:
                words[addr] = others_value

    mask = (1 << width) - 1 if width > 0 else 0
    return width, depth, [word & mask for word in words]


def emit_ver(out_path: pathlib.Path, width: int, words: Iterable[int]) -> None:
    digits = max(1, (width + 3) // 4)
    with out_path.open("w", encoding="utf-8") as handle:
        for addr, word in enumerate(words):
            handle.write(f"@{addr:x}\n")
            handle.write(f"{word:0{digits}x}\n")


def intel_hex_record(address: int, record_type: int, payload: bytes) -> str:
    count = len(payload)
    header = [count, (address >> 8) & 0xFF, address & 0xFF, record_type]
    checksum = (-sum(header) - sum(payload)) & 0xFF
    raw = header + list(payload) + [checksum]
    return ":" + "".join(f"{byte:02X}" for byte in raw)


def emit_hex(out_path: pathlib.Path, width: int, words: Iterable[int]) -> None:
    byte_width = max(1, (width + 7) // 8)
    current_upper: int | None = None

    with out_path.open("w", encoding="utf-8") as handle:
        for addr, word in enumerate(words):
            byte_addr = addr * byte_width
            upper = (byte_addr >> 16) & 0xFFFF
            lower = byte_addr & 0xFFFF

            if upper != current_upper:
                current_upper = upper
                handle.write(intel_hex_record(0, 0x04, upper.to_bytes(2, "big")) + "\n")

            handle.write(
                intel_hex_record(lower, 0x00, word.to_bytes(byte_width, "big")) + "\n"
            )

        handle.write(":00000001FF\n")


def maybe_generate(mif_path: pathlib.Path, out_dir: pathlib.Path, force: bool) -> None:
    width, _depth, words = parse_mif(mif_path)
    stem = mif_path.stem
    hex_path = out_dir / f"{stem}.hex"
    ver_path = out_dir / f"{stem}.ver"

    if force or not hex_path.exists():
        emit_hex(hex_path, width, words)
    if force or not ver_path.exists():
        emit_ver(ver_path, width, words)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", required=True, help="Directory to place generated .hex/.ver files")
    parser.add_argument("--force", action="store_true", help="Overwrite existing generated aliases")
    parser.add_argument("mif_files", nargs="+", help="Input .mif files")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    out_dir = pathlib.Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    try:
        for mif_name in args.mif_files:
            maybe_generate(pathlib.Path(mif_name).resolve(), out_dir, args.force)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
