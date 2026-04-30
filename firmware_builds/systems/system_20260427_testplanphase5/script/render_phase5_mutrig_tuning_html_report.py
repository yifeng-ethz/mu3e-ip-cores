#!/usr/bin/env python3
"""Render the live Phase-5 MuTRiG tuning evidence into one HTML page."""

from __future__ import annotations

import datetime as dt
import html
import json
import os
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent
REPO_ROOT = SYSTEM_DIR.parent.parent.parent
REPORT_DIR = SYSTEM_DIR / "reports"
OUT_HTML = REPORT_DIR / "phase5_mutrig_tuning_report_20260430.html"


EVIDENCE = [
    (
        "Restore full tuned baseline",
        "Config",
        "phase5_mutrig_restore_full32_tuned_baseline_20260430e.json",
        "All eight ASICs reloaded full-channel with the single-lane-clean PLL overrides.",
    ),
    (
        "Single-lane matrix",
        "Delay",
        "phase5_real_256ch_per_lane_best2_pulse4_delay_2000cyc_20260429.json",
        "Eight isolated lanes pass the 2000-cycle MTS/ring error gate.",
    ),
    (
        "All lanes together",
        "Delay",
        "phase5_real_256ch_all_lanes_best2_pulse4_delay_2000cyc_20260429.json",
        "All-lane run still fails on ring input errors.",
    ),
    (
        "Upper lanes 1+2, one channel",
        "Delay",
        "phase5_real_upper_lanes12_ch1_quietemu_pulse4_delay_2000cyc_20260430.json",
        "Passes when parked emulator lanes are disabled.",
    ),
    (
        "Upper lanes 1+2, full channels",
        "Delay",
        "phase5_real_upper_lanes12_best2_pulse4_delay_2000cyc_20260429.json",
        "Fails only when full-channel multiplicity is restored.",
    ),
    (
        "Lower lane 5, one channel",
        "Delay",
        "phase5_real_lane5_ch1_goodribbon_pulse4_delay_2000cyc_20260430.json",
        "Lane 5 alone passes.",
    ),
    (
        "Lower lane 6, one channel",
        "Delay",
        "phase5_real_lane6_ch1_goodribbon_pulse4_delay_2000cyc_20260430.json",
        "Lane 6 alone passes.",
    ),
    (
        "Lower lanes 5+6, one channel",
        "Delay",
        "phase5_real_lower_lanes56_ch1_goodribbon_latency2000_retry_pulse4_20260430.json",
        "After restoring ASIC5/6 from the good-ribbon config, the one-channel pair passes at the 2000-cycle gate.",
    ),
    (
        "Lower lanes 5+6, full channels",
        "Delay",
        "phase5_real_lower_lanes56_full32_postrestore_latency2000_pulse4_20260430.json",
        "Fresh post-restore full 32-channel ASIC5+6 run fails the required 0..2000-cycle MTS/ring gate.",
    ),
    (
        "Lower full channels, loose latency",
        "Delay",
        "phase5_real_lower_lanes56_full32_latency65535_pulse4_20260430.json",
        "Still fails even with expected latency opened to 65535, so this is not a small positive-latency tail.",
    ),
    (
        "Lower pair bypass-lapse",
        "Diagnostic",
        "phase5_real_lower_lanes56_full32_bypasslapse_latency2000_pulse4_20260430.json",
        "Disabling the MTS GTS/lapse transform does not clear the lower-pair timestamp errors.",
    ),
    (
        "Lower pair E-field delay",
        "Diagnostic",
        "phase5_real_lower_lanes56_full32_delayfieldE_latency2000_pulse4_20260430.json",
        "Using E instead of T for delay calculation is worse, matching the short-mode TDC-injection expectation.",
    ),
    (
        "Lower pair drop-delay",
        "Diagnostic",
        "phase5_real_lower_lanes56_full32_dropdelay_latency2000_pulse4_20260430.json",
        "Dropping MTS delay-error hits keeps the downstream ring clean, but this is diagnostic-only and not closure.",
    ),
    (
        "Lower channels 0..3",
        "Mask scan",
        "phase5_real_lower_lanes56_chmask_00_03_latency2000_pulse4_20260430.json",
        "A four-channel mask can pass, proving full-channel failure is not a universal lane lock loss.",
    ),
    (
        "Lower channels 4..7",
        "Mask scan",
        "phase5_real_lower_lanes56_chmask_04_07_latency2000_pulse4_20260430.json",
        "This adjacent four-channel mask fails, showing channel grouping still matters.",
    ),
    (
        "Lower pass-union mask",
        "Mask scan",
        "phase5_real_lower_lanes56_chmask_pass_union_latency2000_pulse4_20260430.json",
        "The union of individually clean channel groups still fails when aggregated across ASIC5+6.",
    ),
    (
        "Lane 5 full channels",
        "Delay",
        "phase5_real_lane5_full32_hl60_latency2000_pulse4_20260430.json",
        "ASIC5/lane5 passes full 32 channels by itself with vnhitlogic=60.",
    ),
    (
        "Lane 6 full channels",
        "Delay",
        "phase5_real_lane6_full32_hl60_latency2000_pulse4_20260430.json",
        "ASIC6/lane6 passes full 32 channels by itself with vnhitlogic=60.",
    ),
    (
        "Lower pair hitlogic 60",
        "Tune",
        "phase5_real_lower_lanes56_full32_hl60_latency2000_pulse4_20260430.json",
        "Raising vnhitlogic on both ASICs does not clear the pair-level full-channel failure.",
    ),
    (
        "Lower pulse3 hitlogic 10",
        "Pulse edge",
        "phase5_real_lower_lanes56_full32_hl10_latency2000_pulse3_20260430.json",
        "Pulse high 3 with vnhitlogic=10 is clean but far below full 32-channel multiplicity.",
    ),
    (
        "Lower pulse3 hitlogic 5",
        "Pulse edge",
        "phase5_real_lower_lanes56_full32_hl5_latency2000_pulse3_20260430.json",
        "Lowering hitlogic to 5 remains clean but still underfilled.",
    ),
    (
        "Lower pulse4 hitlogic 5",
        "Pulse edge",
        "phase5_real_lower_lanes56_full32_hl5_latency2000_pulse4_20260430.json",
        "The next integer pulse width restores multiplicity but also restores MTS/ring errors.",
    ),
    (
        "Lower pulse3 cml_sc=1",
        "Pulse edge",
        "phase5_real_lower_lanes56_full32_hl10_cmlsc1_latency2000_pulse3_20260430.json",
        "The wiki cml_sc=1 setting moves pulse3 farther away from the required multiplicity.",
    ),
    (
        "Lower pair at 10 kHz/channel",
        "Tune",
        "phase5_real_lower_lanes56_full32_hl60_latency2000_pulse4_interval12500_20260430.json",
        "Even 10 kHz/channel still fails, so the blocker is not only 100 kHz steady-state throughput.",
    ),
    (
        "ASIC5 ext offset",
        "Tune",
        "phase5_real_lower_lanes56_full32_asic5_extoffset1_latency2000_pulse4_20260430.json",
        "Header ext_trig_offset=1 on ASIC5 makes the full-channel pair worse, not better.",
    ),
    (
        "ASIC6 ext offset",
        "Tune",
        "phase5_real_lower_lanes56_full32_asic6_extoffset1_latency2000_pulse4_20260430.json",
        "Header ext_trig_offset=1 on ASIC6 also worsens the full-channel pair.",
    ),
]

