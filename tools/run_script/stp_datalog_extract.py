#!/usr/bin/env python3
"""
Extract embedded SignalTap data logs from a `.stp` file (offline) and export as:
- CSV matrix (sample rows, signal columns)
- CSV toggles (event list: {sample, signal, value})
- VCD (viewable in GTKWave)
- WaveDrom JSON/HTML (small, selectable window)

This tool parses `<log><data>...</data><extradata>...</extradata></log>` from the `.stp` XML.
It does not require Quartus, JTAG access, or any hardware.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator, List, Optional, Sequence, Tuple


@dataclass(frozen=True)
class LogRecord:
    index: int
    log_name: str
    signal_set_name: str
    data_wires: Tuple[str, ...]
    sample_depth_attr: Optional[int]
    trigger_position_attr: Optional[int]
    data_bits: str
    extradata: str


def leaf_name(full: str) -> str:
    return full.rsplit("|", 1)[-1]


def safe_filename(s: str) -> str:
    s = s.strip()
    s = re.sub(r"\s+", "_", s)
    s = re.sub(r"[^A-Za-z0-9_.@+=-]+", "_", s)
    return s.strip("._") or "out"


def parse_log_timestamp(log_name: str) -> Optional[str]:
    # Example: "log: Trig @ 2026/02/18 14:51:04 (0:0:0.0 elapsed)"
    m = re.search(r"@\s*(\d{4})/(\d{2})/(\d{2})\s+(\d{2}):(\d{2}):(\d{2})", log_name)
    if not m:
        return None
    yyyy, mm, dd, hh, mi, ss = m.groups()
    return f"{yyyy}{mm}{dd}_{hh}{mi}{ss}"


def vcd_id_code(idx: int) -> str:
    alphabet = [chr(i) for i in range(33, 127)]
    base = len(alphabet)
    n = idx
    out = ""
    while True:
        out = alphabet[n % base] + out
        n //= base
        if n == 0:
            return out
        n -= 1


def find_display_branch_default_log(stp_path: Path) -> Optional[str]:
    try:
        for ev, el in ET.iterparse(stp_path, events=("start",)):
            if el.tag == "display_branch":
                return el.attrib.get("log")
            el.clear()
    except ET.ParseError:
        return None
    return None


def iter_log_records(stp_path: Path) -> Iterator[LogRecord]:
    idx = -1
    current_signal_set: Optional[str] = None
    current_data_wires: List[str] = []
    in_data_input_vec = False

    cur_data: Optional[Tuple[int, dict, str]] = None
    cur_extradata: Optional[str] = None

    for ev, el in ET.iterparse(stp_path, events=("start", "end")):
        if ev == "start":
            if el.tag == "signal_set":
                current_signal_set = el.attrib.get("name", "")
                current_data_wires = []
            elif el.tag == "data_input_vec":
                in_data_input_vec = True
            elif el.tag == "wire" and in_data_input_vec:
                nm = el.attrib.get("name")
                if nm is not None:
                    current_data_wires.append(nm)
            continue

        # end-event
        if el.tag == "data":
            idx += 1
            cur_data = (idx, dict(el.attrib), (el.text or "").strip())
        elif el.tag == "extradata":
            if cur_data is not None:
                cur_extradata = (el.text or "").strip()
        elif el.tag == "log":
            if cur_data is not None:
                log_idx, attrib, data_bits = cur_data
                log_name = attrib.get("name", f"log_{log_idx}")
                sample_depth = attrib.get("sample_depth")
                trigger_position = attrib.get("trigger_position")
                yield LogRecord(
                    index=log_idx,
                    log_name=log_name,
                    signal_set_name=current_signal_set or "",
                    data_wires=tuple(current_data_wires),
                    sample_depth_attr=int(sample_depth) if sample_depth is not None else None,
                    trigger_position_attr=int(trigger_position) if trigger_position is not None else None,
                    data_bits=data_bits,
                    extradata=cur_extradata or "",
                )
            cur_data = None
            cur_extradata = None
        elif el.tag == "data_input_vec":
            in_data_input_vec = False
        elif el.tag == "signal_set":
            current_signal_set = None

        el.clear()


def compute_sample_count(data_bits: str, wire_count: int) -> int:
    if wire_count <= 0:
        raise ValueError("wire_count must be > 0")
    if len(data_bits) % wire_count != 0:
        raise ValueError(f"data_bits length {len(data_bits)} not divisible by wire_count {wire_count}")
    return len(data_bits) // wire_count


def pick_signal_indices(
    wires: Sequence[str],
    include_regexes: Sequence[re.Pattern],
    exclude_regexes: Sequence[re.Pattern],
) -> List[int]:
    out: List[int] = []
    for i, w in enumerate(wires):
        if include_regexes and not any(r.search(w) for r in include_regexes):
            continue
        if exclude_regexes and any(r.search(w) for r in exclude_regexes):
            continue
        out.append(i)
    return out


def write_csv_matrix(
    out_path: Path,
    wire_names: Sequence[str],
    data_bits: str,
    extradata: str,
    sample_start: int,
    sample_count: int,
    selected_indices: Sequence[int],
) -> None:
    wire_count = len(wire_names)
    end = sample_start + sample_count

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["sample", "meta", "trigger"] + [wire_names[i] for i in selected_indices])

        for s in range(sample_start, end):
            meta = extradata[s] if s < len(extradata) else ""
            trig = 1 if meta == "T" else 0
            chunk = data_bits[s * wire_count : (s + 1) * wire_count]
            w.writerow([s, meta, trig] + [chunk[i] for i in selected_indices])


def write_csv_toggles(
    out_path: Path,
    wire_names: Sequence[str],
    data_bits: str,
    extradata: str,
    sample_start: int,
    sample_count: int,
    selected_indices: Sequence[int],
) -> None:
    wire_count = len(wire_names)
    end = sample_start + sample_count

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["sample", "meta", "signal", "value"])

        prev: List[Optional[str]] = [None] * len(selected_indices)
        for s in range(sample_start, end):
            meta = extradata[s] if s < len(extradata) else ""
            chunk = data_bits[s * wire_count : (s + 1) * wire_count]
            for col, sig_i in enumerate(selected_indices):
                v = chunk[sig_i]
                if prev[col] is None or v != prev[col]:
                    w.writerow([s, meta, wire_names[sig_i], v])
                    prev[col] = v

        if extradata:
            prev_trig: Optional[str] = None
            for s in range(sample_start, end):
                meta = extradata[s] if s < len(extradata) else ""
                trig = "1" if meta == "T" else "0"
                if prev_trig is None or trig != prev_trig:
                    w.writerow([s, meta, "stp_trigger", trig])
                    prev_trig = trig


def write_vcd(
    out_path: Path,
    wire_names: Sequence[str],
    data_bits: str,
    extradata: str,
    sample_start: int,
    sample_count: int,
    selected_indices: Sequence[int],
    timescale: str,
) -> None:
    wire_count = len(wire_names)
    end = sample_start + sample_count

    if sample_count <= 0:
        raise ValueError("sample_count must be > 0 for VCD export")

    def norm_bit(ch: str) -> str:
        if ch in {"0", "1"}:
            return ch
        if ch in {"x", "X"}:
            return "x"
        if ch in {"z", "Z"}:
            return "z"
        return "x"

    signals = ["stp_trigger"] + [wire_names[i] for i in selected_indices]
    id_codes = {name: vcd_id_code(i) for i, name in enumerate(signals)}

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w") as f:
        f.write("$date\n  exported by stp_datalog_extract.py\n$end\n")
        f.write("$version\n  stp_datalog_extract.py\n$end\n")
        f.write(f"$timescale {timescale} $end\n")
        f.write("$scope module stp $end\n")
        for name in signals:
            f.write(f"$var wire 1 {id_codes[name]} {name} $end\n")
        f.write("$upscope $end\n")
        f.write("$enddefinitions $end\n")

        f.write("#0\n")
        f.write("$dumpvars\n")
        init_chunk = data_bits[sample_start * wire_count : (sample_start + 1) * wire_count]
        init_trig = "1" if (sample_start < len(extradata) and extradata[sample_start] == "T") else "0"
        f.write(f"{init_trig}{id_codes['stp_trigger']}\n")
        for sig_i in selected_indices:
            name = wire_names[sig_i]
            f.write(f"{norm_bit(init_chunk[sig_i])}{id_codes[name]}\n")
        f.write("$end\n")

        prev_vals: List[str] = [init_trig] + [norm_bit(init_chunk[i]) for i in selected_indices]

        for t, s in enumerate(range(sample_start + 1, end), start=1):
            chunk = data_bits[s * wire_count : (s + 1) * wire_count]
            cur_trig = "1" if (s < len(extradata) and extradata[s] == "T") else "0"
            cur_vals = [cur_trig] + [norm_bit(chunk[i]) for i in selected_indices]

            if cur_vals == prev_vals:
                continue

            f.write(f"#{t}\n")
            if cur_trig != prev_vals[0]:
                f.write(f"{cur_trig}{id_codes['stp_trigger']}\n")
            for pos, sig_i in enumerate(selected_indices, start=1):
                v = cur_vals[pos]
                if v != prev_vals[pos]:
                    name = wire_names[sig_i]
                    f.write(f"{v}{id_codes[name]}\n")

            prev_vals = cur_vals


def write_wavedrom_json(
    out_path: Path,
    wire_names: Sequence[str],
    data_bits: str,
    extradata: str,
    sample_start: int,
    sample_count: int,
    selected_indices: Sequence[int],
) -> dict:
    wire_count = len(wire_names)
    end = sample_start + sample_count

    def wave_for(values: Sequence[str]) -> str:
        out: List[str] = []
        prev: Optional[str] = None
        for v in values:
            if prev is None:
                out.append(v)
            else:
                out.append("." if v == prev else v)
            prev = v
        return "".join(out)

    def bit_at(sig_i: int, s: int) -> str:
        ch = data_bits[s * wire_count + sig_i]
        if ch in {"0", "1"}:
            return ch
        if ch in {"x", "X"}:
            return "x"
        if ch in {"z", "Z"}:
            return "z"
        return "x"

    trig_vals = ["1" if (s < len(extradata) and extradata[s] == "T") else "0" for s in range(sample_start, end)]
    signals = [{"name": "stp_trigger", "wave": wave_for(trig_vals)}]

    for sig_i in selected_indices:
        vals = [bit_at(sig_i, s) for s in range(sample_start, end)]
        signals.append({"name": wire_names[sig_i], "wave": wave_for(vals)})

    doc = {"signal": signals}
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(doc, indent=2) + "\n")
    return doc


def write_wavedrom_html(out_path: Path, wavedrom_doc: dict, title: str) -> None:
    doc_json = json.dumps(wavedrom_doc, indent=2)
    html = f"""<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>{title}</title>
    <script src="https://cdn.jsdelivr.net/npm/wavedrom@2.9.1/skins/default.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/wavedrom@2.9.1/wavedrom.min.js"></script>
    <style>
      body {{ font-family: sans-serif; margin: 16px; }}
      .note {{ color: #444; font-size: 12px; }}
    </style>
  </head>
  <body>
    <h3>{title}</h3>
    <p class="note">Generated by stp_datalog_extract.py. WaveDrom JS is loaded from jsDelivr.</p>
    <script type="WaveDrom">
{doc_json}
    </script>
    <script>WaveDrom.ProcessAll();</script>
  </body>
</html>
"""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(html)


def open_wavedrom(html_path: Path) -> None:
    if sys.platform.startswith("linux"):
        opener = ["xdg-open", str(html_path)]
    elif sys.platform == "darwin":
        opener = ["open", str(html_path)]
    elif os.name == "nt":
        subprocess.Popen(["cmd", "/c", "start", "", str(html_path)], shell=True)
        return
    else:
        raise RuntimeError(f"unsupported platform for open: {sys.platform}")
    subprocess.Popen(opener)


def open_gtkwave(vcd_path: Path, save_path: Optional[Path]) -> None:
    if not shutil_which("gtkwave"):
        raise RuntimeError("gtkwave not found in PATH")
    cmd = ["gtkwave", str(vcd_path)]
    if save_path is not None:
        cmd.append(str(save_path))
    os.execvp(cmd[0], cmd)


def shutil_which(prog: str) -> Optional[str]:
    for p in os.environ.get("PATH", "").split(os.pathsep):
        cand = Path(p) / prog
        if cand.is_file() and os.access(cand, os.X_OK):
            return str(cand)
    return None


def clamp_window(sample_start: int, sample_count: int, samples_total: int) -> Tuple[int, int]:
    s0 = max(0, min(sample_start, samples_total))
    n = max(0, min(sample_count, samples_total - s0))
    return s0, n


def main(argv: Optional[Sequence[str]] = None) -> int:
    p = argparse.ArgumentParser(description="Extract embedded SignalTap data logs from a .stp file (offline)")
    p.add_argument("--stp", type=Path, required=True, help="Input .stp file")
    p.add_argument("--list", action="store_true", help="List logs found in the .stp and exit")

    sel = p.add_argument_group("selection")
    sel.add_argument("--log-index", type=int, action="append", help="Select log by index (repeatable)")
    sel.add_argument("--log-name", action="append", help="Select logs whose name matches this regex (repeatable)")
    sel.add_argument("--names", choices=["leaf", "full"], default="leaf", help="Signal naming for outputs")
    sel.add_argument("--include-signal", action="append", help="Keep signals matching this regex (repeatable)")
    sel.add_argument("--exclude-signal", action="append", help="Drop signals matching this regex (repeatable)")

    rng = p.add_argument_group("sample window (CSV/VCD)")
    rng.add_argument("--sample-start", type=int, help="First sample to export")
    rng.add_argument("--sample-count", type=int, help="Number of samples to export")
    rng.add_argument(
        "--center-on-trigger",
        action="store_true",
        default=False,
        help="Center {sample_start, sample_count} window on trigger_position when possible",
    )

    out = p.add_argument_group("outputs")
    out.add_argument("--out-dir", type=Path, default=Path("/tmp/stp_datalog_export"))
    out.add_argument("--csv-matrix", action="store_true", help="Write <base>_matrix.csv")
    out.add_argument("--csv-toggles", action="store_true", help="Write <base>_toggles.csv")
    out.add_argument("--vcd", action="store_true", help="Write <base>.vcd (GTKWave)")
    out.add_argument("--vcd-timescale", default="1ns", help="VCD $timescale value")
    out.add_argument("--wavedrom", action="store_true", help="Write <base>_wavedrom.json and .html")
    out.add_argument("--wavedrom-samples", type=int, default=256, help="WaveDrom window size")

    view = p.add_argument_group("viewers")
    view.add_argument("--open-gtkwave", action="store_true", help="Open GTKWave after export (first selected log)")
    view.add_argument("--gtkwave-save", type=Path, help="Optional .gtkw savefile to load with GTKWave")
    view.add_argument("--open-wavedrom", action="store_true", help="Open WaveDrom HTML after export (first selected log)")

    args = p.parse_args(argv)

    if not args.stp.exists():
        print(f"ERR: stp not found: {args.stp}", file=sys.stderr)
        return 2

    include_re = [re.compile(x) for x in (args.include_signal or [])]
    exclude_re = [re.compile(x) for x in (args.exclude_signal or [])]
    log_name_res = [re.compile(x) for x in (args.log_name or [])]

    if args.list:
        default_log = find_display_branch_default_log(args.stp)
        print("index\tdefault\tname\tsignal_set\twires\tsamples\ttrigger_pos")
        for rec in iter_log_records(args.stp):
            wire_count = len(rec.data_wires)
            samples_total = compute_sample_count(rec.data_bits, wire_count) if wire_count else 0
            is_default = "Y" if (default_log is not None and rec.log_name == default_log) else ""
            print(
                f"{rec.index}\t{is_default}\t{rec.log_name}\t{rec.signal_set_name}\t{wire_count}\t{samples_total}\t{rec.trigger_position_attr}"
            )
        return 0

    want_indices = set(args.log_index or [])
    default_log_name = None
    if not want_indices and not log_name_res:
        default_log_name = find_display_branch_default_log(args.stp)

    selected: List[LogRecord] = []
    for rec in iter_log_records(args.stp):
        if want_indices and rec.index not in want_indices:
            continue
        if log_name_res and not any(r.search(rec.log_name) for r in log_name_res):
            continue
        if default_log_name is not None and rec.log_name != default_log_name:
            continue
        selected.append(rec)
        if default_log_name is not None:
            break
        if want_indices and len(selected) >= len(want_indices):
            break

    if not selected and default_log_name is None and not want_indices and not log_name_res:
        for rec in iter_log_records(args.stp):
            selected.append(rec)
            break

    if not selected:
        print("ERR: no matching logs found", file=sys.stderr)
        if default_log_name:
            print(f"  display_branch default log: {default_log_name}", file=sys.stderr)
        print("Hint: run with --list, then select with --log-index N", file=sys.stderr)
        return 3

    if args.open_gtkwave:
        args.vcd = True
    if args.open_wavedrom:
        args.wavedrom = True

    if not (args.csv_matrix or args.csv_toggles or args.vcd or args.wavedrom):
        args.csv_matrix = True
        args.vcd = True

    first_vcd: Optional[Path] = None
    first_wd_html: Optional[Path] = None

    for rec in selected:
        wires = list(rec.data_wires)
        if not wires:
            print(f"WARN: log {rec.index}: no wires found in data_input_vec; skipping")
            continue

        wire_names = [leaf_name(w) for w in wires] if args.names == "leaf" else wires
        wire_count = len(wire_names)
        samples_total = compute_sample_count(rec.data_bits, wire_count)

        sample_start = args.sample_start if args.sample_start is not None else 0
        sample_count = args.sample_count if args.sample_count is not None else (samples_total - sample_start)
        if args.center_on_trigger and rec.trigger_position_attr is not None and rec.trigger_position_attr >= 0:
            center = rec.trigger_position_attr
            if args.sample_count is not None and args.sample_start is None:
                sample_start = max(0, center - args.sample_count // 2)
        sample_start, sample_count = clamp_window(sample_start, sample_count, samples_total)

        sig_indices = pick_signal_indices(wires, include_re, exclude_re)
        if not sig_indices:
            print(f"WARN: log {rec.index}: no signals selected; skipping")
            continue

        ts = parse_log_timestamp(rec.log_name) or f"idx{rec.index:03d}"
        base = safe_filename(f"log{rec.index:03d}_{ts}")
        out_dir = args.out_dir

        print(f"Exporting log {rec.index}: {rec.log_name}")
        print(f"  signal_set: {rec.signal_set_name}")
        print(f"  wires: {wire_count} (selected {len(sig_indices)})")
        print(f"  samples: {samples_total} (export {sample_count} from {sample_start})")

        if args.csv_matrix:
            out_csv = out_dir / f"{base}_matrix.csv"
            write_csv_matrix(
                out_csv,
                wire_names=wire_names,
                data_bits=rec.data_bits,
                extradata=rec.extradata,
                sample_start=sample_start,
                sample_count=sample_count,
                selected_indices=sig_indices,
            )
            print(f"  wrote: {out_csv}")

        if args.csv_toggles:
            out_tog = out_dir / f"{base}_toggles.csv"
            write_csv_toggles(
                out_tog,
                wire_names=wire_names,
                data_bits=rec.data_bits,
                extradata=rec.extradata,
                sample_start=sample_start,
                sample_count=sample_count,
                selected_indices=sig_indices,
            )
            print(f"  wrote: {out_tog}")

        if args.vcd:
            out_vcd = out_dir / f"{base}.vcd"
            write_vcd(
                out_vcd,
                wire_names=wire_names,
                data_bits=rec.data_bits,
                extradata=rec.extradata,
                sample_start=sample_start,
                sample_count=sample_count,
                selected_indices=sig_indices,
                timescale=args.vcd_timescale,
            )
            if first_vcd is None:
                first_vcd = out_vcd
            print(f"  wrote: {out_vcd}")

        if args.wavedrom:
            wd_samples = max(1, int(args.wavedrom_samples))
            if rec.trigger_position_attr is not None and rec.trigger_position_attr >= 0:
                center = rec.trigger_position_attr
                wd_start = max(0, min(center - wd_samples // 2, max(0, samples_total - wd_samples)))
            else:
                wd_start = 0
            wd_start = max(sample_start, wd_start)
            wd_count = min(wd_samples, samples_total - wd_start)

            out_wd_json = out_dir / f"{base}_wavedrom.json"
            doc = write_wavedrom_json(
                out_wd_json,
                wire_names=wire_names,
                data_bits=rec.data_bits,
                extradata=rec.extradata,
                sample_start=wd_start,
                sample_count=wd_count,
                selected_indices=sig_indices,
            )
            print(f"  wrote: {out_wd_json}")

            out_wd_html = out_dir / f"{base}_wavedrom.html"
            write_wavedrom_html(out_wd_html, doc, title=f"{base} (samples {wd_start}..{wd_start + wd_count - 1})")
            if first_wd_html is None:
                first_wd_html = out_wd_html
            print(f"  wrote: {out_wd_html}")

    if args.open_wavedrom and first_wd_html is not None:
        open_wavedrom(first_wd_html)

    if args.open_gtkwave and first_vcd is not None:
        open_gtkwave(first_vcd, args.gtkwave_save)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

