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
        "This early good-ribbon pass is now superseded by the timing-closed Phase-6 image, where explicit SMB5 reload reproduced the lower one-channel MTS/ring failure.",
    ),
    (
        "Lower ASIC5/6 cross-ASIC sweep",
        "Phase6",
        "phase6_lower56_cross_asic_sweep_20260430.json",
        "ASIC5/lane5 and ASIC6/lane6 pass alone, the real two-lane pair fails, ASIC6 ext_trig_offset 0..15 does not clear it, and the two-lane emulator reference passes after settle.",
    ),
    (
        "Lane 6 zero VCO point",
        "Phase6",
        "phase6_lane6_vco000_pulse4_100k_20260430_192903.json",
        "ASIC6/lane6 still passes at vncnt=0, vnvcodelay=0, vnhitlogic=0; the zero-point assumption is not a no-hit/reset condition here.",
    ),
    (
        "Lane 6 FEB frame boundary",
        "Phase6",
        "phase6_frame_boundary_lane6_vco000_100k_active_inject_20260430.json",
        "ASIC6/lane6 single-channel active-window run passes counters while the boundary STP records nonzero FEB hit_type3 frame content; same-window nonempty RBCAM alignment remains open.",
    ),
    (
        "Lane 7 zero VCO point",
        "Phase6",
        "phase6_lane7_vco000_pulse4_100k_20260430_193008.json",
        "ASIC7/lane7 also passes at vncnt=0, vnvcodelay=0, vnhitlogic=0 with zero LVDS/DPA deltas.",
    ),
    (
        "Lanes 6+7 zero VCO pair",
        "Phase6",
        "phase6_lane67_vco000_pulse4_100k_20260430_193112.json",
        "ASIC6+7 together fail with ring input errors while each lane passes alone, matching the lower multi-ASIC timestamp/order blocker.",
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
        "The timing-closed Phase-6 rerun fails the nominal lower ASIC5+6 one-channel case after explicit SMB5 XML reload. The follow-up sweep shows ASIC5/lane5 and ASIC6/lane6 pass alone, but the two real lanes fail together; ASIC6 ext_trig_offset 0..15 does not clear the error; the two-lane emulator reference through the same lower MTS/ring path passes after 50 ms settle. Runner replay 20260430_190036 records P6B006/P6B007 expected_pass, P6B010 unexpected_fail with ring_inerr_delta=534904, P6B020 expected_fail, and P6E010 underfilled. New lane6/7 zero-point tests show ASIC6 and ASIC7 each pass at vncnt=0/vnvcodelay=0/vnhitlogic=0, but the lane6+7 pair fails with ring_inerr_delta=826978 and zero LVDS/DPA deltas. The single-ASIC lane6 FEB frame-boundary run passes counters and the active STP window shows nonzero hit_type3 frame content, but same-window nonempty RBCAM-to-frame-assembly alignment is still open. SignalTap shows mts1.aso_hit_type1_error and hit_stack1.hit_type_1_error[0] rising in the same exported VCD window for the bad lower pair.",
        "Debug real MuTRiG cross-ASIC timestamp/epoch/order coherence before or inside lower MTS, and close the RBCAM-to-FEB-frame same-window alignment with a deeper or better-triggered STP/simulation correlation.",
    ),
    (
        "SWB input path",
        "PASS_SC",
        "SWB must receive FEB data and the SC read/reply path must return host-visible replies from FEB.",
        "online_sc commit 11eada541 compiled timing-clean at all checked STA corners, programmed SOF checksum 0x31A704E1, recovered /dev/mudaq0, and returned host-visible SC link-2 reads: 0x00000 payload 0 and 0x0C000 payload 0x52434D48.",
        "Hold SWB SciFi-hit input proof until FEB emits clean hit frames; the SC path itself is no longer the blocker.",
    ),
    (
        "SWB OPQ to DMA",
        "BLOCKED",
        "Merged hit words must drive the existing SWB DMA outputs with OPQ accounting matching the active hit-limit profile.",
        "packet_scheduler ed249da carries the 26.5 Mu3e Demo signoff merge; the underlying 25e204c UVM case proves N_HIT=255 delivers 255 hits and records exactly one drop. A repo-owned direct-MMIO datagen probe then found a separate SWB firmware blocker: datagen-driven runs produced no DMA words and no mux/event-builder counter movement because generated link records stayed idle before musip_mux_4_1. online_sc swb_block.vhd is patched to decode gen_link data/datak with work.mu3e.to_link(...); SWB make flow_map passed with 0 errors and 182 warnings, but full compile/reflash/board rerun are still required before closure.",
        "Finish SWB full compile/reflash, rerun the datagen probe until mux/event-builder counters and DMA words advance, then read OPQ ingress/drop CSRs and require the same 255-delivered plus 1-drop ledger before any FEB-link host-disk claim.",
    ),
    (
        "Host DMA buffer",
        "BLOCKED",
        "/dev/mudaq0 must receive SWB DMA data from the OPQ/event-builder chain.",
        "PCIe recovery passed and /dev/mudaq0 is present after SWB programming. Mu3e online DMA tools are deprecated as evidence; swb_dmatest, rw, MIDAS, and libmudaq-backed utilities are reference-only. The new tools/phase6_swb_dma_probe path directly mmaps /dev/mudaq0 and /dev/mudaq0_dmabuf, captures raw RW/RO registers and counter sweeps before cleanup, and writes dma_words.bin plus JSON/Markdown summaries.",
        "Use only repo-owned direct-MMIO tools under tools/ for closure captures. First make SWB datagen produce nonzero DMA words; then capture FEB-link runs with the same manifest and offline reducer.",
    ),
    (
        "Disk/offline timestamp check",
        "BLOCKED",
        "Mu3e Demo OPQ: every decoded bunch must contain 255 delivered hits with identical TS, OPQ must account exactly one dropped hit from the 256-hit source cluster, and adjacent bunch TS spacing must match 100 kHz.",
        "No valid disk artifact has been produced yet for the 256-channel, 100 kHz/channel Mu3e Demo OPQ requirement. The Phase-6 DMA reducer now decodes headers, trailers, frame counters, timestamp deltas, subheader distributions, and hit-count histograms from either memory_content.txt or the repo-owned probe's dma_words.bin once nonzero data exists.",
        "Run the reducer on the first post-SWB-input DMA artifact and require 255-delivered plus one OPQ-accounted drop before disk closure.",
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
    if result in {"PASS", "PASS_SC", "PASS_DIAG", "PASS_WITH_METHOD_NOTE", "PASS_DEBUG_ONLY"}:
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
    phase6_report = REPORT_DIR / "phase6_timingclosed_cycle1_20260430.md"
    phase6_signaltap_report = REPORT_DIR / "phase6_lower_mts_ring_signaltap_20260430.md"
    phase6_vcd_summary = REPORT_DIR / "phase6_lower_mts_ring_vcd_summary_20260430.md"
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
      Older Phase-5 evidence showed single-lane delay could be made clean, but
      the timing-closed Phase-6 rerun with explicit SMB3/SMB5 XML reload moved
      the live blocker earlier: even the lower <code>lanes5+6</code>
      one-channel pair now trips MTS/ring input errors. The lower-MTS/ring
      SignalTap checkpoint localizes the visible error sideband to MTS1 before
      hit_stack1/ring sees the reject. No FEB/SWB host-disk
      Mu3e Demo OPQ, 100 kHz end-to-end claim is valid yet. Under the active
      <code>N_HIT=255</code> profile, a 256-hit source cluster must deliver
      255 hits and account exactly one OPQ hit drop. The SWB OPQ image now has
      timing-clean programming and host-visible SC replies, so SWB SC return is
      no longer the first blocker.
    </div>

    <h2>Current Read</h2>
    <p>
      The strongest blocker is not the deprecated injector path or XML mapping.
      The active injector is the Phase-5 <code>mutrig_injector_0</code> path and
      the XML split is SMB3 for ASICs 0..3 and SMB5 for ASICs 4..7. The lower
      side fails because two real lower streams together make MTS assert
      <code>tserr</code> before the ring stage; the ring
      <code>inerr_count</code> is therefore a real timestamp-delay failure,
      not a ring-local decode bug.
    </p>
    <p>
      The latest fixed Phase-6 cycle explicitly loaded
      <code>config_smb3_tdc.txt</code> and <code>config_smb5_tdc.txt</code>.
      P6B010 configured ASIC5/6 one-channel mode successfully but failed as
      <code>unexpected_fail</code>. The bounded cycle measured
      <code>ring_inerr_delta=535108</code>; the later SignalTap rerun measured
      <code>ring_inerr_delta=535373</code>, <code>mts_discard_delta=0</code>,
      and LVDS error/DPA deltas were zero. P6B020 full-channel remains the
      expected fail, and P6E010 pulse-high 3 is clean but underfilled. Reduced
      evidence:
      <a href="{esc(rel(phase6_report))}">{esc(phase6_report.name)}</a>.
    </p>
    <p>
      The follow-up lower ASIC5/6 sweep distinguishes lane-local health from
      cross-ASIC failure. ASIC5/lane5 and ASIC6/lane6 each pass one-channel
      pulse-high 4/5 runs alone with zero ring input errors. The two real lanes
      together fail at pulse-high 4/5, and ASIC6 <code>ext_trig_offset</code>
      values <code>0..15</code> all fail. A two-lane emulator reference through
      the same lower MTS/ring path passes after 50 ms post-sync/pre-inject
      settle. Reduced sweep evidence:
      <a href="{esc(rel(REPORT_DIR / 'phase6_lower56_cross_asic_sweep_20260430.md'))}">phase6_lower56_cross_asic_sweep_20260430.md</a>.
    </p>
    <p>
      The lane6/7 zero-point check makes the same conclusion sharper. ASIC6 and
      ASIC7 were explicitly configured with <code>vncnt=0</code>,
      <code>vnvcodelay=0</code>, and <code>vnhitlogic=0</code>. Each ASIC still
      passes alone at 100 kHz with zero ring input errors and zero LVDS/DPA
      deltas, so this zero setting is not a hard no-hit reset point in the
      current packed configuration. The paired lane6+7 run fails with
      <code>ring_inerr_delta=826978</code> while LVDS/DPA deltas remain zero,
      matching the lower multi-ASIC timestamp/order blocker rather than a
      lane-local PLL-lock problem. Reduced lane6/7 evidence:
      <a href="{esc(rel(REPORT_DIR / 'phase6_lane67_zero_point_20260430.md'))}">phase6_lane67_zero_point_20260430.md</a>.
    </p>
    <p>
      The first good-ASIC frame-boundary capture is useful but not yet
      closure-grade. ASIC6/lane6 at the zero-VCO point passes a 100 kHz
      active-window run with zero MTS discards, zero ring input errors, zero
      histogram drops, zero frame CRC errors, and zero LVDS/DPA deltas. The
      boundary SignalTap capture records a legal FEB <code>hit_type3</code>
      frame with nonzero subheader/hit content, but the same 1k-sample window
      does not catch the matching nonempty RBCAM <code>hit_type2</code> beat.
      That is an observability alignment gap, not an end-to-end closure claim.
      Evidence:
      <a href="{esc(rel(REPORT_DIR / 'phase6_frame_boundary_lane6_vco000_100k_active_inject_20260430.md'))}">phase6_frame_boundary_lane6_vco000_100k_active_inject_20260430.md</a>
      and
      <a href="{esc(rel(REPORT_DIR / 'phase6_frame_boundary_lane6_vco000_100k_active_vcd_summary_20260430.md'))}">phase6_frame_boundary_lane6_vco000_100k_active_vcd_summary_20260430.md</a>.
    </p>
    <p>
      The lower-MTS/ring SignalTap debug image programmed with checksum
      <code>0x16B6BF30</code> and SOF SHA256
      <code>080f92844f868d33e142ce6e576911b728f9364fadd1d9c2824addd7d1cff2b9</code>.
      It is an Arria V debug-only image: setup WNS is <code>-0.086 ns</code>
      on <code>transceiver_pll_clock[0]</code>, within the clarified
      about-200 ps FEB debug tolerance, while SWB Arria 10 still requires clean
      timing closure. The VCD shows <code>mts1.aso_hit_type1_error</code> and
      <code>hit_stack1.hit_type_1_error[0]</code> both first high at
      <code>128500 ps</code>. Reduced SignalTap evidence:
      <a href="{esc(rel(phase6_signaltap_report))}">{esc(phase6_signaltap_report.name)}</a>
      and <a href="{esc(rel(phase6_vcd_summary))}">{esc(phase6_vcd_summary.name)}</a>.
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
      SWB live preflight was superseded after the timing fix in online_sc
      <code>11eada541</code>. The new SOF programmed with checksum
      <code>0x31A704E1</code>, PCIe recovery restored <code>/dev/mudaq0</code>,
      and host-visible SC link-2 reads now return in roughly 68-69 us, including
      <code>0x0C000 -> 0x52434D48</code>. That clears the old SC reply blocker.
      The Mu3e online DMA tools are now deprecated for closure evidence:
      <code>swb_dmatest</code>, <code>rw</code>, MIDAS, and libmudaq-backed
      utilities are reference-only. The repo-owned
      <code>tools/phase6_swb_dma_probe/phase6_swb_dma_probe.py</code> directly
      maps <code>/dev/mudaq0</code> and <code>/dev/mudaq0_dmabuf</code>, records
      raw RW/RO registers plus SWB counter sweeps before cleanup, and writes
      <code>dma_words.bin</code> for offline reduction.
    </p>
    <p>
      That direct probe found the current SWB DMA blocker before FEB-link
      closure: generic time/stream datagen, minimal datagen, forced-DMA
      datagen, and TB-style stream datagen all produced <code>no_dma_words</code>
      while mux/event-builder counters stayed zero. The active SWB image already
      contains the OPQ/MuSiP path and nonzero DMA address registers; the bug is
      upstream of DMA address programming. Source inspection showed
      <code>data_generator_a10</code> leaves generated <code>link32_t</code>
      records idle, so <code>musip_mux_4_1</code> rejects them. The online_sc
      source patch decodes <code>gen_link.data/gen_link.datak</code> through
      <code>work.mu3e.to_link(...)</code> before the mux. Quartus
      <code>make flow_map</code> now passes for that patch with 0 errors and 182
      warnings. OPQ hardware counters, host DMA, and disk closure still cannot
      count as end-to-end evidence until the patched SWB image is fully compiled,
      reflashed, and the repo-owned probe records nonzero DMA words.
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