PROGRESS = [
    (
        "FEB MuTRiG output",
        "BLOCKED",
        "256 real channels at 100 kHz/channel must enter FEB DMA-side logic with matching 256-hit timestamps.",
        "Full-channel lower ASIC5+6 and all-lane runs still produce MTS/ring timestamp errors. Single lanes and selected masks pass the 0..2000-cycle gate.",
        "Keep tuning at MTS/ring boundary; do not claim FEB closure from single-lane evidence.",
    ),
    (
        "SWB input path",
        "BLOCKED",
        "SWB must receive FEB data and the SC read/reply path must return host-visible replies from FEB.",
        "online_sc commit ada3aea38 full flow, assembly, programming, and PCIe recovery passed with SOF checksum 0x31AA0589. Reset-link stop-reset/enable echoed 0x31000000/0x32000000; valid SC reads still time out at the host, but FEB sc_hub JTAG latched LAST_RD_ADDR=0x0000C000 and LAST_RD_DATA=0x52434D48.",
        "Use SWB SignalTap on swb_sc_secondary to decide whether the FEB reply reaches the secondary capture or is lost before the host ring.",
    ),
    (
        "SWB OPQ to DMA",
        "BLOCKED",
        "Merged hit words must drive the existing SWB DMA outputs with OPQ accounting matching the active hit-limit profile.",
        "packet_scheduler ed249da carries the 26.5 Mu3e Demo signoff merge; the underlying 25e204c UVM case proves N_HIT=255 delivers 255 hits and records exactly one drop. Hardware OPQ proof is still blocked before SWB input/DMA because the SC reply path is not host-visible.",
        "After the SC return path and SWB input gate pass, read OPQ ingress/drop CSRs and require the same 255-delivered plus 1-drop ledger before any host-disk claim.",
    ),
    (
        "Host DMA buffer",
        "BLOCKED",
        "/dev/mudaq0 must receive SWB DMA data from the OPQ/event-builder chain.",
        "PCIe recovery passed and /dev/mudaq0 is present after SWB programming, but no valid host DMA capture exists for the new SWB OPQ image because the SWB-side return/input gate is still blocked.",
        "Capture a bounded DMA run only after P6-SWB-IN passes with a returned FEB SC read and advancing FEB/SWB counters.",
    ),
    (
        "Disk/offline timestamp check",
        "BLOCKED",
        "Mu3e Demo OPQ: every decoded bunch must contain 255 delivered hits with identical TS, OPQ must account exactly one dropped hit from the 256-hit source cluster, and adjacent bunch TS spacing must match 100 kHz.",
        "No disk artifact has been produced yet for the 256-channel, 100 kHz/channel Mu3e Demo OPQ requirement; the live blocker is upstream at SWB secondary return/input proof.",
        "Add the offline reducer next to the long-run scripts, then run it on the first post-SWB-input DMA artifact.",
    ),
]


