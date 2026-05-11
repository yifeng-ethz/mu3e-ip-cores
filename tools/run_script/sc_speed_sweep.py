#!/usr/bin/env python3
"""Software-side SC packet-size speed sweep for read/write transactions."""

from __future__ import annotations

import argparse
import csv
import statistics
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TEST_BIN = ROOT / "build-codex/switching_pc/tools/test_slowcontrol"


def parse_words(spec: str | None, min_words: int, max_words: int) -> list[int]:
    if spec:
        words: list[int] = []
        for item in spec.split(","):
            item = item.strip()
            if not item:
                continue
            if "-" in item:
                start_s, end_s = item.split("-", 1)
                start = int(start_s, 0)
                end = int(end_s, 0)
                if end < start:
                    raise SystemExit(f"invalid range: {item}")
                words.extend(range(start, end + 1))
            else:
                words.append(int(item, 0))
        uniq = sorted(set(words))
        if not uniq:
            raise SystemExit("no packet sizes requested")
        return uniq
    if min_words > max_words:
        raise SystemExit("min-words must be <= max-words")
    return list(range(min_words, max_words + 1))


def extract_time_us(stdout: str) -> int:
    for line in stdout.splitlines():
        if "Time for SC transmission:" not in line:
            continue
        token = line.split()[-2]
        try:
            return int(token, 10)
        except ValueError as exc:
            raise RuntimeError(f"non-decimal timing token {token!r} in output:\n{stdout}") from exc
    raise RuntimeError(f"timing line not found in output:\n{stdout}")


def run_tx(
    test_bin: Path,
    link: int,
    args: list[str],
    match_only: bool,
    retries: int,
    retry_sleep_us: int,
    extra_args: list[str],
) -> int:
    cmd = [str(test_bin), str(link), *args, *extra_args, "--once", "--quiet"]
    if match_only:
        cmd.append("--match-only")
    last_exc: Exception | None = None
    for attempt in range(retries + 1):
        try:
            proc = subprocess.run(cmd, check=True, capture_output=True, text=True)
            return extract_time_us(proc.stdout)
        except Exception as exc:
            last_exc = exc
            if attempt == retries:
                raise
            if retry_sleep_us:
                time.sleep(retry_sleep_us / 1_000_000.0)
    assert last_exc is not None
    raise last_exc


def write_row(writer: csv.DictWriter, row: dict[str, object]) -> None:
    writer.writerow(row)
    sys.stdout.write(
        f"{str(row['op']):>5} words={int(row['words']):>3} median={float(row['median_us']):>8.1f} us "
        f"avg={float(row['avg_us']):>10.2f} us min={int(row['min_us']):>6} max={int(row['max_us']):>8} "
        f"MBps_med={float(row['payload_MBps_median']):>5.2f}\n"
    )
    sys.stdout.flush()


