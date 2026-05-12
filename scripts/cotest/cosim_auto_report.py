#!/usr/bin/env python3
"""Generate RN.BASIC cosim, board, and theory report trees."""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import re
import subprocess
import sys
import tempfile
from collections import Counter
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_BUILD_DIR = (
    REPO_ROOT
    / "firmware_builds"
    / "systems"
    / "v3_pretest-260511-emutype0-dualport-260512"
)
DEFAULT_TEST_BASIC = (
    REPO_ROOT / "firmware_builds" / "systems" / "v3_pretest-260511" / "doc" / "TEST_BASIC.md"
)
OPQ_INGRESS_CEILING = 250_000
RATE_BASE = 65_536.0
RUN_WINDOW_S = 1.0e-3
BOARD_WINDOW_MS = 1.0
PASS = "\u2705"
FAIL = "\u274c"


DISLIN_RENDERER_C = r'''
#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define MAX_POINTS 16384
#define PAGE_WIDTH 2100
#define PAGE_HEIGHT 1485

typedef struct {
  int n;
  float x[MAX_POINTS];
  float y[MAX_POINTS];
} series_t;

static const char *fmt_from_path(const char *path) {
  const char *dot = strrchr(path, '.');
  if (dot != NULL && strcasecmp(dot, ".pdf") == 0) {
    return "PDF";
  }
  return "PNG";
}

static void trim(char *s) {
  size_t len;
  while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') {
    memmove(s, s + 1, strlen(s));
  }
  len = strlen(s);
  while (len > 0 && (s[len - 1] == ' ' || s[len - 1] == '\t' ||
                     s[len - 1] == '\n' || s[len - 1] == '\r')) {
    s[--len] = '\0';
  }
}

static int read_series(series_t *s) {
  char line[4096];
  int first = 1;
  memset(s, 0, sizeof(*s));
  while (fgets(line, sizeof(line), stdin) != NULL) {
    char *comma;
    float x;
    float y;
    if (first) {
      first = 0;
      if (strstr(line, "x,") == line) {
        continue;
      }
    }
    trim(line);
    if (line[0] == '\0') {
      continue;
    }
    comma = strchr(line, ',');
    if (comma == NULL) {
      continue;
    }
    *comma = '\0';
    x = (float)atof(line);
    y = (float)atof(comma + 1);
    if (s->n >= MAX_POINTS) {
      break;
    }
    s->x[s->n] = x;
    s->y[s->n] = y;
    s->n++;
  }
  return s->n;
}

static void center_text(const char *text, int y, int h) {
  int width;
  height(h);
  width = nlmess(text);
  messag(text, (PAGE_WIDTH - width) / 2, y);
}

static float nice_step(float span, float target_ticks) {
  float raw;
  float base;
  float frac;
  if (span <= 0.0f) {
    return 1.0f;
  }
  raw = span / target_ticks;
  base = powf(10.0f, floorf(log10f(raw)));
  frac = raw / base;
  if (frac <= 1.0f) {
    return base;
  }
  if (frac <= 2.0f) {
    return 2.0f * base;
  }
  if (frac <= 5.0f) {
    return 5.0f * base;
  }
  return 10.0f * base;
}

static void render_plot(const char *mode,
                        const char *title,
                        const char *subtitle,
                        const char *xlabel,
                        const char *ylabel,
                        const char *out_path) {
  series_t s;
  float xmin = 0.0f;
  float xmax = 1.0f;
  float ymax = 1.0f;
  float xstep;
  float ystep;
  float yzero[MAX_POINTS];
  const char *fmt;

  if (!read_series(&s)) {
    s.n = 1;
    s.x[0] = 0.0f;
    s.y[0] = 0.0f;
  }

  xmin = s.x[0];
  xmax = s.x[0];
  for (int i = 0; i < s.n; i++) {
    if (s.x[i] < xmin) {
      xmin = s.x[i];
    }
    if (s.x[i] > xmax) {
      xmax = s.x[i];
    }
    if (s.y[i] > ymax) {
      ymax = s.y[i];
    }
    yzero[i] = 0.0f;
  }
  if (xmax <= xmin) {
    xmax = xmin + 1.0f;
  }
  xmax += 1.0f;
  ymax = fmaxf(1.0f, ymax * 1.12f);
  xstep = nice_step(xmax - xmin, 8.0f);
  ystep = nice_step(ymax, 6.0f);
  fmt = fmt_from_path(out_path);

  metafl(fmt);
  setfil(out_path);
  filmod("delete");
  if (strcasecmp(fmt, "PNG") == 0) {
    winsiz(1600, 1131);
  }
  page(PAGE_WIDTH, PAGE_HEIGHT);
  scrmod("reverse");
  disini();
  complx();
  pagera();
  center_text(title, 150, 38);
  center_text(subtitle, 205, 25);

  axspos(260, 1040);
  axslen(1620, 680);
  name(xlabel, "x");
  name(ylabel, "y");
  if (xstep < 1.0f) {
    labdig(1, "x");
  } else {
    labdig(0, "x");
  }
  labdig(0, "y");
  ticks(2, "x");
  ticks(2, "y");
  graf(xmin, xmax, ceilf(xmin / xstep) * xstep, xstep, 0.0f, ymax, 0.0f, ystep);
  grid(1, 1);

  if (strcmp(mode, "curve") == 0) {
    color("blue");
    linwid(5);
    curve(s.x, s.y, s.n);
    linwid(1);
  } else {
    color("green");
    shdpat(16);
    bars(s.x, yzero, s.y, s.n);
  }
  color("fore");
  endgrf();
  disfin();
}

int main(int argc, char **argv) {
  if (argc != 7) {
    fprintf(stderr, "usage: %s mode title subtitle xlabel ylabel output\n", argv[0]);
    return 2;
  }
  render_plot(argv[1], argv[2], argv[3], argv[4], argv[5], argv[6]);
  return 0;
}
'''