def esc(value: Any) -> str:
    return html.escape(str(value), quote=True)


def rel(path: Path) -> str:
    return Path(os.path.relpath(path, REPORT_DIR)).as_posix()


def fmt_int(value: Any) -> str:
    if value is None:
        return "-"
    try:
        return f"{int(value):,}"
    except (TypeError, ValueError):
        return esc(value)


def load_json(name: str) -> dict[str, Any] | None:
    path = REPORT_DIR / name
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def first_case(cases: Any) -> dict[str, Any] | None:
    if isinstance(cases, list) and cases:
        return cases[0]
    if isinstance(cases, dict):
        return cases
    return None


def summarize_case(case: dict[str, Any]) -> dict[str, Any]:
    summary = case.get("summary", {})
    return {
        "result": "PASS" if summary.get("pass") else "FAIL",
        "class": summary.get("phase5_classification", "-"),
        "scope": f"lvds=0x{int(case.get('lane_go', 0)):03X}",
        "active": f"emu=0x{int(case.get('active_lanes_mask', 0)):02X}",
        "pulse": case.get("injector_config", {}).get("pulse_high_cycles"),
        "duration": case.get("duration_ms"),
        "hist": summary.get("hist_total_delta"),
        "mts": summary.get("mts_total_delta"),
        "mts_disc": summary.get("mts_discard_delta"),
        "ring": summary.get("ring_inerr_delta"),
        "frame": summary.get("frame_actual_delta"),
        "crc": summary.get("frame_crc_delta"),
    }