def main() -> int:
    p = argparse.ArgumentParser(description="Run a software SC packet-size sweep")
    p.add_argument("--test-bin", type=Path, default=DEFAULT_TEST_BIN)
    p.add_argument("--link", type=int, default=2)
    p.add_argument("--addr", type=lambda s: int(s, 0), default=0x0)
    p.add_argument("--iterations", type=int, default=10)
    p.add_argument("--min-words", type=int, default=1)
    p.add_argument("--max-words", type=int, default=128)
    p.add_argument("--words", default=None, help="comma-separated list/ranges, e.g. 1,4,8,16-32")
    p.add_argument("--guard-us", type=int, default=1000)
    p.add_argument("--retries", type=int, default=5)
    p.add_argument("--busy-poll", action="store_true", help="set SC main/response poll sleeps to 0 us")
    p.add_argument("--sc-main-poll-us", type=int, default=None)
    p.add_argument("--sc-response-poll-us", type=int, default=None)
    p.add_argument("--legacy-drain-all", action="store_true", help="use legacy parser path instead of --match-only")
    p.add_argument("--out-csv", type=Path, required=True)
    args = p.parse_args()

    if not args.test_bin.exists():
        raise SystemExit(f"test binary does not exist: {args.test_bin}")
    if args.iterations <= 0:
        raise SystemExit("iterations must be > 0")
    if args.guard_us < 0:
        raise SystemExit("guard-us must be >= 0")
    if args.retries < 0:
        raise SystemExit("retries must be >= 0")
    if args.sc_main_poll_us is not None and args.sc_main_poll_us < 0:
        raise SystemExit("sc-main-poll-us must be >= 0")
    if args.sc_response_poll_us is not None and args.sc_response_poll_us < 0:
        raise SystemExit("sc-response-poll-us must be >= 0")

    words_list = parse_words(args.words, args.min_words, args.max_words)
    match_only = not args.legacy_drain_all
    addr_arg = f"0x{args.addr:X}"
    effective_sc_main_poll_us = 0 if args.busy_poll else (args.sc_main_poll_us if args.sc_main_poll_us is not None else 100)
    effective_sc_response_poll_us = 0 if args.busy_poll else (args.sc_response_poll_us if args.sc_response_poll_us is not None else 1000)
    extra_args: list[str] = []
    if args.busy_poll:
        extra_args.append("--busy-poll")
    else:
        if args.sc_main_poll_us is not None:
            extra_args.extend(["--sc-main-poll-us", str(args.sc_main_poll_us)])
        if args.sc_response_poll_us is not None:
            extra_args.extend(["--sc-response-poll-us", str(args.sc_response_poll_us)])

    args.out_csv.parent.mkdir(parents=True, exist_ok=True)

    if match_only:
        _ = run_tx(args.test_bin, args.link, ["--write-burst", addr_arg, "1"], True, args.retries, args.guard_us, extra_args)
        if args.guard_us:
            time.sleep(args.guard_us / 1_000_000.0)
        _ = run_tx(args.test_bin, args.link, ["--read", addr_arg, "1"], True, args.retries, args.guard_us, extra_args)
        if args.guard_us:
            time.sleep(args.guard_us / 1_000_000.0)

    with args.out_csv.open("w", newline="") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=[
                "op",
                "words",
                "iterations",
                "mode",
                "guard_us",
                "sc_main_poll_us",
                "sc_response_poll_us",
                "median_us",
                "avg_us",
                "min_us",
                "max_us",
                "payload_MBps_median",
                "payload_MBps_avg",
            ],
        )
        writer.writeheader()

        for words in words_list:
            write_samples: list[int] = []
            for _ in range(args.iterations):
                write_samples.append(
                    run_tx(
                        args.test_bin,
                        args.link,
                        ["--write-burst", addr_arg, str(words)],
                        match_only,
                        args.retries,
                        args.guard_us,
                        extra_args,
                    )
                )
                if args.guard_us:
                    time.sleep(args.guard_us / 1_000_000.0)

            write_row(
                writer,
                {
                    "op": "WRITE",
                    "words": words,
                    "iterations": args.iterations,
                    "mode": "legacy" if args.legacy_drain_all else "match_only",
                    "guard_us": args.guard_us,
                    "sc_main_poll_us": effective_sc_main_poll_us,
                    "sc_response_poll_us": effective_sc_response_poll_us,
                    "median_us": round(statistics.median(write_samples), 1),
                    "avg_us": round(statistics.mean(write_samples), 2),
                    "min_us": min(write_samples),
                    "max_us": max(write_samples),
                    "payload_MBps_median": round((words * 4.0) / statistics.median(write_samples), 2),
                    "payload_MBps_avg": round((words * 4.0) / statistics.mean(write_samples), 2),
                },
            )

            _ = run_tx(
                args.test_bin,
                args.link,
                ["--write-burst", addr_arg, str(words)],
                match_only,
                args.retries,
                args.guard_us,
                extra_args,
            )
            if args.guard_us:
                time.sleep(args.guard_us / 1_000_000.0)

            read_samples: list[int] = []
            for _ in range(args.iterations):
                read_samples.append(
                    run_tx(
                        args.test_bin,
                        args.link,
                        ["--read", addr_arg, str(words)],
                        match_only,
                        args.retries,
                        args.guard_us,
                        extra_args,
                    )
                )
                if args.guard_us:
                    time.sleep(args.guard_us / 1_000_000.0)

            write_row(
                writer,
                {
                    "op": "READ",
                    "words": words,
                    "iterations": args.iterations,
                    "mode": "legacy" if args.legacy_drain_all else "match_only",
                    "guard_us": args.guard_us,
                    "sc_main_poll_us": effective_sc_main_poll_us,
                    "sc_response_poll_us": effective_sc_response_poll_us,
                    "median_us": round(statistics.median(read_samples), 1),
                    "avg_us": round(statistics.mean(read_samples), 2),
                    "min_us": min(read_samples),
                    "max_us": max(read_samples),
                    "payload_MBps_median": round((words * 4.0) / statistics.median(read_samples), 2),
                    "payload_MBps_avg": round((words * 4.0) / statistics.mean(read_samples), 2),
                },
            )

    print(f"saved {args.out_csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
