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
        "phase5_mutrig_restore_full32_tuned_baseline_20260430.json",
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
        "phase5_real_lower_lanes56_ch1_quietemu_pulse4_delay_2000cyc_20260430.json",
        "Pair fails with MTS tserr forwarded into the ring.",
    ),
    (
        "ASIC6 ext offset",
        "Tune",
        "phase5_real_lower_lanes56_ch1_asic6_extoffset1_pulse4_delay_2000cyc_20260430.json",
        "Header ext_trig_offset=1 on ASIC6 did not improve the lower pair.",
    ),
    (
        "ASIC5 ext offset",
        "Tune",
        "phase5_real_lower_lanes56_ch1_asic5_extoffset1_pulse4_delay_2000cyc_20260430.json",
        "Header ext_trig_offset=1 on ASIC5 made accepted delay counts worse.",
    ),
    (
        "ASIC6 sync_ch_rst=0",
        "Tune",
        "phase5_real_lower_lanes56_ch1_asic6_synchrst0_pulse4_delay_2000cyc_20260430.json",
        "Reset-sync flip on ASIC6 did not improve the lower pair.",
    ),
    (
        "ASIC5 sync_ch_rst=0",
        "Tune",
        "phase5_real_lower_lanes56_ch1_asic5_synchrst0_pulse4_delay_2000cyc_20260430.json",
        "Reset-sync flip on ASIC5 did not improve the lower pair.",
    ),
    (
        "Lower pair cml_sc=1",
        "Tune",
        "phase5_real_lower_lanes56_ch1_cmlsc1_pulse4_delay_2000cyc_20260430.json",
        "Wiki CML-scale setting kills accepted delay counts while ring errors remain.",
    ),
    (
        "ASIC6 40/30/30",
        "Tune",
        "phase5_real_lower_lanes56_ch1_asic6_cnt40_vcd30_hl30_pulse4_delay_2000cyc_20260430.json",
        "Known SMB5 local-2 PLL point did not clear the lower-pair error.",
    ),
    (
        "ASIC6 PLL-half",
        "Tune",
        "phase5_real_lower_lanes56_ch1_asic6_cnt25off1_vcd20_hl40_pulse4_delay_2000cyc_20260430.json",
        "Older pll-half local-2 point did not clear the lower-pair error.",
    ),
    (
        "SMB5 241204 pair config",
        "Tune",
        "phase5_real_lower_lanes56_ch1_smb005_241204_pulse4_delay_2000cyc_20260430.json",
        "Full older ASIC5/6 local config is worse than good_ribbon_0.",
    ),
    (
        "Lane5 one-channel rate",
        "Rate",
        "phase5_real_lane5_ch1_rate100k_goodribbon_pulse4_2500ms_20260430.json",
        "Quick rate profile is out of tolerance and not stable enough for closure.",
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
    klass = "pass" if result == "PASS" else "missing" if result == "MISSING" else "fail"
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
      Single-lane delay can be made clean, but the lower pair <code>lanes5+6</code>
      still forwards MTS timestamp errors into the lower ring-buffer CAM even at
      one TDC-test channel per ASIC. No FEB/SWB host-disk 256-hit, 100 kHz
      end-to-end claim is valid yet.
    </div>

    <h2>Current Read</h2>
    <p>
      The strongest blocker is not the deprecated injector path or XML mapping.
      The active injector is the Phase-5 <code>mutrig_injector_0</code> path and
      the XML split is SMB3 for ASICs 0..3 and SMB5 for ASICs 4..7. The lower
      side fails because MTS asserts <code>tserr</code> before the ring stage;
      the ring <code>inerr_count</code> is therefore a real timestamp-delay
      failure, not a ring-local decode bug.
    </p>
    <p>
      Tuning attempts that did not clear the lower pair include
      <code>ext_trig_offset</code>, <code>sync_ch_rst</code>,
      <code>cml_sc=1</code>, ASIC6 <code>40/30/30</code>, ASIC6 pll-half, and
      the older SMB5 241204 local config. The upper pair behaves differently:
      <code>lanes1+2</code> passes at one channel and fails at full multiplicity.
    </p>
    <p>
      MuTRiG tuning reference: <a href="{esc(rel(mutrig_doc))}">MUTRIG.md</a>.
      That page links the local MuTRiG wiki mirror and records the DMON/TDC
      injection implications used here.
    </p>

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