def summarize_records(records: list[dict[str, Any]]) -> dict[str, Any]:
    if not records:
        return {"result": "EMPTY"}

    failures = [
        record for record in records
        if not record.get("summary", {}).get("pass") and record.get("status") != "PASS"
    ]
    lane_mask = 0
    active_mask = 0
    for record in records:
        lane_mask |= int(record.get("lane_go", 0))
        active_mask |= int(record.get("active_lanes_mask", 0))

    def total(field: str) -> int:
        return sum(int(record.get("summary", {}).get(field, 0) or 0) for record in records)

    first = records[0]
    pulse = first.get("injector_config", {}).get("pulse_high_cycles")
    duration = first.get("duration_ms")
    return {
        "result": "PASS" if not failures else "FAIL",
        "class": f"{len(records) - len(failures)} / {len(records)} pass",
        "scope": f"lvds=0x{lane_mask:03X}",
        "active": f"emu=0x{active_mask:02X}",
        "pulse": pulse,
        "duration": duration,
        "hist": total("hist_total_delta"),
        "mts": total("mts_total_delta"),
        "mts_disc": total("mts_discard_delta"),
        "ring": total("ring_inerr_delta"),
        "frame": total("frame_actual_delta"),
        "crc": total("frame_crc_delta"),
    }


def summarize_payload(payload: dict[str, Any] | None) -> dict[str, Any]:
    if payload is None:
        return {"result": "MISSING"}
    if "cases" in payload:
        case = first_case(payload.get("cases", []))
        if case is None:
            return {"result": "EMPTY"}
        return summarize_case(case)
    if "records" in payload:
        records = payload.get("records", [])
        if not isinstance(records, list):
            return {"result": "UNKNOWN"}
        return summarize_records(records)
    if "rows" in payload:
        rows = payload.get("rows", [])
        failures = [row for row in rows if not row.get("pass")]
        return {
            "result": "PASS" if not failures else "FAIL",
            "class": f"{len(rows) - len(failures)} / {len(rows)} configured",
            "scope": "config",
            "active": "-",
            "pulse": "-",
            "duration": "-",
            "hist": "-",
            "mts": "-",
            "mts_disc": "-",
            "ring": "-",
            "frame": "-",
            "crc": "-",
        }
    return {"result": "UNKNOWN"}


def badge(result: str) -> str:
    if result in {"PASS", "PASS_DIAG", "PASS_WITH_METHOD_NOTE", "PASS_DEBUG_ONLY"}:
        klass = "pass"
    elif result in {"PENDING", "IN_PROGRESS", "MISSING"}:
        klass = "missing"
    else:
        klass = "fail"
    return f'<span class="badge {klass}">{esc(result)}</span>'


def evidence_rows() -> str:
    rows = []
    for title, kind, filename, note in EVIDENCE:
        payload = load_json(filename)
        summary = summarize_payload(payload)
        path = REPORT_DIR / filename
        link = f'<a href="{esc(rel(path))}">{esc(filename)}</a>' if path.exists() else esc(filename)
        rows.append(
            "<tr>"
            f"<td>{esc(kind)}</td>"
            f"<td>{esc(title)}<div class=\"note\">{esc(note)}</div></td>"
            f"<td>{badge(summary.get('result', '-'))}<div class=\"class\">{esc(summary.get('class', '-'))}</div></td>"
            f"<td>{esc(summary.get('scope', '-'))}<br>{esc(summary.get('active', '-'))}</td>"
            f"<td>{fmt_int(summary.get('pulse'))}<br>{fmt_int(summary.get('duration'))} ms</td>"
            f"<td>{fmt_int(summary.get('hist'))}</td>"
            f"<td>{fmt_int(summary.get('mts'))}</td>"
            f"<td>{fmt_int(summary.get('mts_disc'))}</td>"
            f"<td>{fmt_int(summary.get('ring'))}</td>"
            f"<td>{fmt_int(summary.get('frame'))}</td>"
            f"<td>{fmt_int(summary.get('crc'))}</td>"
            f"<td>{link}</td>"
            "</tr>"
        )
    return "\n".join(rows)