@dataclass(frozen=True)
class PlanCase:
    row_id: str
    index: int
    slice_id: int
    slice_name: str
    injector_mode: int
    injector_name: str
    lane_mask: int
    channel_mask: int
    rate_88fp: int
    expected_hits: int
    expected_pulses: int | None = None
    poisson_rate: int | None = None
    signal_rate: int | None = None
    rate_ratio: str | None = None

    @property
    def lane_popcount(self) -> int:
        return self.lane_mask.bit_count()

    @property
    def channel_popcount(self) -> int:
        return self.channel_mask.bit_count()

    @property
    def lane_hex(self) -> str:
        return f"0x{self.lane_mask:02X}"

    @property
    def channel_hex(self) -> str:
        return f"0x{self.channel_mask:08X}"

    @property
    def rate_hex(self) -> str:
        return f"0x{self.rate_88fp:04X}"


@dataclass
class Evidence:
    case: PlanCase
    sim_dir: Path
    board_dir: Path | None
    row_config: dict[str, Any] = field(default_factory=dict)
    rate: dict[str, Any] = field(default_factory=dict)
    hist_a: dict[str, Any] = field(default_factory=dict)
    hist_b: dict[str, Any] = field(default_factory=dict)
    scoreboard: dict[str, Any] = field(default_factory=dict)
    rdma_summary: dict[str, Any] = field(default_factory=dict)
    board: dict[str, Any] = field(default_factory=dict)
    sim_missing: bool = False
    plan_mismatch: list[str] = field(default_factory=list)
    board_unresolved: str = ""
    rate_status: str = FAIL
    delay_status: str = FAIL
    rdma_status: str = FAIL
    rate_notes: list[str] = field(default_factory=list)
    delay_notes: list[str] = field(default_factory=list)
    rdma_notes: list[str] = field(default_factory=list)
    sim_total: int | None = None
    board_total: int | None = None
    hist_a_sum: int | None = None
    hist_b_sum: int | None = None
    rdma_record_count: int | None = None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", type=Path, default=DEFAULT_BUILD_DIR)
    parser.add_argument("--run-id")
    parser.add_argument("--report-root", type=Path)
    parser.add_argument("--cosim-report", type=Path)
    parser.add_argument("--board-sweep", type=Path)
    parser.add_argument("--test-basic", type=Path, default=DEFAULT_TEST_BASIC)
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def parse_int(text: str) -> int:
    return int(text.strip().replace(",", ""), 0)


def pct_delta(value: int | float | None, expected: int | float | None) -> float | None:
    if value is None or expected is None:
        return None
    if expected == 0:
        return 0.0 if value == 0 else None
    return 100.0 * (float(value) - float(expected)) / float(expected)


def fmt_num(value: int | float | None) -> str:
    if value is None:
        return "--"
    if isinstance(value, float):
        if not math.isfinite(value):
            return "--"
        if abs(value - round(value)) < 1.0e-9:
            return f"{int(round(value)):,}"
        return f"{value:,.3f}"
    return f"{value:,}"


def fmt_pct(value: float | None) -> str:
    if value is None or not math.isfinite(value):
        return "--"
    return f"{value:.2f}%"


def md_escape(text: str) -> str:
    return text.replace("|", "\\|")


def parse_test_basic(path: Path) -> list[PlanCase]:
    cases: list[PlanCase] = []
    line_re = re.compile(r"^\|\s*(RN\.BASIC\.(\d{3}))\s*\|")
    for raw in path.read_text(encoding="utf-8").splitlines():
        match = line_re.match(raw)
        if not match:
            continue
        row_id = match.group(1)
        index = int(match.group(2))
        cols = [col.strip() for col in raw.strip().strip("|").split("|")]
        if index <= 128:
            lane = parse_int(cols[1])
            chan = parse_int(cols[2])
            rate = parse_int(cols[3])
            expected = parse_int(cols[5])
            cases.append(
                PlanCase(row_id, index, 1, "1 periodic", 2, "periodic", lane, chan, rate, expected)
            )
        elif index <= 160:
            lane = parse_int(cols[1])
            chan = parse_int(cols[2])
            expected = parse_int(cols[4])
            cases.append(
                PlanCase(row_id, index, 2, "2 headersync", 1, "headersync", lane, chan, 0x0100, expected)
            )
        elif index <= 162:
            lane = parse_int(cols[1])
            chan = parse_int(cols[2])
            pulses = parse_int(cols[4])
            expected = parse_int(cols[5])
            cases.append(
                PlanCase(
                    row_id,
                    index,
                    3,
                    "3 onclick",
                    4,
                    "onclick",
                    lane,
                    chan,
                    0x0100,
                    expected,
                    expected_pulses=pulses,
                )
            )
        elif index <= 194:
            lane = parse_int(cols[1])
            poisson = parse_int(cols[3])
            signal = parse_int(cols[4])
            expected = parse_int(cols[6])
            cases.append(
                PlanCase(
                    row_id,
                    index,
                    4,
                    "4 emul-only",
                    0,
                    "emul_only",
                    lane,
                    0xFFFFFFFF,
                    poisson + signal,
                    expected,
                    poisson_rate=poisson,
                    signal_rate=signal,
                    rate_ratio=cols[2],
                )
            )

    indexes = [case.index for case in cases]
    expected_indexes = list(range(1, 195))
    if indexes != expected_indexes:
        raise ValueError(f"{path} yielded RN.BASIC indexes {indexes[:4]}..{indexes[-4:]}, expected 001-194")
    return cases