def progress_rows() -> str:
    rows = []
    for stage, result, gate, evidence, next_step in PROGRESS:
        rows.append(
            "<tr>"
            f"<td>{esc(stage)}</td>"
            f"<td>{badge(result)}</td>"
            f"<td>{esc(gate)}</td>"
            f"<td>{esc(evidence)}</td>"
            f"<td>{esc(next_step)}</td>"
            "</tr>"
        )
    return "\n".join(rows)


def write_html() -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    now = dt.datetime.now().isoformat(timespec="seconds")
    mutrig_doc = REPO_ROOT / "firmware_builds" / "doc" / "MUTRIG.md"
    html_text = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Phase-5 MuTRiG Tuning Report</title>
  <style>
    body {{
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: #182026;
      background: #f6f7f8;
    }}
    header {{
      padding: 24px 32px 18px;
      background: #fff;
      border-bottom: 1px solid #d8dde3;
    }}
    main {{ padding: 24px 32px 40px; }}
    h1 {{ margin: 0 0 8px; font-size: 28px; letter-spacing: 0; }}
    h2 {{ margin: 28px 0 12px; font-size: 18px; letter-spacing: 0; }}
    p {{ max-width: 1100px; line-height: 1.45; }}
    table {{
      width: 100%;
      border-collapse: collapse;
      background: #fff;
      border: 1px solid #d8dde3;
      font-size: 13px;
    }}
    th, td {{
      padding: 8px 10px;
      border-bottom: 1px solid #e4e8ec;
      text-align: left;
      vertical-align: top;
    }}
    th {{ background: #edf1f4; font-weight: 650; }}
    .badge {{
      display: inline-block;
      min-width: 52px;
      padding: 2px 7px;
      border-radius: 4px;
      color: #fff;
      text-align: center;
      font-weight: 650;
      font-size: 12px;
    }}
    .pass {{ background: #1d7f45; }}
    .fail {{ background: #b73535; }}
    .missing {{ background: #6b7280; }}
    .progress-table td:nth-child(3),
    .progress-table td:nth-child(4),
    .progress-table td:nth-child(5) {{ min-width: 220px; }}
    .note, .class {{
      margin-top: 4px;
      color: #52606d;
      font-size: 12px;
      line-height: 1.35;
    }}
    .callout {{
      background: #fff;
      border-left: 4px solid #b73535;
      padding: 12px 14px;
      margin: 16px 0;
      max-width: 1120px;
    }}
    code {{ background: #edf1f4; padding: 1px 4px; border-radius: 3px; }}
    a {{ color: #0a5ca8; text-decoration: none; }}
    a:hover {{ text-decoration: underline; }}
  </style>
</head>
<body>
  <header>
    <h1>Phase-5 MuTRiG Tuning Report</h1>
    <div>Generated {esc(now)} from JSON evidence under <code>{esc(REPORT_DIR)}</code>.</div>
  </header>
  <main>
    <div class="callout">
      <strong>Closure status: FAIL.</strong>
      Single-lane delay can be made clean and the lower <code>lanes5+6</code>
      one-channel pair now passes after a clean good-ribbon restore. The blocker
      is the full-channel pair: ASIC5 and ASIC6 each pass alone, but together
      they still forward MTS timestamp errors into the lower ring-buffer CAM.
      No FEB/SWB host-disk Mu3e Demo OPQ, 100 kHz end-to-end claim is valid
      yet. Under the active <code>N_HIT=255</code> profile, a 256-hit source
      cluster must deliver 255 hits and account exactly one OPQ hit drop.
      The SWB OPQ image itself has compiled and programmed, but the SC reply
      path is still not host-visible.
    </div>

    <h2>Current Read</h2>
    <p>
      The strongest blocker is not the deprecated injector path or XML mapping.
      The active injector is the Phase-5 <code>mutrig_injector_0</code> path and
      the XML split is SMB3 for ASICs 0..3 and SMB5 for ASICs 4..7. The lower
      side fails at full multiplicity because MTS asserts
      <code>tserr</code> before the ring stage; the ring
      <code>inerr_count</code> is therefore a real timestamp-delay failure,
      not a ring-local decode bug.
    </p>
    <p>
      The lower full-channel pair also fails with the MTS expected-latency
      window opened to 65535 and at 10 kHz/channel. Channel-mask scans prove
      some groups are clean alone, but their union still fails. That points at
      a cross-ASIC ordering/epoch interaction in the lower MTS path, not a
      single dead lane. Bypassing the MTS lapse transform did not clear it, and
      using the E timestamp field made it worse. Pulse-width scans show a hard
      threshold: pulse high 3 is clean but badly underfilled, while pulse high 4
      has multiplicity but trips MTS/ring errors. The upper pair behaves differently:
      <code>lanes1+2</code> passes at one channel and fails at full
      multiplicity.
    </p>
    <p>
      MuTRiG tuning reference: <a href="{esc(rel(mutrig_doc))}">MUTRIG.md</a>.
      That page links the local MuTRiG wiki mirror and records the DMON/TDC
      injection implications used here.
    </p>
    <p>
      SWB live preflight on 2026-04-30 programmed the online_sc image
      <code>ada3aea38</code> with SOF checksum <code>0x31AA0589</code>, recovered
      PCIe, and restored <code>/dev/mudaq0</code>. Reset-link commands to FEB 7
      echo state. Valid SC reads still time out at the host, but FEB
      <code>sc_hub</code> JTAG readback latched
      <code>LAST_RD_ADDR=0x0000C000</code> and
      <code>LAST_RD_DATA=0x52434D48</code>. That localizes the blocker to FEB
      upload into SWB secondary capture, or the SWB secondary host-ring drain,
      before OPQ hardware counters, host DMA, and disk decode can count.
    </p>

    <h2>Phase-6 End-to-End Progress</h2>
    <p>
      Closure still means the full hardware chain, not just a FEB-local
      histogram. The required source proof is 100 kHz injection on all 256
      MuTRiG channels with one timestamp per 256-hit source bunch. The active
      SWB/ER OPQ profile is Mu3e Demo: <code>N_SHD=128</code>,
      <code>N_HIT=255</code>. Therefore the host-disk proof for this checkpoint
      is 255 delivered same-timestamp hits plus exactly one accounted OPQ
      <code>drop_hit</code> per 256-hit source cluster, with adjacent bunch
      timestamps matching the 100 kHz cadence.
    </p>
    <table class="progress-table">
      <thead>
        <tr>
          <th>Stage</th>
          <th>Status</th>
          <th>Gate</th>
          <th>Current Evidence</th>
          <th>Next Check</th>
        </tr>
      </thead>
      <tbody>
{progress_rows()}
      </tbody>
    </table>

    <h2>Evidence Table</h2>
    <table>
      <thead>
        <tr>
          <th>Kind</th>
          <th>Run</th>
          <th>Result</th>
          <th>Scope</th>
          <th>Pulse / Duration</th>
          <th>Hist</th>
          <th>MTS</th>
          <th>MTS Disc</th>
          <th>Ring InErr</th>
          <th>Frame Actual</th>
          <th>CRC</th>
          <th>Artifact</th>
        </tr>
      </thead>
      <tbody>
{evidence_rows()}
      </tbody>
    </table>
  </main>
</body>
</html>
"""
    OUT_HTML.write_text(html_text, encoding="utf-8")
    print(OUT_HTML)


def main() -> int:
    write_html()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