def detect_cosim_commit(build_dir: Path, cosim_report: Path) -> str | None:
    env_commit = os.environ.get("COSIM_SWEEP_COMMIT", "").strip()
    if re.fullmatch(r"[0-9a-fA-F]{7,40}", env_commit):
        return env_commit[:8].lower()

    runner = build_dir / "cosim" / "scripts" / "rn_basic_cosim.py"
    try:
        result = subprocess.run(
            [
                "git",
                "-C",
                str(REPO_ROOT),
                "log",
                "--format=%H%x00%s",
                "--",
                str(runner.relative_to(REPO_ROOT)),
            ],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        result = None
    if result and result.returncode == 0:
        fallback_sha = None
        for line in result.stdout.splitlines():
            sha, _, subject = line.partition("\0")
            if not re.fullmatch(r"[0-9a-fA-F]{40}", sha):
                continue
            if fallback_sha is None:
                fallback_sha = sha
            if "cosim sweep" in subject.lower():
                return sha[:8].lower()
        if fallback_sha:
            return fallback_sha[:8].lower()

    for path in sorted(cosim_report.glob("RN.BASIC.*/*.json"))[:64]:
        text = path.read_text(encoding="utf-8", errors="ignore")
        match = re.search(r"(?:commit|sha)[^0-9a-fA-F]{0,20}([0-9a-fA-F]{7,40})", text, re.I)
        if match:
            return match.group(1)[:8].lower()
    return None


def choose_run_id(build_dir: Path, cosim_report: Path, requested: str | None) -> tuple[str, str | None]:
    if requested:
        return requested, detect_cosim_commit(build_dir, cosim_report)
    commit = detect_cosim_commit(build_dir, cosim_report)
    now = datetime.now().astimezone()
    if commit:
        return f"{now:%Y%m%d}-{commit}", commit
    return f"{now:%Y%m%dT%H%M%S}", None


def fresh_report_root(base: Path, requested_run_id: str | None, run_id: str) -> tuple[str, Path]:
    root = base
    final_run_id = run_id
    if requested_run_id is None:
        suffix = 0
        while root.exists():
            suffix += 1
            final_run_id = f"{run_id}-rerun" if suffix == 1 else f"{run_id}-rerun{suffix}"
            root = base.parent / final_run_id
    elif root.exists():
        raise FileExistsError(f"report root already exists: {root}")
    return final_run_id, root


def expected_hits_from_formula(case: PlanCase) -> int:
    if case.slice_id == 3:
        return case.lane_popcount * case.channel_popcount * int(case.expected_pulses or 0)
    hits = (
        case.lane_popcount
        * case.channel_popcount
        * float(case.rate_88fp)
        / RATE_BASE
        * 125.0e6
        * RUN_WINDOW_S
    )
    return min(int(round(hits)), OPQ_INGRESS_CEILING)


def discover_board_mapping(board_sweep: Path, cases: list[PlanCase]) -> tuple[dict[str, Path], list[str]]:
    by_tuple: dict[tuple[int, int, int], list[PlanCase]] = {}
    for case in cases:
        by_tuple.setdefault((case.lane_mask, case.channel_mask, case.rate_88fp), []).append(case)

    mapped: dict[str, Path] = {}
    unresolved: list[str] = []
    for counters_path in sorted(board_sweep.glob("p45_[0-9][0-9][0-9]_*/*counters.json")):
        if ".bak." in str(counters_path):
            continue
        evidence_dir = counters_path.parent
        data = load_json(counters_path)
        verdict = data.get("verdict") if isinstance(data.get("verdict"), dict) else load_json(evidence_dir / "verdict.json")
        row = data.get("row", {})
        bucket = str(verdict.get("bucket", "")).upper()
        window_ms = verdict.get("theoretical_window_ms")
        if bucket and bucket != "BASIC":
            unresolved.append(f"{evidence_dir.name}: bucket={bucket}")
            continue
        if window_ms is not None and abs(float(window_ms) - BOARD_WINDOW_MS) > 1.0e-6:
            unresolved.append(f"{evidence_dir.name}: window_ms={window_ms}")
            continue
        try:
            lane = parse_int(str(row.get("lane_mask")))
            chan = parse_int(str(row.get("channel_mask")))
            rate = parse_int(str(row.get("rate_88fp")))
        except (TypeError, ValueError):
            unresolved.append(f"{evidence_dir.name}: missing row tuple")
            continue
        candidates = by_tuple.get((lane, chan, rate), [])
        if len(candidates) == 1:
            mapped[candidates[0].row_id] = evidence_dir
        else:
            unresolved.append(f"{evidence_dir.name}: tuple maps to {len(candidates)} cases")
    return mapped, unresolved


def compare_row_config(case: PlanCase, row_config: dict[str, Any]) -> list[str]:
    if not row_config:
        return ["missing row_config.json"]
    mismatches: list[str] = []
    checks = [
        ("slice", case.slice_id, row_config.get("slice")),
        ("injector_mode", case.injector_mode, row_config.get("injector_mode")),
        ("lane_mask", case.lane_mask, row_config.get("lane_mask")),
        ("channel_mask", case.channel_mask, row_config.get("channel_mask")),
        ("rate_88fp", case.rate_88fp, row_config.get("rate_88fp")),
        ("theoretical_hits", case.expected_hits, row_config.get("theoretical_hits")),
    ]
    for name, expected, actual in checks:
        if actual is None:
            mismatches.append(f"{name}: missing")
        elif int(actual) != int(expected):
            mismatches.append(f"{name}: evidence={actual} plan={expected}")
    return mismatches


def find_int(data: dict[str, Any], path: list[str]) -> int | None:
    cur: Any = data
    for key in path:
        if not isinstance(cur, dict) or key not in cur:
            return None
        cur = cur[key]
    if isinstance(cur, bool):
        return int(cur)
    if isinstance(cur, (int, float)):
        return int(cur)
    return None


def hist_points(hist: dict[str, Any]) -> list[tuple[float, int]]:
    bins = hist.get("hist_bins", {})
    width = float(hist.get("bin_width_ns", 1) or 1)
    points: list[tuple[float, int]] = []
    if isinstance(bins, dict):
        for key, value in bins.items():
            try:
                points.append((float(int(key)) * width, int(value)))
            except (TypeError, ValueError):
                continue
    points.sort(key=lambda item: item[0])
    return points or [(0.0, 0)]


def delay_hist_points(scoreboard: dict[str, Any]) -> list[tuple[float, int]]:
    delays = scoreboard.get("delay_ns", [])
    counts: Counter[int] = Counter()
    if isinstance(delays, list):
        for value in delays:
            try:
                counts[int(round(float(value)))] += 1
            except (TypeError, ValueError):
                continue
    if not counts and scoreboard.get("count"):
        mean = int(round(float(scoreboard.get("delay_mean_ns", 0.0))))
        counts[mean] = int(scoreboard.get("count", 0))
    return [(float(key), value) for key, value in sorted(counts.items())] or [(0.0, 0)]


def compile_renderer(run_id: str) -> Path:
    dislin_dir = find_dislin_dir()
    work = Path(tempfile.gettempdir()) / f"cosim_auto_report_dislin_{run_id}"
    work.mkdir(parents=True, exist_ok=True)
    src = work / "cosim_auto_report_dislin.c"
    binary = work / "cosim_auto_report_dislin"
    src.write_text(DISLIN_RENDERER_C, encoding="ascii")
    subprocess.run(
        [
            "gcc",
            "-O2",
            "-std=c99",
            "-Wall",
            "-Wextra",
            f"-I{dislin_dir}",
            str(src),
            f"-L{dislin_dir}",
            f"-Wl,-rpath,{dislin_dir}",
            "-ldislin",
            "-lm",
            "-o",
            str(binary),
        ],
        check=True,
    )
    return binary


def find_dislin_dir() -> Path:
    candidates = []
    if os.environ.get("DISLIN_DIR"):
        candidates.append(Path(os.environ["DISLIN_DIR"]))
    candidates.extend(
        [
            REPO_ROOT / "packet_scheduler" / ".vendor" / "dislin",
            Path("/home/yifeng/packages/lib/dislin"),
            Path("/home/yifeng/packages/dislin-11.5/examples"),
        ]
    )
    for candidate in candidates:
        if (candidate / "dislin.h").exists() and (
            (candidate / "libdislin.so").exists() or (candidate / "libdislin.a").exists()
        ):
            return candidate
    raise FileNotFoundError("DISLIN headers/library not found; set DISLIN_DIR")


def render_dislin(binary: Path, mode: str, points: list[tuple[float, int]], title: str, subtitle: str, out: Path) -> Path:
    payload = "x,y\n" + "".join(f"{x:.6f},{y}\n" for x, y in points)
    out.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [str(binary), mode, title, subtitle, "delay [ns]", "count", str(out)],
        input=payload,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode == 0 and out.exists():
        return out
    png = out.with_suffix(".png")
    retry = subprocess.run(
        [str(binary), mode, title, subtitle, "delay [ns]", "count", str(png)],
        input=payload,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if retry.returncode == 0 and png.exists():
        return png
    raise RuntimeError(f"DISLIN render failed for {out}: {result.stderr.strip()} {retry.stderr.strip()}")


def collect_evidence(cases: list[PlanCase], cosim_report: Path, board_map: dict[str, Path]) -> list[Evidence]:
    evidences: list[Evidence] = []
    for case in cases:
        sim_dir = cosim_report / case.row_id
        ev = Evidence(case=case, sim_dir=sim_dir, board_dir=board_map.get(case.row_id))
        if not sim_dir.exists():
            ev.sim_missing = True
            ev.plan_mismatch.append("missing sim evidence directory")
        ev.row_config = load_json(sim_dir / "row_config.json")
        ev.rate = load_json(sim_dir / "rate_csr_dump.json")
        ev.hist_a = load_json(sim_dir / "delay_hist_bin_a.json")
        ev.hist_b = load_json(sim_dir / "delay_hist_bin_b.json")
        ev.scoreboard = load_json(sim_dir / "delay_scoreboard.json")
        ev.rdma_summary = load_json(sim_dir / "rdma_rxbuffer_summary.json")
        ev.plan_mismatch.extend(compare_row_config(case, ev.row_config))
        if ev.board_dir:
            ev.board = load_json(ev.board_dir / "counters.json")
        else:
            ev.board_unresolved = "no BASIC-compatible board p45 evidence"
        summarize_evidence(ev)
        evidences.append(ev)
    return evidences


def summarize_evidence(ev: Evidence) -> None:
    rate = ev.rate
    ev.sim_total = find_int(rate, ["histogram_statistics_v2", "total_hits_csr13"])
    if ev.sim_total is None:
        ev.sim_total = find_int(rate, ["csr_total"])
    ev.hist_a_sum = find_int(ev.hist_a, ["hist_bin_sum"])
    ev.hist_b_sum = find_int(ev.hist_b, ["hist_bin_sum"])
    ev.rdma_record_count = find_int(ev.rdma_summary, ["record_count"])
    if ev.board:
        verdict = ev.board.get("verdict") if isinstance(ev.board.get("verdict"), dict) else {}
        ev.board_total = find_int(verdict, ["total_hits"]) or find_int(verdict, ["total_hits_csr13"])

    expected = ev.case.expected_hits
    if expected_hits_from_formula(ev.case) != expected:
        ev.rate_notes.append("TEST_BASIC expected value differs from formula")

    if ev.plan_mismatch:
        ev.rate_notes.append("sim row_config does not match TEST_BASIC")
        ev.delay_notes.append("sim row_config does not match TEST_BASIC")
        ev.rdma_notes.append("sim row_config does not match TEST_BASIC")
    else:
        sim_delta = pct_delta(ev.sim_total, expected)
        board_delta = pct_delta(ev.board_total, expected) if ev.board_total is not None else None
        errors_zero = all_error_counters_zero(rate)
        sim_ok = sim_delta is not None and abs(sim_delta) < 5.0
        board_ok = True if ev.board_total is None else (board_delta is not None and abs(board_delta) < 5.0)
        ev.rate_status = PASS if sim_ok and board_ok and errors_zero else FAIL
        if not errors_zero:
            ev.rate_notes.append("nonzero IP error counter")
        if ev.board_total is None:
            ev.rate_notes.append("board measured total TBD")

        hist_total = None
        if ev.hist_a_sum is not None and ev.hist_b_sum is not None:
            hist_total = ev.hist_a_sum + ev.hist_b_sum
        stddev = ev.scoreboard.get("delay_stddev_ns")
        if stddev is None:
            delays = ev.scoreboard.get("delay_ns", [])
            if isinstance(delays, list) and delays:
                mean = sum(float(x) for x in delays) / len(delays)
                stddev = math.sqrt(sum((float(x) - mean) ** 2 for x in delays) / len(delays))
        hist_ok = hist_total is not None and ev.sim_total is not None and abs(hist_total - ev.sim_total) <= 8
        std_ok = stddev is not None and float(stddev) < 100.0
        ev.delay_status = PASS if hist_ok and std_ok else FAIL
        if hist_total is None:
            ev.delay_notes.append("histogram banks missing")
        if stddev is None:
            ev.delay_notes.append("scoreboard stddev missing")

        rdma_ok = ev.rdma_record_count is not None and ev.sim_total is not None and abs(ev.rdma_record_count - ev.sim_total) <= 8
        ev.rdma_status = PASS if rdma_ok else FAIL
        if ev.board_total is None:
            ev.rdma_notes.append("board RDMA stream TBD")


def all_error_counters_zero(rate: dict[str, Any]) -> bool:
    errors = rate.get("error_counters", {})
    if not isinstance(errors, dict):
        return False
    for value in errors.values():
        if isinstance(value, (int, float)) and int(value) != 0:
            return False
    return True


def rate_rows(ev: Evidence) -> list[dict[str, Any]]:
    case = ev.case
    rows: list[dict[str, Any]] = []
    active_lanes = max(1, case.lane_popcount)
    per_lane_expected = case.expected_hits / active_lanes
    selected = ev.rate.get("arb_hit_type0_supercore", {}).get("selected_count", {})
    if isinstance(selected, dict):
        for lane_s, value in sorted(selected.items(), key=lambda item: int(item[0])):
            lane = int(lane_s)
            expected = per_lane_expected if ((case.lane_mask >> lane) & 1) else 0
            rows.append(make_counter_row("arb_hit_type0", f"SELECTED_COUNT (lane {lane})", None, value, expected, None))
    rows.append(
        make_counter_row(
            "arb_hit_type0",
            "DROPPED_HITS",
            None,
            find_int(ev.rate, ["arb_hit_type0_supercore", "dropped_hits"]),
            0,
            None,
        )
    )
    rows.append(
        make_counter_row(
            "histogram_statistics_v2",
            "TOTAL_HITS_CSR13",
            ev.board_total,
            ev.sim_total,
            case.expected_hits,
            ev.board_total,
        )
    )
    rows.append(
        make_counter_row(
            "histogram_statistics_v2",
            "LAST_INTERVAL_TOTAL_HITS_CSR17",
            None,
            find_int(ev.rate, ["histogram_statistics_v2", "last_interval_total_hits_csr17"]),
            case.expected_hits,
            None,
        )
    )
    checkpoints = ev.rate.get("checkpoints", {})
    if isinstance(checkpoints, dict):
        for name, value in sorted(checkpoints.items()):
            rows.append(make_counter_row("checkpoint", name, None, value, case.expected_hits, None))
    ring = ev.rate.get("ring_buffer_cam", {})
    if isinstance(ring, dict):
        per_ring_expected = case.expected_hits / max(1, len(ring))
        for bank, counters in sorted(ring.items()):
            if isinstance(counters, dict):
                rows.append(make_counter_row(f"ring_buffer_cam_{bank}", "push_cnt", None, counters.get("push_cnt"), per_ring_expected, None))
                rows.append(make_counter_row(f"ring_buffer_cam_{bank}", "pop_cnt", None, counters.get("pop_cnt"), per_ring_expected, None))
    errors = ev.rate.get("error_counters", {})
    if isinstance(errors, dict):
        for name, value in sorted(errors.items()):
            rows.append(make_counter_row("error_counters", name, None, value, 0, None))
    return rows


def make_counter_row(
    ip: str,
    counter: str,
    measured: int | float | None,
    sim: int | float | None,
    expected: int | float | None,
    board_for_delta: int | float | None,
) -> dict[str, Any]:
    return {
        "ip": ip,
        "counter": counter,
        "measured": int(measured) if isinstance(measured, (int, float)) else None,
        "sim": int(sim) if isinstance(sim, (int, float)) else None,
        "expected": expected,
        "sim_delta_pct": pct_delta(sim, expected),
        "board_delta_pct": pct_delta(board_for_delta, expected),
    }


def write_rate_md(ev: Evidence, case_dir: Path, per_ip_writer: csv.DictWriter[str]) -> None:
    rows = rate_rows(ev)
    lines = [f"# {ev.case.row_id} rate (CSR counters)", ""]
    if ev.rate_notes:
        lines.append("Notes: " + "; ".join(md_escape(note) for note in ev.rate_notes))
        lines.append("")
    lines.extend(
        [
            "| IP | counter | measured | sim | expected | sim_delta_pct | board_delta_pct |",
            "|---|---|---:|---:|---:|---:|---:|",
        ]
    )
    for row in rows:
        lines.append(
            f"| {md_escape(str(row['ip']))} | {md_escape(str(row['counter']))} | "
            f"{fmt_num(row['measured'])} | {fmt_num(row['sim'])} | {fmt_num(row['expected'])} | "
            f"{fmt_pct(row['sim_delta_pct'])} | {fmt_pct(row['board_delta_pct'])} |"
        )
        per_ip_writer.writerow(
            {
                "row_id": ev.case.row_id,
                "slice": ev.case.slice_id,
                "ip": row["ip"],
                "counter": row["counter"],
                "measured": "" if row["measured"] is None else row["measured"],
                "sim": "" if row["sim"] is None else row["sim"],
                "expected": "" if row["expected"] is None else row["expected"],
                "sim_delta_pct": "" if row["sim_delta_pct"] is None else f"{row['sim_delta_pct']:.6f}",
                "board_delta_pct": "" if row["board_delta_pct"] is None else f"{row['board_delta_pct']:.6f}",
            }
        )
    (case_dir / "rate.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_delay_md(ev: Evidence, case_dir: Path, plot_paths: dict[str, Path]) -> None:
    case = ev.case
    total_expected = case.expected_hits
    bank_expected = total_expected / 2.0
    stddev = ev.scoreboard.get("delay_stddev_ns")
    if stddev is None:
        delays = ev.scoreboard.get("delay_ns", [])
        if isinstance(delays, list) and delays:
            mean_calc = sum(float(x) for x in delays) / len(delays)
            stddev = math.sqrt(sum((float(x) - mean_calc) ** 2 for x in delays) / len(delays))
    mean = ev.scoreboard.get("delay_mean_ns", 0)
    count = ev.scoreboard.get("count", 0)
    hist_total = (ev.hist_a_sum or 0) + (ev.hist_b_sum or 0)
    lines = [f"# {case.row_id} delay (2 hist plot + scoreboard)", ""]
    if ev.delay_notes:
        lines.append("Notes: " + "; ".join(md_escape(note) for note in ev.delay_notes))
        lines.append("")
    rel_a = plot_paths["hist_bin_a"].relative_to(case_dir)
    rel_b = plot_paths["hist_bin_b"].relative_to(case_dir)
    rel_s = plot_paths["scoreboard_delay"].relative_to(case_dir)
    lines.extend(
        [
            "## hist bin A",
            f"![hist_bin_a]({rel_a.as_posix()})",
            f"bank-A sum: {fmt_num(ev.hist_a_sum)}; expected: {fmt_num(bank_expected)}; delta: {fmt_pct(pct_delta(ev.hist_a_sum, bank_expected))}",
            "",
            "## hist bin B",
            f"![hist_bin_b]({rel_b.as_posix()})",
            f"bank-B sum: {fmt_num(ev.hist_b_sum)}; expected: {fmt_num(bank_expected)}; delta: {fmt_pct(pct_delta(ev.hist_b_sum, bank_expected))}",
            "",
            f"combined bank sum: {fmt_num(hist_total)}; rate total: {fmt_num(ev.sim_total)}; delta: {fmt_num(hist_total - (ev.sim_total or 0))}",
            "",
            "## scoreboard delay vs true ts",
            f"![scoreboard_delay]({rel_s.as_posix()})",
            f"delay_mean_ns: {fmt_num(float(mean) if mean is not None else None)}",
            f"delay_stddev_ns: {fmt_num(float(stddev) if stddev is not None else None)}",
            f"count: {fmt_num(int(count) if count is not None else None)}",
        ]
    )
    (case_dir / "delay.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def sample_records(path: Path, record_size: int, start_record: int, count: int = 8) -> list[str]:
    if not path.exists() or record_size <= 0:
        return []
    with path.open("rb") as fh:
        fh.seek(start_record * record_size)
        data = fh.read(record_size * count)
    return [data[i : i + record_size].hex() for i in range(0, len(data), record_size)]


def write_rdma_md(ev: Evidence, case_dir: Path) -> dict[str, Any]:
    summary = ev.rdma_summary
    record_count = int(summary.get("record_count", 0) or 0)
    record_size = int(round(float(summary.get("record_size_avg", 64) or 64)))
    record_size = max(1, record_size)
    rxbuffer = ev.sim_dir / "rdma_rxbuffer.bin"
    first_samples = sample_records(rxbuffer, record_size, 0)
    mid_start = max(0, record_count // 2)
    mid_samples = sample_records(rxbuffer, record_size, mid_start)
    lines = [f"# {ev.case.row_id} rdma (rxbuffer 8-frame sample)", ""]
    if ev.rdma_notes:
        lines.append("Notes: " + "; ".join(md_escape(note) for note in ev.rdma_notes))
        lines.append("")
    lines.append(
        "Timestamp-jitter tolerance: retained evidence supports record-count parity; byte-level expected frames are marked TBD unless board bytes are available."
    )
    lines.append("")
    all_samples: dict[str, Any] = {
        "row_id": ev.case.row_id,
        "record_size": record_size,
        "record_count": record_count,
        "offset0": first_samples,
        "offset_mid": mid_samples,
    }
    for title, samples in [("offset 0", first_samples), (f"offset {mid_start}", mid_samples)]:
        lines.append(f"## {title}")
        lines.extend(
            [
                "| frame_idx | measured (hex) | sim (hex) | expected (hex) | match |",
                "|---|---|---|---|:-:|",
            ]
        )
        for idx in range(8):
            sim_hex = samples[idx] if idx < len(samples) else "--"
            lines.append(f"| {idx} | -- | {sim_hex} | -- | {FAIL} |")
        lines.append("")
    lines.extend(
        [
            f"record_count measured: {fmt_num(ev.board_total)}",
            f"record_count sim: {fmt_num(record_count)}",
            f"record_count expected: {fmt_num(ev.case.expected_hits)}",
        ]
    )
    (case_dir / "rdma.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return all_samples


def write_case_index(ev: Evidence, case_dir: Path) -> None:
    case = ev.case
    lines = [
        f"# {case.row_id}",
        "",
        f"Slice: {case.slice_id}",
        f"Injector mode: {case.injector_mode}",
        f"Anchor: lane={case.lane_hex}, chan={case.channel_hex}, rate_88fp={case.rate_hex}",
        f"Expected total hits: {fmt_num(case.expected_hits)}",
        "",
    ]
    if ev.plan_mismatch:
        lines.append("TBD: sim evidence row_config does not match the 194-row TEST_BASIC plan.")
        lines.append("")
    if ev.board_unresolved:
        lines.append(f"TBD: {ev.board_unresolved}.")
        lines.append("")
    lines.extend(
        [
            "| Condition | Status | Detail |",
            "|---|:-:|---|",
            f"| rate (CSR counters) | {ev.rate_status} | [rate.md](rate.md) |",
            f"| delay (2 hist + scoreboard) | {ev.delay_status} | [delay.md](delay.md) |",
            f"| rdma (rxbuffer record stream) | {ev.rdma_status} | [rdma.md](rdma.md) |",
        ]
    )
    (case_dir / "index.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_top_index(report_root: Path, run_id: str, commit: str | None, generated: str, evidences: list[Evidence]) -> None:
    lines = [
        "# Cosim Auto-Report (RN.BASIC, 194 cases)",
        "",
        f"Run ID: {run_id}",
        f"Cosim source commit: {commit or 'unknown'}",
        f"Generated: {generated}",
        "",
        "Source data:",
        f"- Sim: cosim/REPORT/RN.BASIC.NNN/ (commit {commit or 'unknown'})",
        "- Board: sweep_evidence/p45_NNN/ (32-row pre-arbfix; mapped where p45_NNN",
        "  aligns to RN.BASIC.NNN)",
        "- Expected: theoretical_hits from TEST_BASIC.md",
        "",
        "| ID | slice | injector_mode | rate | delay | rdma | detail |",
        "|---|---|---|:-:|:-:|:-:|---|",
    ]
    for ev in evidences:
        case = ev.case
        lines.append(
            f"| {case.row_id} | {case.slice_name} | {case.injector_mode} | "
            f"{ev.rate_status} | {ev.delay_status} | {ev.rdma_status} | "
            f"[{case.row_id}/]({case.row_id}/index.md) |"
        )
    lines.extend(["", "## Slice-level rollup"])
    slice_totals = {1: 128, 2: 32, 3: 2, 4: 32}
    slice_names = {1: "Slice 1 periodic", 2: "Slice 2 headersync", 3: "Slice 3 onclick", 4: "Slice 4 emul-only"}
    for slice_id in [1, 2, 3, 4]:
        passed = sum(1 for ev in evidences if ev.case.slice_id == slice_id and ev.rate_status == PASS and ev.delay_status == PASS and ev.rdma_status == PASS)
        lines.append(f"- {slice_names[slice_id]}: {passed} PASS / {slice_totals[slice_id]}")
    lines.extend(
        [
            "",
            "## Pass/fail rules",
            "- rate: |sim - expected| < 5% of expected AND |board - expected| < 5% (when board data present) AND every IP error counter is 0",
            "- delay: hist_bin_a sum + hist_bin_b sum matches the rate total within +/- 8; scoreboard delay_stddev_ns < 100 ns",
            "- rdma: record_count matches the rate total within +/- 8",
        ]
    )
    unresolved = unresolved_cases(evidences)
    if unresolved:
        lines.extend(["", "## TBD evidence"])
        for item in unresolved[:40]:
            lines.append(f"- {item}")
        if len(unresolved) > 40:
            lines.append(f"- ... {len(unresolved) - 40} more cases; see intermediate/per_case_summary.csv")
    (report_root / "index.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def unresolved_cases(evidences: list[Evidence]) -> list[str]:
    items: list[str] = []
    for ev in evidences:
        reasons = []
        if ev.board_unresolved:
            reasons.append("board")
        if ev.plan_mismatch:
            reasons.append("sim-plan")
        if ev.sim_missing:
            reasons.append("sim-missing")
        if reasons:
            items.append(f"{ev.case.row_id}: {', '.join(reasons)}")
    return items


def write_intermediates(report_root: Path, evidences: list[Evidence], frame_samples: list[dict[str, Any]]) -> None:
    intermediate = report_root / "intermediate"
    intermediate.mkdir(parents=True, exist_ok=True)
    with (intermediate / "per_case_summary.csv").open("w", encoding="utf-8", newline="") as fh:
        fields = [
            "row_id",
            "slice",
            "injector_mode",
            "lane_mask",
            "channel_mask",
            "rate_88fp",
            "expected_hits",
            "sim_total",
            "board_total",
            "hist_a_sum",
            "hist_b_sum",
            "rdma_record_count",
            "rate_status",
            "delay_status",
            "rdma_status",
            "tbd",
        ]
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        for ev in evidences:
            writer.writerow(
                {
                    "row_id": ev.case.row_id,
                    "slice": ev.case.slice_id,
                    "injector_mode": ev.case.injector_mode,
                    "lane_mask": ev.case.lane_hex,
                    "channel_mask": ev.case.channel_hex,
                    "rate_88fp": ev.case.rate_hex,
                    "expected_hits": ev.case.expected_hits,
                    "sim_total": "" if ev.sim_total is None else ev.sim_total,
                    "board_total": "" if ev.board_total is None else ev.board_total,
                    "hist_a_sum": "" if ev.hist_a_sum is None else ev.hist_a_sum,
                    "hist_b_sum": "" if ev.hist_b_sum is None else ev.hist_b_sum,
                    "rdma_record_count": "" if ev.rdma_record_count is None else ev.rdma_record_count,
                    "rate_status": "PASS" if ev.rate_status == PASS else "FAIL",
                    "delay_status": "PASS" if ev.delay_status == PASS else "FAIL",
                    "rdma_status": "PASS" if ev.rdma_status == PASS else "FAIL",
                    "tbd": "; ".join(ev.plan_mismatch + ([ev.board_unresolved] if ev.board_unresolved else [])),
                }
            )
    (intermediate / "frame_samples.json").write_text(json.dumps(frame_samples, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def generate_report(
    report_root: Path,
    run_id: str,
    commit: str | None,
    generated: str,
    evidences: list[Evidence],
    renderer: Path,
) -> None:
    report_root.mkdir(parents=True)
    intermediate = report_root / "intermediate"
    intermediate.mkdir(parents=True)
    per_ip_path = intermediate / "per_ip_counter_chain.csv"
    frame_samples: list[dict[str, Any]] = []
    with per_ip_path.open("w", encoding="utf-8", newline="") as per_ip_fh:
        per_ip_writer = csv.DictWriter(
            per_ip_fh,
            fieldnames=[
                "row_id",
                "slice",
                "ip",
                "counter",
                "measured",
                "sim",
                "expected",
                "sim_delta_pct",
                "board_delta_pct",
            ],
        )
        per_ip_writer.writeheader()
        for ev in evidences:
            case_dir = report_root / ev.case.row_id
            plots_dir = case_dir / "plots"
            plots_dir.mkdir(parents=True, exist_ok=True)
            plot_paths = {
                "hist_bin_a": render_dislin(
                    renderer,
                    "hist",
                    hist_points(ev.hist_a),
                    f"{ev.case.row_id} hist bin A",
                    f"sum {fmt_num(ev.hist_a_sum)} expected {fmt_num(ev.case.expected_hits / 2.0)}",
                    plots_dir / "hist_bin_a.pdf",
                ),
                "hist_bin_b": render_dislin(
                    renderer,
                    "hist",
                    hist_points(ev.hist_b),
                    f"{ev.case.row_id} hist bin B",
                    f"sum {fmt_num(ev.hist_b_sum)} expected {fmt_num(ev.case.expected_hits / 2.0)}",
                    plots_dir / "hist_bin_b.pdf",
                ),
                "scoreboard_delay": render_dislin(
                    renderer,
                    "hist",
                    delay_hist_points(ev.scoreboard),
                    f"{ev.case.row_id} scoreboard delay",
                    f"count {fmt_num(ev.scoreboard.get('count', 0))}",
                    plots_dir / "scoreboard_delay.pdf",
                ),
            }
            write_rate_md(ev, case_dir, per_ip_writer)
            write_delay_md(ev, case_dir, plot_paths)
            frame_samples.append(write_rdma_md(ev, case_dir))
            write_case_index(ev, case_dir)
    write_intermediates(report_root, evidences, frame_samples)
    write_top_index(report_root, run_id, commit, generated, evidences)


def main() -> int:
    args = parse_args()
    build_dir = args.build_dir.resolve()
    cosim_report = (args.cosim_report or build_dir / "cosim" / "REPORT").resolve()
    board_sweep = (args.board_sweep or build_dir / "sweep_evidence").resolve()
    run_id, commit = choose_run_id(build_dir, cosim_report, args.run_id)
    default_report_root = build_dir / "reports" / run_id
    report_root_arg = args.report_root.resolve() if args.report_root else default_report_root
    run_id, report_root = fresh_report_root(report_root_arg, args.run_id or args.report_root, run_id)
    generated = datetime.now().astimezone().replace(microsecond=0).isoformat()

    cases = parse_test_basic(args.test_basic.resolve())
    board_map, board_unresolved = discover_board_mapping(board_sweep, cases)
    evidences = collect_evidence(cases, cosim_report, board_map)
    if board_unresolved and not board_map:
        for ev in evidences:
            ev.board_unresolved = "p45 board evidence is not BASIC-compatible"
            if "board measured total TBD" not in ev.rate_notes:
                ev.rate_notes.append("board measured total TBD")
            if "board RDMA stream TBD" not in ev.rdma_notes:
                ev.rdma_notes.append("board RDMA stream TBD")
    renderer = compile_renderer(run_id)
    generate_report(report_root, run_id, commit, generated, evidences, renderer)
    print(f"RUN_ID={run_id}")
    print(f"REPORT_ROOT={report_root}")
    print(f"COSIM_COMMIT={commit or 'unknown'}")
    print(f"BOARD_MAPPED={len(board_map)}")
    print(f"BOARD_UNRESOLVED={len(board_unresolved)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
