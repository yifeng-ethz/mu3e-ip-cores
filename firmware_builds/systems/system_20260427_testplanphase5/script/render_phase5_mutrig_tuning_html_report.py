#!/usr/bin/env python3
"""Render the live Phase-5 MuTRiG tuning evidence into one HTML page."""

from __future__ import annotations

import datetime as dt
import csv
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
HIST_ARTIFACT_DIR = REPORT_DIR / "assets" / "phase5_mutrig_tuning_20260430"
HIST_ARTIFACT_MANIFEST = HIST_ARTIFACT_DIR / "phase5_histogram_artifacts_manifest.json"
HIGHCYCLE_ARTIFACT_DIR = REPORT_DIR / "assets" / "phase6_highcycle_rate_sweep_20260501"
HIGHCYCLE_STATS = HIGHCYCLE_ARTIFACT_DIR / "phase6_highcycle_rate_sweep_stats.tsv"
MASK_RESPONSE_ARTIFACT_DIR = REPORT_DIR / "assets" / "phase6_mask_response_seed20260501"
MASK_RESPONSE_STATS = MASK_RESPONSE_ARTIFACT_DIR / "phase6_mask_response_bar_stats.tsv"
MASK_RESPONSE_RAW_CHECK = REPORT_DIR / "phase6_mask_response_raw_mask_check_seed20260501.tsv"
HEADER_DELAY_ARTIFACT_DIR = REPORT_DIR / "assets" / "phase6_header_delay_asic_20260501_hdrch_mts1pct"
HEADER_DELAY_STATS = HEADER_DELAY_ARTIFACT_DIR / "phase6_header_delay_asic_stats.tsv"
REQUIRED_MONITOR_MS = 1000


EVIDENCE = [
    (
        "Restore full tuned baseline",
        "Config",
        "phase5_mutrig_restore_full32_tuned_baseline_20260430e.json",
        "All eight ASICs reloaded full-channel with the single-lane-clean PLL overrides.",
    ),
    (
        "All-real lanes 1 s rate monitor",
        "Rate",
        "phase5_live_allreal_rate_1s_20260430.json",
        "Fresh 1 s all-real-lane rate run: LVDS error/DPA deltas are zero and last-interval histogram total is nonzero, but MTS/ring errors remain and slow SC bin readback returned zero bins, so this is blocker evidence rather than a plotted-artifact pass.",
    ),
    (
        "Emulator r53 1 s all-channel rate bins",
        "Rate plot",
        "phase5_rate_per_channel_1s_20260501_allchan100k_emulator_periodic_r53.json",
        "First JTAG/toolkit-style rate-bin capture with both histogram ingress bridges forced pre-RBCAM and all 256 bins nonzero. Histogram drops, MTS discards, and ring input timestamp errors are zero, but RBCAM overwrite/cache counters and rate uniformity are not clean enough for closure.",
    ),
    (
        "Emulator all lanes 10 kHz 1 s",
        "Phase6 emu",
        "phase6_histv7_emulator_all_rate10k_1s_lowerfix_20260501.json",
        "Freshly compiled/programmed full-FEB image sees all eight emulator lanes; physical mask expectation is eight-lane rate, zero histogram drops, zero MTS/ring errors.",
    ),
    (
        "Emulator upper-only 10 kHz 1 s",
        "Phase6 emu",
        "phase6_histv7_emulator_upper_rate10k_1s_lowerfix_20260501.json",
        "Upper-side mask control sees four-lane rate only.",
    ),
    (
        "Emulator lower-only 10 kHz 1 s",
        "Phase6 emu",
        "phase6_histv7_emulator_lower_rate10k_1s_lowerfix_20260501.json",
        "Lower-side mask control now sees four-lane rate, proving the lower histogram bridge is live in the programmed image.",
    ),
    (
        "Emulator all lanes 100 kHz 1 s",
        "Phase6 emu",
        "phase6_histv7_emulator_all_rate100k_1s_lowerfix_20260501.json",
        "All eight emulator lanes pass the 100 kHz/channel smoke with zero histogram drops and zero MTS/ring rejects.",
    ),
    (
        "Emulator dual-MTS delay 100 kHz 1 s",
        "Phase6 emu",
        "phase6_histv7_emulator_all_delay100k_1s_lowerfix_20260501.json",
        "Delay-profile smoke exercises both upper and lower MTS debug sources; this is a wiring guard, not a real-MuTRiG PLL lock claim.",
    ),
    (
        "ASIC5 head-sync default, lapse on",
        "Header",
        "phase6_headsync_lane5_default_jtag_nodisplay_20260501.json",
        "JTAG 256-bin delay read shows a non-delta ASIC5 response under production MTS lapse: peak 44.914% with six nonzero bins.",
    ),
    (
        "ASIC5 head-sync cnt52/vcd18, lapse on",
        "Header",
        "phase6_headsync_lane5_cnt52_vcd18_mtslat2000_jtag_nodisplay_20260501.json",
        "ASIC5 physical tuning improves the shape but production MTS lapse still leaves a two-bin 79.171%/20.829% split.",
    ),
    (
        "ASIC5 head-sync cnt52/vcd18, bypass lapse",
        "Header diag",
        "phase6_headsync_lane5_cnt52_vcd18_bypasslapse_jtag_nodisplay_20260501.json",
        "Diagnostic-only bypass-lapse run collapses ASIC5 to one delay bin, separating the physical TDC/LVDS response from the MTS lapse transform.",
    ),
    (
        "ASIC6 head-sync default, lapse on",
        "Header",
        "phase6_headsync_lane6_default_jtag_nodisplay_20260501.json",
        "ASIC6 default production-lapse control is a single-bin delta at 904 cycles with zero LVDS error/DPA deltas.",
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
        "Phase-6 continued bounded cycle P6B006",
        "Phase6",
        "phase6_long_runs/20260430_live_continued_cycle1/cases/cycle00000_P6B006.json",
        "Fresh ASIC5/lane5 one-channel control passes with zero ring input errors.",
    ),
    (
        "Phase-6 continued bounded cycle P6B007",
        "Phase6",
        "phase6_long_runs/20260430_live_continued_cycle1/cases/cycle00000_P6B007.json",
        "Fresh ASIC6/lane6 one-channel control passes with zero ring input errors.",
    ),
    (
        "Phase-6 continued bounded cycle P6B010",
        "Phase6",
        "phase6_long_runs/20260430_live_continued_cycle1/cases/cycle00000_P6B010.json",
        "Fresh ASIC5+6 one-channel pair still fails before SWB with ring input errors.",
    ),
    (
        "Lower lanes 5+6 one-channel latency 2000",
        "Latency",
        "phase6_probe_lower56_ch1_latency2000_pulse4_20260430.json",
        "Nominal 0..2000-cycle expected-latency gate fails for the two-real-ASIC lower pair.",
    ),
    (
        "Lower lanes 5+6 one-channel latency 4000",
        "Latency",
        "phase6_probe_lower56_ch1_latency4000_pulse4_20260430.json",
        "Opening the expected-latency gate to 4000 cycles does not clear the lower-pair failure.",
    ),
    (
        "Lower lanes 5+6 one-channel latency 65535",
        "Latency",
        "phase6_probe_lower56_ch1_latency65535_pulse4_20260430.json",
        "Even an effectively wide positive-latency gate leaves ring input errors, pointing away from a small positive delay tail.",
    ),
    (
        "Lower lanes 5+6 header mode channel 5",
        "Header",
        "phase6_probe_lower56_ch1_header_ch5_hdelay100_pulse4_20260430.json",
        "Header-synchronous injection on lower header channel 5 still fails for the real pair.",
    ),
    (
        "Lower lanes 5+6 header mode channel 6",
        "Header",
        "phase6_probe_lower56_ch1_header_ch6_hdelay100_pulse4_20260430.json",
        "Header-synchronous injection on lower header channel 6 still fails for the real pair.",
    ),
    (
        "Lane 5 header mode control",
        "Header",
        "phase6_probe_lane5_ch1_header_hdelay100_pulse4_20260430.json",
        "ASIC5/lane5 alone passes the same header-synchronous mode, so the mode itself is not the blocker.",
    ),
    (
        "Lane 6 header mode control",
        "Header",
        "phase6_probe_lane6_ch1_header_hdelay100_pulse4_20260430.json",
        "ASIC6/lane6 alone passes the same header-synchronous mode, so the pair failure is cross-ASIC.",
    ),
    (
        "Lane 6 zero VCO point",
        "Phase6",
        "phase6_lane6_vco000_pulse4_100k_20260430_192903.json",
        "Invalidated: vnvcodelay=0 should produce no TDC-injection hits; rerun with nonzero ASIC-specific PLL settings and RUN_PREP.",
    ),
    (
        "Lane 6 FEB frame boundary",
        "Phase6",
        "phase6_frame_boundary_lane6_vco000_100k_active_inject_20260430.json",
        "Invalidated as tuning evidence by the vco000 label; keep only as a frame-format debug example until rerun with locked nonzero PLL settings.",
    ),
    (
        "Lane 7 zero VCO point",
        "Phase6",
        "phase6_lane7_vco000_pulse4_100k_20260430_193008.json",
        "Invalidated: zero vcodelay is the no-hit control, not a lock point.",
    ),
    (
        "Lanes 6+7 zero VCO pair",
        "Phase6",
        "phase6_lane67_vco000_pulse4_100k_20260430_193112.json",
        "Invalidated for PLL/timestamp conclusions until rerun from ASIC-specific nonzero defaults/restores after RUN_PREP.",
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
        "The histogram 26.1.8 FEB image compiled at 10:17 on 2026-05-01, programmed at 10:21 with checksum 0x13DD5EC5, and responded with packaged injector UID 0x4D494E4A. After explicit all-ASIC reload and CML 0-8-0 flush, the 1 s high-cycle rate sweep shows the physical threshold: ph1/ph2 silent, ph3 underfilled, ph5/ph6/ph7 near 25.55 Mhit/s with all 256 channels populated, ph8 begins overcount spikes, and ph9+ overfills. The ph8+ shape is consistent with TDC injection-line ringing and second rising-edge pickup on some channels, so rates can approach 2x or land between 1x and 2x. The best rate artifacts are ph6/ph7 around 99.8 kHz/channel with CV about 0.006, but the same runs still classify as MTS-discard failures before full FEB output closure. Earlier lower-pair evidence still applies: ASIC5/lane5 and ASIC6/lane6 pass alone, but the two real lanes fail together; expected-latency sweeps, header-sync pair controls, and ext_trig_offset scans do not clear it. SignalTap shows mts1.aso_hit_type1_error and hit_stack1.hit_type_1_error[0] rising in the same exported VCD window for the bad lower pair.",
        "Use ph6 or ph7 as the current rate-mode pulse-width starting point, then clear the MTS-discard/RBCAM boundary with header-delay delta plots and same-window RBCAM/FEB-frame captures before SWB/DMA disk closure.",
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
        "PARTIAL_DMA",
        "Merged hit words must drive the existing SWB DMA outputs with OPQ accounting matching the active hit-limit profile.",
        "packet_scheduler ed249da carries the 26.5 Mu3e Demo signoff merge; the underlying 25e204c UVM case proves N_HIT=255 delivers 255 hits and records exactly one drop. The online_sc fixed4 image compiled timing-clean, programmed checksum 0x31A72852, and recovered /dev/mudaq0. Three fresh 10 s repo-owned stream-datagen runs classify raw host DMA as dma_payload_nonzero with 2048 nonzero words, 1024 nonpadding words, and 256 event-builder payload words each. First payload words differ across runs: 0x00088A0C, 0x0008818F, and 0x0008894F, so this is not stale-buffer reuse. The old frame reducer correctly reports raw_payload_no_legacy_frames for this musip_event_builder payload.",
        "Decode the active MuSiP/OPQ payload contract, clear the still-empty time-datagen path, then run real FEB-link captures and require 255 delivered hits plus one OPQ-accounted drop per 256-hit bunch before any FEB-link host-disk claim.",
    ),
    (
        "Host DMA buffer",
        "PARTIAL_RAW_DMA",
        "/dev/mudaq0 must receive SWB DMA data from the OPQ/event-builder chain.",
        "PCIe recovery passed and /dev/mudaq0 plus /dev/mudaq0_dmabuf are present after the fixed4 SWB programming. Mu3e online software is deprecated as Phase-6 evidence; swb_dmatest, rw, MIDAS, libmudaq-backed utilities, and production cleanup flows are reference-only. The tools/phase6_swb_dma_probe path directly mmaps the devices, captures raw RW/RO registers and counter sweeps before cleanup, and now distinguishes raw 256-bit payload DMA from legacy frame decode.",
        "Use only repo-owned direct-MMIO tools under tools/ for closure captures. If an online utility disagrees with raw registers, trust the repo-owned probe and hardware evidence. The next host-buffer gate is a real FEB-link run with persistent disk artifact and offline timestamp/hit-count reduction.",
    ),
    (
        "Disk/offline timestamp check",
        "BLOCKED",
        "Mu3e Demo OPQ: every decoded bunch must contain 255 delivered hits with identical TS, OPQ must account exactly one dropped hit from the 256-hit source cluster, and adjacent bunch TS spacing must match 100 kHz.",
        "No valid disk artifact has been produced yet for the 256-channel, 100 kHz/channel Mu3e Demo OPQ requirement. The Phase-6 DMA reducer now reports raw_payload_no_legacy_frames when host DMA contains nonpadding musip_event_builder payload without old FEB/SWB frame headers. Three 10 s stream-datagen captures prove the raw SWB DMA buffer changes per run, but they are controls only and do not contain decoded real MuTRiG FEB-link bunches.",
        "Extend the reducer for the active MuSiP payload or capture legacy FEB-link frames, then require 255 delivered same-timestamp hits plus one OPQ-accounted drop before disk closure.",
    ),
]


ZERO_VCODELAY_FILES = {
    "phase6_lane6_vco000_pulse4_100k_20260430_192903.json",
    "phase6_frame_boundary_lane6_vco000_100k_active_inject_20260430.json",
    "phase6_lane7_vco000_pulse4_100k_20260430_193008.json",
    "phase6_lane67_vco000_pulse4_100k_20260430_193112.json",
}


TUNING_LEDGER = [
    (0, "SMB3", "48/20/30", "48/20/40", "-", "phase5_mutrig_restore_full32_tuned_baseline_20260430e.json"),
    (1, "SMB3", "43/30/30", "43/30/30", "-", "phase5_mutrig_restore_full32_tuned_baseline_20260430e.json"),
    (2, "SMB3", "45/35/20", "40/30/30", "-", "phase5_mutrig_restore_full32_tuned_baseline_20260430e.json"),
    (3, "SMB3", "41/10/20", "35/12/25", "-", "phase5_mutrig_restore_full32_tuned_baseline_20260430e.json"),
    (4, "SMB5", "43/15/20", "43/15/20", "-", "phase5_mutrig_restore_full32_tuned_baseline_20260430e.json"),
    (5, "SMB5", "42/20/25", "52/18/25", "bypass-lapse delta; production-lapse sideband", "phase6_headsync_lane5_cnt52_vcd18_bypasslapse_jtag_nodisplay_20260501.csv"),
    (6, "SMB5", "37/27/15", "37/27/15", "default production-lapse delta", "phase6_headsync_lane6_default_jtag_nodisplay_20260501.csv"),
    (7, "SMB5", "40/20/25", "30/14/40", "-", "phase5_mutrig_restore_full32_tuned_baseline_20260430e.json"),
]

HEADSYNC_NOTES = {
    0: "all-eight header-sync plot present; rbCAM drop proxy is 0.000000%",
    1: "all-eight header-sync plot present; rbCAM drop proxy is 0.017684% including underflow",
    2: "all-eight header-sync plot present; rbCAM drop proxy is 0.509355% including underflow",
    3: "all-eight header-sync plot present; rbCAM drop proxy is 0.343672% including underflow",
    4: "all-eight header-sync plot present; rbCAM drop proxy is 0.000000%",
    5: "comparison plot shows ASIC5 physical delta only when MTS lapse is bypassed; production lapse still splits 79/21",
    6: "all-eight header-sync plot is delta-like but rbCAM drop proxy is 1.158235%; tune/check sideband",
    7: "all-eight header-sync plot present; rbCAM drop proxy is 0.838351%; MTS discard is a sub-1% fine-counter caveat",
}


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


def fmt_rate(value: Any) -> str:
    if value is None:
        return "-"
    try:
        rate = float(value)
    except (TypeError, ValueError):
        return esc(value)
    if abs(rate) >= 1_000_000:
        return f"{rate / 1_000_000:.3f} M/s"
    if abs(rate) >= 1_000:
        return f"{rate / 1_000:.3f} k/s"
    return f"{rate:.3f} /s"


def fmt_count_rate(count: Any, rate: Any) -> str:
    return f"{fmt_int(count)}<div class=\"rate\">{fmt_rate(rate)}</div>"


def monitor_status(duration_ms: Any) -> tuple[str, str]:
    try:
        duration = int(duration_ms)
    except (TypeError, ValueError):
        return "unknown", "missing"
    if duration >= REQUIRED_MONITOR_MS:
        return f"{duration} ms", "pass"
    return f"{duration} ms; rerun 1 s", "fail"


def float_or_none(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def load_json(name: str) -> dict[str, Any] | None:
    path = REPORT_DIR / name
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def load_json_path(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def first_case(cases: Any) -> dict[str, Any] | None:
    if isinstance(cases, list) and cases:
        return cases[0]
    if isinstance(cases, dict):
        return cases
    return None


def counter_rate(summary: dict[str, Any], name: str, delta_name: str | None = None) -> float | None:
    rates = summary.get("counter_rates_hz", {})
    if isinstance(rates, dict) and name in rates:
        try:
            return float(rates[name])
        except (TypeError, ValueError):
            return None
    elapsed = summary.get("counter_rate_elapsed_s")
    if elapsed is None:
        return None
    try:
        elapsed_f = float(elapsed)
    except (TypeError, ValueError):
        return None
    if elapsed_f <= 0:
        return None
    field = delta_name or f"{name}_delta"
    try:
        return float(summary.get(field, 0) or 0) / elapsed_f
    except (TypeError, ValueError):
        return None


def lvds_text(case: dict[str, Any]) -> str:
    lvds = case.get("lvds_summary", {})
    if not isinstance(lvds, dict) or not lvds:
        return "not captured"
    if not lvds.get("captured"):
        return "snapshot missing"
    err_total = int(lvds.get("error_delta_total", 0) or 0)
    dpa_total = int(lvds.get("dpa_unlock_delta_total", 0) or 0)
    err_lanes = lvds.get("error_delta_lanes", [])
    dpa_lanes = lvds.get("dpa_unlock_delta_lanes", [])
    lane_go = int(lvds.get("lane_go_after", case.get("lane_go", 0)) or 0)
    active = [lane for lane in range(8) if lane_go & (1 << lane)]
    prefix = "OK" if err_total == 0 and dpa_total == 0 else "ERR"
    details = f"errΔ={err_total}, dpaΔ={dpa_total}, active={active}"
    if err_lanes or dpa_lanes:
        details += f", err_lanes={err_lanes}, dpa_lanes={dpa_lanes}"
    return f"{prefix}: {details}"


def mts_config_text(case: dict[str, Any]) -> str:
    overrides = case.get("debug_overrides", {})
    if not isinstance(overrides, dict):
        overrides = {}
    args = case.get("args", {})
    if not isinstance(args, dict):
        args = {}
    expected = overrides.get("mts_expected_latency", args.get("mts_expected_latency", "keep"))
    lookback = overrides.get("mts_overflow_lookback", args.get("mts_overflow_lookback", "keep"))
    bypass = overrides.get("mts_bypass_lapse", args.get("mts_bypass_lapse", "keep"))
    drop = overrides.get("mts_drop_delay_error", args.get("mts_drop_delay_error", "keep"))
    field = overrides.get("mts_delay_ts_field", args.get("mts_delay_ts_field", "keep"))
    return f"lat={expected}; lookback={lookback}; lapse={bypass}; drop={drop}; ts={field}"


def case_stage_summary(case: dict[str, Any]) -> dict[str, Any]:
    summary = case.get("summary", {})
    duration_ms = case.get("duration_ms")
    rate_elapsed_s = float_or_none(summary.get("counter_rate_elapsed_s"))
    rbcam_reject = (
        int(summary.get("ring_inerr_delta", 0) or 0)
        + int(summary.get("ring_overwrite_delta", 0) or 0)
    )
    return {
        "result": "PASS" if summary.get("pass") else "FAIL",
        "class": summary.get("phase5_classification", summary.get("classification", "-")),
        "scope": f"lvds=0x{int(case.get('lane_go', 0)):03X}",
        "active": f"emu=0x{int(case.get('active_lanes_mask', 0)):02X}",
        "mts_cfg": mts_config_text(case),
        "pulse": case.get("injector_config", {}).get("pulse_high_cycles"),
        "duration": duration_ms,
        "window_s": summary.get("counter_rate_elapsed_s"),
        "hist_in": summary.get("hist_total_delta"),
        "hist_drop": summary.get("hist_drop_delta"),
        "hist_in_rate": counter_rate(summary, "hist_total", "hist_total_delta"),
        "hist_drop_rate": counter_rate(summary, "hist_drop", "hist_drop_delta"),
        "mts_in": summary.get("mts_total_delta"),
        "mts_drop": summary.get("mts_discard_delta"),
        "mts_in_rate": counter_rate(summary, "mts_total", "mts_total_delta"),
        "mts_drop_rate": counter_rate(summary, "mts_discard", "mts_discard_delta"),
        "rbcam_in": summary.get("ring_push_delta"),
        "rbcam_out": summary.get("ring_pop_delta"),
        "rbcam_reject": rbcam_reject,
        "rbcam_cache_miss": summary.get("ring_cache_miss_delta"),
        "rbcam_in_rate": counter_rate(summary, "ring_push", "ring_push_delta"),
        "rbcam_out_rate": counter_rate(summary, "ring_pop", "ring_pop_delta"),
        "rbcam_reject_rate": None if not rate_elapsed_s else rbcam_reject / rate_elapsed_s,
        "feb_in": summary.get("frame_actual_delta"),
        "feb_drop": summary.get("frame_missing_delta"),
        "feb_in_rate": counter_rate(summary, "frame_actual", "frame_actual_delta"),
        "feb_drop_rate": counter_rate(summary, "frame_missing", "frame_missing_delta"),
        "lvds": lvds_text(case),
    }


def summarize_case(case: dict[str, Any]) -> dict[str, Any]:
    return case_stage_summary(case)


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
    elapsed = sum(
        float(record.get("summary", {}).get("counter_rate_elapsed_s", 0.0) or 0.0)
        for record in records
    )
    def aggregate_rate(field: str) -> float | None:
        if elapsed <= 0:
            return None
        return total(field) / elapsed

    rbcam_reject = total("ring_inerr_delta") + total("ring_overwrite_delta")
    return {
        "result": "PASS" if not failures else "FAIL",
        "class": f"{len(records) - len(failures)} / {len(records)} pass",
        "scope": f"lvds=0x{lane_mask:03X}",
        "active": f"emu=0x{active_mask:02X}",
        "mts_cfg": "aggregate; inspect child JSON",
        "pulse": pulse,
        "duration": duration,
        "window_s": elapsed if elapsed > 0 else None,
        "hist_in": total("hist_total_delta"),
        "hist_drop": total("hist_drop_delta"),
        "hist_in_rate": aggregate_rate("hist_total_delta"),
        "hist_drop_rate": aggregate_rate("hist_drop_delta"),
        "mts_in": total("mts_total_delta"),
        "mts_drop": total("mts_discard_delta"),
        "mts_in_rate": aggregate_rate("mts_total_delta"),
        "mts_drop_rate": aggregate_rate("mts_discard_delta"),
        "rbcam_in": total("ring_push_delta"),
        "rbcam_out": total("ring_pop_delta"),
        "rbcam_reject": rbcam_reject,
        "rbcam_cache_miss": total("ring_cache_miss_delta"),
        "rbcam_in_rate": aggregate_rate("ring_push_delta"),
        "rbcam_out_rate": aggregate_rate("ring_pop_delta"),
        "rbcam_reject_rate": None if elapsed <= 0 else rbcam_reject / elapsed,
        "feb_in": total("frame_actual_delta"),
        "feb_drop": total("frame_missing_delta"),
        "feb_in_rate": aggregate_rate("frame_actual_delta"),
        "feb_drop_rate": aggregate_rate("frame_missing_delta"),
        "lvds": "aggregate; inspect child JSON for lane table",
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
            "mts_cfg": "-",
            "pulse": "-",
            "duration": "-",
            "window_s": None,
            "hist_in": "-",
            "hist_drop": "-",
            "hist_in_rate": None,
            "hist_drop_rate": None,
            "mts_in": "-",
            "mts_drop": "-",
            "mts_in_rate": None,
            "mts_drop_rate": None,
            "rbcam_in": "-",
            "rbcam_out": "-",
            "rbcam_reject": "-",
            "rbcam_cache_miss": "-",
            "rbcam_in_rate": None,
            "rbcam_out_rate": None,
            "rbcam_reject_rate": None,
            "feb_in": "-",
            "feb_drop": "-",
            "feb_in_rate": None,
            "feb_drop_rate": None,
            "lvds": "-",
        }
    return {"result": "UNKNOWN"}


def badge(result: str) -> str:
    if result in {"PASS", "PASS_SC", "PASS_DIAG", "PASS_WITH_METHOD_NOTE", "PASS_DEBUG_ONLY"}:
        klass = "pass"
    elif result.startswith("PARTIAL"):
        klass = "warn"
    elif result in {"PENDING", "IN_PROGRESS", "MISSING"}:
        klass = "missing"
    else:
        klass = "fail"
    return f'<span class="badge {klass}">{esc(result)}</span>'


def invalidate_zero_vcodelay(filename: str, summary: dict[str, Any]) -> dict[str, Any]:
    if filename not in ZERO_VCODELAY_FILES:
        return summary
    updated = dict(summary)
    updated["result"] = "INVALID"
    updated["class"] = "zero-vcodelay no-hit control; rerun required"
    return updated


def tuning_rows() -> str:
    rows = []
    for asic, smb, default, restore, diagnostic, evidence in TUNING_LEDGER:
        path = REPORT_DIR / evidence
        link = f'<a href="{esc(rel(path))}">{esc(evidence)}</a>' if path.exists() else esc(evidence)
        headsync_note = HEADSYNC_NOTES.get(asic, "pending per-ASIC head-sync plot")
        rows.append(
            "<tr>"
            f"<td>{asic}</td>"
            f"<td>{esc(smb)}</td>"
            f"<td><code>{esc(default)}</code></td>"
            f"<td><code>{esc(restore)}</code></td>"
            f"<td>{esc(diagnostic)}</td>"
            f"<td>{link}</td>"
            f"<td>{esc(headsync_note)}</td>"
            "</tr>"
        )
    return "\n".join(rows)


def hist_artifact_manifest() -> dict[str, Any]:
    return load_json_path(HIST_ARTIFACT_MANIFEST) or {"artifacts": {}}


def artifact_status_rows() -> str:
    manifest = hist_artifact_manifest()
    artifacts = manifest.get("artifacts", {})
    required = [
        ("rate_per_channel", "1 s 256-bin rate histogram", "Precise per-channel/per-ASIC rate evidence from histogram bins."),
        ("header_delay", "Header-sync delay histogram", "Passing handle: one dominant delay bin, normally >=90% peak fraction."),
        ("header_delay_comparison", "Header-sync delay A/B comparison", "Physical-response check across production-lapse, bypass-lapse, and lane controls."),
    ]
    rows = []
    for key, title, contract in required:
        artifact = artifacts.get(key, {"status": "missing", "reason": "not in manifest"})
        status = artifact.get("status", "missing")
        if key.startswith("header_delay") and status in {"present", "anomaly"}:
            status_label = "INVALID"
            contract = "Invalidated: this artifact was captured from MTS ts_delta, not debug_ts latency."
        elif status == "present":
            status_label = "PASS"
        elif status == "anomaly":
            status_label = "ANOMALY"
        else:
            status_label = "MISSING"
        path_text = artifact.get("path")
        if path_text:
            path = Path(path_text)
            if not path.is_absolute():
                path = HIST_ARTIFACT_DIR / path
            link = f'<a href="{esc(rel(path))}">{esc(path.name)}</a>' if path.exists() else esc(path.name)
        else:
            link = "-"
        note_parts = []
        if artifact.get("source"):
            note_parts.append(f"source={Path(str(artifact['source'])).name}")
        if artifact.get("total_hits") is not None:
            note_parts.append(f"total={fmt_int(artifact.get('total_hits'))}")
        if artifact.get("nonzero_bins") is not None:
            note_parts.append(f"nonzero_bins={fmt_int(artifact.get('nonzero_bins'))}")
        if artifact.get("active_asics") is not None:
            note_parts.append(f"active_asics={fmt_int(artifact.get('active_asics'))}")
        if artifact.get("cv_nonzero_rate") is not None:
            note_parts.append(f"rate_cv={float(artifact.get('cv_nonzero_rate')):.3f}")
        if artifact.get("rate_uniformity_pass") is not None:
            note_parts.append(f"uniformity={'pass' if artifact.get('rate_uniformity_pass') else 'fail'}")
        if artifact.get("peak_fraction") is not None:
            note_parts.append(f"peak={float(artifact.get('peak_fraction')):.3%}")
        if artifact.get("toolkit_preset_id"):
            note_parts.append(f"preset={artifact.get('toolkit_preset_id')}")
        if artifact.get("visual_checkpoint"):
            note_parts.append(str(artifact["visual_checkpoint"]))
        if artifact.get("reason"):
            note_parts.append(str(artifact["reason"]))
        rows.append(
            "<tr>"
            f"<td>{esc(title)}</td>"
            f"<td>{badge(status_label)}</td>"
            f"<td>{esc(contract)}<div class=\"note\">{esc('; '.join(note_parts) if note_parts else '-')}</div></td>"
            f"<td>{link}</td>"
            "</tr>"
        )
    return "\n".join(rows)


def artifact_figures() -> str:
    manifest = hist_artifact_manifest()
    figures = []
    for artifact in manifest.get("artifacts", {}).values():
        if artifact.get("status") not in {"present", "anomaly"} or not artifact.get("path"):
            continue
        path = Path(str(artifact["path"]))
        if not path.is_absolute():
            path = HIST_ARTIFACT_DIR / path
        if not path.exists():
            continue
        artifact_kind = str(artifact.get("kind", path.name))
        caption_parts = [artifact_kind]
        if artifact_kind.startswith("header_delay"):
            caption_parts.append("INVALID ts_delta source")
        if artifact.get("status") == "anomaly":
            caption_parts.append("ANOMALY")
        if artifact.get("visual_checkpoint"):
            caption_parts.append(str(artifact["visual_checkpoint"]))
        figures.append(
            "<figure>"
            f"<a href=\"{esc(rel(path))}\"><img src=\"{esc(rel(path))}\" alt=\"{esc(artifact.get('kind', path.name))}\"></a>"
            f"<figcaption>{esc(' - '.join(caption_parts))}</figcaption>"
            "</figure>"
        )
    if not figures:
        return "<p class=\"missing-text\">No plotted histogram artifacts are present yet. Raw JSON does not satisfy this gate.</p>"
    return "\n".join(figures)


def stats_path(value: str | None) -> Path:
    if not value:
        return Path("/__missing__")
    path = Path(value)
    if path.is_absolute():
        return path
    return REPO_ROOT / path


def header_delay_stats() -> list[dict[str, Any]]:
    if not HEADER_DELAY_STATS.exists():
        return []
    rows: list[dict[str, Any]] = []
    with HEADER_DELAY_STATS.open(newline="", encoding="utf-8") as handle:
        for raw in csv.DictReader(handle, delimiter="\t"):
            row: dict[str, Any] = dict(raw)
            json_path = stats_path(row.get("json"))
            payload = load_json_path(json_path) if json_path.exists() else None
            case = first_case(payload.get("cases", [])) if payload else None
            summary = case.get("summary", {}) if isinstance(case, dict) else {}
            args = payload.get("args", {}) if isinstance(payload, dict) else {}
            row["phase_class"] = summary.get("phase5_classification", "-")
            row["pass"] = bool(summary.get("pass", False))
            row["header_channel"] = args.get("header_channel", "-")
            row["hist_hits"] = summary.get("hist_total_delta", 0)
            row["ring_inerr"] = summary.get("ring_inerr_delta", 0)
            row["mts_discard"] = summary.get("mts_discard_delta", 0)
            row["mts_discard_pct"] = summary.get("mts_discard_pct")
            if row["mts_discard_pct"] is None:
                try:
                    mts_total = float(summary.get("mts_total_delta", 0) or 0)
                    mts_discard = float(summary.get("mts_discard_delta", 0) or 0)
                    if mts_total > 0:
                        row["mts_discard_pct"] = 100.0 * mts_discard / mts_total
                except (TypeError, ValueError):
                    row["mts_discard_pct"] = None
            row["lvds_error_delta"] = summary.get("lvds_error_delta_total", "n/a")
            row["dpa_unlock_delta"] = summary.get("lvds_dpa_unlock_delta_total", "n/a")
            rows.append(row)
    return rows


def header_delay_figures() -> str:
    contact = HEADER_DELAY_ARTIFACT_DIR / "phase6_header_delay_asic_contact_sheet.png"
    if not contact.exists():
        return "<p class=\"missing-text\">All-eight-ASIC header-sync delay DISLIN plots are missing.</p>"
    return (
        "<figure>"
        f"<a href=\"{esc(rel(contact))}\"><img src=\"{esc(rel(contact))}\" alt=\"all ASIC header-sync delay contact sheet\"></a>"
        "<figcaption>Invalidated header-sync ts_delta diagnostic per ASIC. The green boundary was drawn for the rbCAM latency window, but this artifact used inter-hit timestamp delta, not MTS debug_ts latency.</figcaption>"
        "</figure>"
    )


def pct_text(value: Any) -> str:
    try:
        return f"{100.0 * float(value):.6f}%"
    except (TypeError, ValueError):
        return "-"


def pct_text_already_percent(value: Any) -> str:
    try:
        return f"{float(value):.6f}%"
    except (TypeError, ValueError):
        return "-"


def header_delay_rows() -> str:
    rows = []
    for row in header_delay_stats():
        plot = stats_path(row.get("plot"))
        plot_link = f'<a href="{esc(rel(plot))}">{esc(plot.name)}</a>' if plot.exists() else esc(plot.name or "-")
        try:
            peak = float(row.get("peak_fraction", 0.0))
            proxy = float(row.get("rbcam_drop_proxy_with_counter_fraction", row.get("rbcam_drop_proxy_fraction", 0.0)))
            ring_inerr = int(row.get("ring_inerr", 0) or 0)
            hist_hits = int(row.get("hist_hits", 0) or 0)
        except (TypeError, ValueError):
            peak = proxy = 0.0
            ring_inerr = hist_hits = 0
        status = "INVALID"
        rows.append(
            "<tr>"
            f"<td>{esc(row.get('asic', '-'))}</td>"
            f"<td>{badge(status)}<div class=\"class\">{esc(row.get('phase_class', '-'))}</div></td>"
            f"<td>{esc(row.get('lane_mask', '-'))}<div class=\"rate\">header_ch={esc(row.get('header_channel', '-'))}; {esc(row.get('debug_source', '-'))}</div></td>"
            f"<td>{fmt_int(row.get('total_hits'))}</td>"
            f"<td>{pct_text(peak)}</td>"
            f"<td>{pct_text(row.get('inband_0_2000_fraction'))}</td>"
            f"<td>{pct_text(proxy)}</td>"
            f"<td>{fmt_int(row.get('outband_lt0_hits'))} / {fmt_int(row.get('outband_gt2000_hits'))}</td>"
            f"<td>{fmt_int(row.get('hist_underflow_wait_delta'))} / {fmt_int(row.get('hist_overflow_wait_delta'))}</td>"
            f"<td>{fmt_int(row.get('hist_underflow_read_delta'))} / {fmt_int(row.get('hist_overflow_read_delta'))}</td>"
            f"<td>{fmt_int(row.get('mts_discard'))}<div class=\"rate\">{pct_text_already_percent(row.get('mts_discard_pct'))}</div></td>"
            f"<td>{fmt_int(row.get('ring_inerr'))}</td>"
            f"<td>{plot_link}</td>"
            "</tr>"
        )
    if not rows:
        return "<tr><td colspan=\"13\">Header-sync delay stats missing.</td></tr>"
    return "\n".join(rows)


def highcycle_stats() -> list[dict[str, str]]:
    if not HIGHCYCLE_STATS.exists():
        return []
    with HIGHCYCLE_STATS.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def highcycle_rows() -> str:
    rows = []
    for row in highcycle_stats():
        plot = Path(row.get("plot", ""))
        plot_link = f'<a href="{esc(rel(plot))}">{esc(plot.name)}</a>' if plot.exists() else esc(plot.name or "-")
        try:
            mean_khz = float(row.get("mean_hz_per_channel", "0")) / 1000.0
            min_khz = float(row.get("min_hz_per_channel", "0")) / 1000.0
            max_khz = float(row.get("max_hz_per_channel", "0")) / 1000.0
            cv = float(row.get("cv_all_channels", "0"))
        except ValueError:
            mean_khz = min_khz = max_khz = cv = 0.0
        pulse_high = row.get("pulse_high", "-")
        note = "silent"
        if mean_khz > 0.0:
            if 98.0 <= mean_khz <= 102.0 and max_khz < 130.0:
                note = "rate plateau"
            elif mean_khz < 90.0:
                note = "underfilled"
            else:
                note = "overfilled; possible TDC-line ringing/double-edge pickup"
        rows.append(
            "<tr>"
            f"<td>{esc(pulse_high)}</td>"
            f"<td>{fmt_int(row.get('total_hz'))}</td>"
            f"<td>{mean_khz:.3f}</td>"
            f"<td>{fmt_int(row.get('nonzero_channels'))}</td>"
            f"<td>{min_khz:.3f}</td>"
            f"<td>{max_khz:.3f}</td>"
            f"<td>{cv:.4f}</td>"
            f"<td>{esc(note)}</td>"
            f"<td>{plot_link}</td>"
            "</tr>"
        )
    if not rows:
        return "<tr><td colspan=\"9\">High-cycle sweep artifacts missing.</td></tr>"
    return "\n".join(rows)


def highcycle_figures() -> str:
    selected = {1, 3, 5, 6, 8, 15}
    figures = []
    by_ph = {}
    for row in highcycle_stats():
        try:
            by_ph[int(row.get("pulse_high", "-1"))] = row
        except ValueError:
            continue
    for pulse_high in sorted(selected):
        row = by_ph.get(pulse_high)
        if not row:
            continue
        plot = Path(row.get("plot", ""))
        if not plot.exists():
            continue
        mean_khz = float(row.get("mean_hz_per_channel", "0")) / 1000.0
        cv = float(row.get("cv_all_channels", "0"))
        figures.append(
            "<figure>"
            f"<a href=\"{esc(rel(plot))}\"><img src=\"{esc(rel(plot))}\" alt=\"pulse_high {pulse_high} rate plot\"></a>"
            f"<figcaption>pulse_high={pulse_high}; mean={mean_khz:.3f} kHz/channel; CV={cv:.4f}</figcaption>"
            "</figure>"
        )
    if not figures:
        return "<p class=\"missing-text\">No high-cycle DISLIN rate plots are present yet.</p>"
    return "\n".join(figures)


def mask_response_stats() -> list[dict[str, str]]:
    if not MASK_RESPONSE_STATS.exists():
        return []
    with MASK_RESPONSE_STATS.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def mask_response_figures() -> str:
    figures = []
    for filename, caption in (
        (
            "phase6_mask_response_asic_lvds_contact_sheet.png",
            "ASIC LVDS mask response: whole 32-channel ASIC blocks vanish when the lane is masked.",
        ),
        (
            "phase6_mask_response_channel_mask_contact_sheet.png",
            "Channel mask response: the same random 32-bit channel mask repeats across all eight ASICs.",
        ),
    ):
        path = MASK_RESPONSE_ARTIFACT_DIR / filename
        if path.exists():
            figures.append(
                "<figure>"
                f"<a href=\"{esc(rel(path))}\"><img src=\"{esc(rel(path))}\" alt=\"{esc(caption)}\"></a>"
                f"<figcaption>{esc(caption)}</figcaption>"
                "</figure>"
            )
    if not figures:
        return "<p class=\"missing-text\">No Phase-6 mask-response bar plots are present yet.</p>"
    return "\n".join(figures)


def mask_response_rows() -> str:
    rows = []
    for row in mask_response_stats():
        try:
            total_mhz = float(row.get("total_hz", "0")) / 1_000_000.0
            mean_khz = float(row.get("mean_hz_per_channel", "0")) / 1000.0
            max_khz = float(row.get("max_hz_per_channel", "0")) / 1000.0
            cv = float(row.get("cv_all_channels", "0"))
        except ValueError:
            total_mhz = mean_khz = max_khz = cv = 0.0
        plot = Path(row.get("plot", ""))
        plot_link = f'<a href="{esc(rel(plot))}">{esc(plot.name)}</a>' if plot.exists() else esc(plot.name or "-")
        rows.append(
            "<tr>"
            f"<td>{esc(row.get('kind', '-'))}</td>"
            f"<td>{esc(row.get('case', '-'))}</td>"
            f"<td>{total_mhz:.3f}</td>"
            f"<td>{mean_khz:.3f}</td>"
            f"<td>{fmt_int(row.get('nonzero_channels'))}</td>"
            f"<td>{max_khz:.3f}</td>"
            f"<td>{cv:.4f}</td>"
            f"<td>{plot_link}</td>"
            "</tr>"
        )
    if not rows:
        return "<tr><td colspan=\"8\">Mask-response artifacts missing.</td></tr>"
    return "\n".join(rows)


def mask_response_raw_check() -> list[dict[str, str]]:
    if not MASK_RESPONSE_RAW_CHECK.exists():
        return []
    with MASK_RESPONSE_RAW_CHECK.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def mask_response_raw_summary() -> str:
    rows = mask_response_raw_check()
    if not rows:
        return "<p class=\"missing-text\">Raw mask-check TSV is missing.</p>"
    exact = sum(1 for row in rows if row.get("pass_exact_nonzero") == "1")
    gated = sum(1 for row in rows if row.get("pass_50k_gate") == "1")
    max_off = max((int(row.get("max_off_count", "0") or 0) for row in rows), default=0)
    min_on = min((int(row.get("min_on_count", "0") or 0) for row in rows), default=0)
    path_link = f'<a href="{esc(rel(MASK_RESPONSE_RAW_CHECK))}">{esc(MASK_RESPONSE_RAW_CHECK.name)}</a>'
    klass = "pass" if exact == len(rows) and gated == len(rows) else "fail"
    return (
        f"<p><span class=\"badge {klass}\">RAW CHECK</span> {exact}/{len(rows)} cases match the "
        f"intended nonzero channel set exactly, {gated}/{len(rows)} pass the 50k-count on-bin gate, "
        f"max off-bin count is {max_off}, and min on-bin count is {min_on}. Raw TSV: {path_link}.</p>"
    )


def mask_response_raw_rows() -> str:
    rows = []
    for row in mask_response_raw_check():
        status = "PASS" if row.get("pass_exact_nonzero") == "1" and row.get("pass_50k_gate") == "1" else "FAIL"
        klass = "pass" if status == "PASS" else "fail"
        rows.append(
            "<tr>"
            f"<td>{esc(row.get('kind', '-'))}</td>"
            f"<td>{esc(row.get('case', '-'))}</td>"
            f"<td>{fmt_int(row.get('expected_on'))}</td>"
            f"<td>{fmt_int(row.get('observed_nonzero'))}</td>"
            f"<td>{fmt_int(row.get('observed_ge_50k'))}</td>"
            f"<td>{fmt_int(row.get('max_off_count'))}</td>"
            f"<td>{fmt_int(row.get('min_on_count'))}</td>"
            f"<td><span class=\"badge {klass}\">{status}</span></td>"
            "</tr>"
        )
    if not rows:
        return "<tr><td colspan=\"8\">Raw mask-check rows missing.</td></tr>"
    return "\n".join(rows)


def evidence_rows() -> str:
    rows = []
    for title, kind, filename, note in EVIDENCE:
        payload = load_json(filename)
        summary = invalidate_zero_vcodelay(filename, summarize_payload(payload))
        path = REPORT_DIR / filename
        link = f'<a href="{esc(rel(path))}">{esc(filename)}</a>' if path.exists() else esc(filename)
        monitor_text, monitor_klass = monitor_status(summary.get("duration"))
        window = float_or_none(summary.get("window_s"))
        window_text = f"{window:.3f} s" if window is not None else "rate window missing"
        rows.append(
            "<tr>"
            f"<td>{esc(kind)}</td>"
            f"<td>{esc(title)}<div class=\"note\">{esc(note)}</div></td>"
            f"<td>{badge(summary.get('result', '-'))}<div class=\"class\">{esc(summary.get('class', '-'))}</div></td>"
            f"<td>{esc(summary.get('scope', '-'))}<br>{esc(summary.get('active', '-'))}</td>"
            f"<td>{esc(summary.get('mts_cfg', '-'))}</td>"
            f"<td><span class=\"mini-badge {monitor_klass}\">{esc(monitor_text)}</span><div class=\"rate\">{esc(window_text)}</div></td>"
            f"<td>{fmt_count_rate(summary.get('mts_in'), summary.get('mts_in_rate'))}<br>drop {fmt_count_rate(summary.get('mts_drop'), summary.get('mts_drop_rate'))}</td>"
            f"<td>{fmt_count_rate(summary.get('hist_in'), summary.get('hist_in_rate'))}<br>drop {fmt_count_rate(summary.get('hist_drop'), summary.get('hist_drop_rate'))}</td>"
            f"<td>in {fmt_count_rate(summary.get('rbcam_in'), summary.get('rbcam_in_rate'))}<br>out {fmt_count_rate(summary.get('rbcam_out'), summary.get('rbcam_out_rate'))}<br>reject {fmt_count_rate(summary.get('rbcam_reject'), summary.get('rbcam_reject_rate'))}</td>"
            f"<td>in {fmt_count_rate(summary.get('feb_in'), summary.get('feb_in_rate'))}<br>miss {fmt_count_rate(summary.get('feb_drop'), summary.get('feb_drop_rate'))}</td>"
            f"<td>{esc(summary.get('lvds', '-'))}</td>"
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
    .warn {{ background: #ad6a00; }}
    .fail {{ background: #b73535; }}
    .missing {{ background: #6b7280; }}
    .mini-badge {{
      display: inline-block;
      padding: 2px 6px;
      border-radius: 4px;
      color: #fff;
      font-size: 11px;
      font-weight: 650;
      white-space: nowrap;
    }}
    .mini-badge.pass {{ background: #1d7f45; }}
    .mini-badge.fail {{ background: #b73535; }}
    .mini-badge.missing {{ background: #6b7280; }}
    .progress-table td:nth-child(3),
    .progress-table td:nth-child(4),
    .progress-table td:nth-child(5) {{ min-width: 220px; }}
    .rate {{
      margin-top: 2px;
      color: #52606d;
      font-size: 11px;
      line-height: 1.25;
    }}
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
    .plot-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(360px, 1fr));
      gap: 16px;
      margin: 12px 0 16px;
      max-width: 1280px;
    }}
    figure {{
      margin: 0;
      padding: 10px;
      background: #fff;
      border: 1px solid #d8dde3;
      border-radius: 4px;
    }}
    figure img {{
      display: block;
      width: 100%;
      height: auto;
    }}
    figcaption {{
      margin-top: 6px;
      color: #52606d;
      font-size: 12px;
    }}
    .missing-text {{
      color: #b73535;
      font-weight: 650;
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
      The fixed Phase-6 cycles explicitly loaded <code>config_smb3_tdc.txt</code>
      and <code>config_smb5_tdc.txt</code>. The original timing-closed bounded
      cycle measured P6B010 <code>ring_inerr_delta=535108</code>; the later
      SignalTap rerun measured <code>ring_inerr_delta=535373</code>,
      <code>mts_discard_delta=0</code>, and LVDS error/DPA deltas were zero.
      The fresh continued cycle
      <code>phase6_long_runs/20260430_live_continued_cycle1</code> reproduces
      the split: P6B006 lane5 and P6B007 lane6 pass alone with zero ring input
      errors, while P6B010 lower lanes5+6 one-channel fails with
      <code>ring_inerr_delta=563053</code>. P6B020 full-channel remains the
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
      A fresh all-real-lane 1 s rate monitor on 2026-05-01 is a blocker
      checkpoint, not a pass. It used the toolkit-equivalent rate preset
      metadata, all eight real LVDS lanes, <code>pulse_interval=1250</code>,
      and <code>pulse_high=4</code>. LVDS error and DPA-unlock deltas were
      zero, <code>LAST_INTERVAL_TOTAL_HITS=11851571</code>, and
      <code>hist_drop_delta=0</code>, so real hits are reaching the histogram.
      The same window still reports <code>MTS_DISCARD=1</code>,
      <code>ring_inerr_delta=2787809</code>, and
      <code>ring_overwrite_delta=79066</code>. The SC per-bin readback returned
      zero bins despite the nonzero last-interval counter; that is a tooling
      artifact from slow SC reads crossing the ping-pong histogram bank, so the
      plotted rate artifact must come from the burst System Console/toolkit
      path or a faster frozen-bin capture.
    </p>
    <p>
      The 2026-05-01 Qsys patch fixes a separate observability bug: the
      histogram source now defaults to pre-RBCAM <code>hit_type1</code>,
      <code>histogram_statistics_0</code> has two fill inputs with global
      <code>{{ASIC, channel}}</code> keys, and the lower MTS stream is split
      into both <code>hit_stack_subsystem_1</code> and
      <code>histogram_ingress_bridge_1</code>. The lower bridge
      <code>pre_out</code> is explicitly drained so the tap copy cannot
      backpressure MTS. Authentic integration simulation passed with all eight
      lanes visible: each lane reported 20 MTS channel-16 payload hits and 20
      histogram flushes, with zero histogram drops.
    </p>
    <p>
      The full-FEB generated-image blocker is now closed for emulator evidence.
      The stale image tied lower <code>histogram_statistics_0.fill_in_1</code>
      off, giving a physically sharp four-lane rate in an all-lane emulator
      run. The correct lower bridge address is Qsys byte
      <code>0xAC10..0xAC20</code>, visible through the SC hub at word
      <code>0x0AB04..0x0AB07</code>; <code>0x0AC10</code> was a bad SC-word
      premise. The newly compiled/programmed <code>top_nostp_pipe</code> SOF
      checksum <code>0x13E73362</code> exposes both bridge UIDs
      (<code>0x0AB00</code> upper and <code>0x0AB04</code> lower, both
      <code>0x48495342</code>) and passes the 1 s emulator mask matrix: all
      lanes 10 kHz gives <code>79984</code> histogram hits, upper-only gives
      <code>39996</code>, lower-only gives <code>39996</code>, all lanes
      100 kHz gives <code>798728</code>, and the dual-MTS delay-profile smoke
      gives <code>409080</code>; all have zero histogram drops. This is a
      wiring and counter observability pass, not a real MuTRiG PLL lock claim.
    </p>
    <p>
      The first all-channel plotted rate-bin checkpoint now uses the
      System Console/JTAG histogram dump path with both histogram ingress
      bridges forced to the pre-RBCAM stream. The emulator periodic
      <code>r53</code> run produces nonzero counts in all 256
      <code>{{ASIC, channel}}</code> bins and zero counts at the first
      error gate (<code>hist_drop=0</code>,
      <code>MTS_DISCARD=0</code>, <code>ring_inerr=0</code>). It is still an
      anomaly for rate closure: RBCAM overwrite/cache counters are nonzero, and
      the bin sum and per-channel balance do not match a uniform 100 kHz/channel
      source. The earlier <code>cluster-size=32</code> test is explicitly
      invalid as an all-channel cluster because the hardware field is five
      bits, so 32 wraps to zero and normalizes to one channel per ASIC.
    </p>
    <p>
      The latest direct probes rule out two weaker explanations. First, opening
      the MTS expected-latency gate from <code>2000</code> to <code>4000</code>
      and <code>65535</code> still leaves large lower-pair ring input-error
      counts, so the reject is not just a small positive delay tail above the
      nominal window. Second, header-synchronous injection on lower header
      channels <code>5</code> and <code>6</code> still fails for the real
      pair, while the same header mode passes for lane5 alone and lane6 alone.
      The pair failure is therefore still cross-ASIC even when the injection is
      locked to MuTRiG frame headers.
    </p>
    <p>
      The 2026-05-01 head-sync histogram plots add a sharper physical split.
      ASIC5 default production-lapse delay is not delta-like: <code>81759</code>
      JTAG-bin hits occupy six bins with a <code>44.914%</code> peak. Tuning
      ASIC5 to <code>cnt/vcodelay/hitlogic=52/18/25</code> improves it, but
      production lapse still leaves two bins at <code>79.171%</code> and
      <code>20.829%</code>. The same physical ASIC5 setting with
      <code>--mts-bypass-lapse on</code> collapses to one bin
      (<code>91574</code> hits, <code>100%</code> peak), while ASIC6 default
      production-lapse also collapses to one bin at <code>904</code> cycles.
      This is not a pure MuTRiG PLL unlock signature. It points at the MTS
      lapse/overflow transform, or the compile-time lookback/padding threshold
      feeding that transform, before blaming lane5 LVDS or TDC physics.
    </p>
    <p>
      The all-eight header-sync delay scan changes the acceptance handle. The
      useful loss proxy is the delay population outside the rbCAM
      <code>0..2000</code> cycle ingress window. Raw MTS discard is kept as a
      caveat because the MuTRiG fine-counter one-hot can be broken while the
      coarse timestamp remains usable. Therefore a sub-1% MTS discard is not a
      hard fail when the delay histogram is sharply in window; the next blocker
      to clear is any nonzero rbCAM drop proxy or underflow/overflow tail.
    </p>
    <p>
      The MTS IP now has a reviewed runtime CSR for that exact hypothesis:
      <code>overflow_lookback_8ns</code> at CSR word <code>5</code>. The FEB
      runners expose it as <code>--mts-overflow-lookback</code> and record the
      readback in stage snapshots. This is not a substitute for the physical
      MuTRiG scan; it is the control that separates a PLL/TDC response from an
      MTS epoch-disambiguation response in the next ASIC5 production-lapse
      A/B sweep.
    </p>
    <p>
      The lane6/7 zero-point checks are invalidated as tuning evidence. A
      MuTRiG with <code>vnvcodelay=0</code> should produce no TDC-injection
      hits. The captures labeled <code>vncnt=0</code>,
      <code>vnvcodelay=0</code>, and <code>vnhitlogic=0</code> therefore prove
      a stale configuration, bad override, or run-sequence artifact unless the
      manifest shows that a nonzero setting was actually loaded. Reduced
      lane6/7 evidence remains archived only as bad-evidence input:
      <a href="{esc(rel(REPORT_DIR / 'phase6_lane67_zero_point_20260430.md'))}">phase6_lane67_zero_point_20260430.md</a>.
    </p>
    <p>
      The first frame-boundary capture is a useful frame-format debug example
      but not closure-grade. Because it is labeled <code>vco000</code>, it must
      be rerun with ASIC-specific nonzero PLL settings and a full
      <code>RUN_PREPARE</code> sequence before it can support P6-BUG-004-H.
      The next valid capture must tie a nonempty RBCAM <code>hit_type2</code>
      beat to the later FEB <code>hit_type3</code> frame drain in one deeper
      SignalTap window or in a matched simulation/VCD replay. Archived
      evidence:
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
      The later fixed4 SWB image for the mux/subtime pack path also completed
      <code>make flow</code> with 0 errors and 298 warnings, programmed
      checksum <code>0x31A72852</code>, and recovered
      <code>/dev/mudaq0</code> plus <code>/dev/mudaq0_dmabuf</code>.
      The Mu3e online DMA tools are now deprecated for closure evidence:
      <code>swb_dmatest</code>, <code>rw</code>, MIDAS, and libmudaq-backed
      utilities are reference-only. The repo-owned
      <code>tools/phase6_swb_dma_probe/phase6_swb_dma_probe.py</code> directly
      maps <code>/dev/mudaq0</code> and <code>/dev/mudaq0_dmabuf</code>, records
      raw RW/RO registers plus SWB counter sweeps before cleanup, and writes
      <code>dma_words.bin</code> for offline reduction.
    </p>
    <p>
      The direct probe now proves the raw SWB DMA payload path is alive and
      repeatable in the stream-datagen configuration. Three fresh 10 s runs
      each recorded <code>2048</code> nonzero DMA words, <code>1024</code>
      nonpadding words, and <code>256</code> event-builder payload words.
      Their first payload words differ across runs
      (<code>0x00088A0C</code>, <code>0x0008818F</code>,
      <code>0x0008894F</code>), which rules out stale-buffer reuse for this
      control. The old FEB/SWB frame reducer reports
      <code>raw_payload_no_legacy_frames</code>, which is the expected
      interpretation for active <code>musip_event_builder</code> raw 256-bit
      payload, not an end-to-end hit-frame pass. The time-datagen path still
      records <code>no_dma_words</code> in
      <code>post_tool_update_time_datagen_generic_defaultstate</code> and with
      all four generic lanes enabled. Source inspection makes that a weak
      control: the legacy <code>data_generator_a10</code> does not guarantee
      OPQ-compatible subheader hit-count fields matching the generated hit
      body. OPQ hardware counters, real FEB-link host DMA, and disk closure
      remain open until the active MuSiP payload is decoded or a real FEB-link
      artifact is captured and reduced.
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

    <h2>Required Histogram Artifacts</h2>
    <p>
      Passing review requires plotted artifacts, not raw JSON alone. The
      channel-rate plot must come from a 1 s, 256-bin histogram accumulation,
      and the delay plot must be a header-synchronous <code>kind=delay</code>
      capture where the in-band delay collapses toward a delta function inside
      the rbCAM <code>0..2000</code> cycle accept window. The ratio of delay
      hits outside that window is the rbCAM ingress discard proxy and is more
      useful for latency closure than raw MTS discard. Stage CSRs are
      intentionally shown as rates over the measured read window, because those
      counters are not sampled simultaneously. The histogram bins are the
      precision evidence for per-channel and per-ASIC rate.
    </p>
    <p>
      The live histogram CSR setup must use the FE SciFi toolkit presets from
      <code>toolkits/fe_scifi/board_bring_up/fe_scifi_board_bring_up_project.tcl</code>.
      For delay closure, the active pipe image is the only valid lower-side
      source: <code>debug_1</code> must be upper MTS <code>debug_ts</code>
      and <code>debug_2</code> must be lower MTS <code>debug_ts</code>.
      <code>ts_delta</code> is an inter-hit timestamp-delta diagnostic and is
      rejected as rbCAM-latency evidence because it can make a false
      zero-centered peak.
    </p>
    <div class="plot-grid">
{artifact_figures()}
    </div>
    <table>
      <thead>
        <tr>
          <th>Artifact</th>
          <th>Status</th>
          <th>Contract / Inspection</th>
          <th>File</th>
        </tr>
      </thead>
      <tbody>
{artifact_status_rows()}
      </tbody>
    </table>

    <h2>Phase-6 Header-Sync Delay by ASIC</h2>
    <p>
      The existing all-ASIC DISLIN plots are invalidated as rbCAM latency
      evidence. They isolated one real MuTRiG ASIC at a time correctly, but the
      histogram debug inputs were wired to MTS <code>ts_delta</code>, which is
      the signed delta between adjacent hit timestamps. A physical hit cannot
      have zero construction latency into rbCAM; the valid plot must use MTS
      <code>debug_ts = counter_gts_8n - selected_timestamp</code> and should
      show a narrow peak with finite offset, normally with about 100..500
      cycles of width inside the <code>0..2000</code> accept window.
    </p>
    <div class="plot-grid">
{header_delay_figures()}
    </div>
    <table>
      <thead>
        <tr>
          <th>ASIC</th>
          <th>Status</th>
          <th>Lane / Source</th>
          <th>Total Delay Hits</th>
          <th>Peak</th>
          <th>0..2000 In-Band</th>
          <th>Invalid rbCAM Proxy</th>
          <th>&lt;0 / &gt;2000 Hits</th>
          <th>UF / OF During 1 s</th>
          <th>UF / OF During Read</th>
          <th>MTS Discard</th>
          <th>Ring InErr</th>
          <th>Plot</th>
        </tr>
      </thead>
      <tbody>
{header_delay_rows()}
      </tbody>
    </table>

    <h2>Phase-6 High-Cycle Rate Sweep</h2>
    <p>
      This is the post-histogram-26.1.8 real-MuTRiG rate-mode sweep requested
      for <code>pulse_high_cycles=1..15</code>. Every plot is rendered by
      DISLIN from the 1 s System Console histogram CSV, with one global channel
      per bin and the 100 kHz target marked in red. Overfilled cases are
      interpreted as physical injection-shape evidence: a non-optimal high
      time can ring the TDC injection line and produce a second rising edge on
      selected channels, so the measured rate may approach 2x or sit between
      the single-edge and double-edge limits.
    </p>
    <div class="plot-grid">
{highcycle_figures()}
    </div>
    <table>
      <thead>
        <tr>
          <th>Pulse High</th>
          <th>Total Hits/s</th>
          <th>Mean kHz/ch</th>
          <th>Nonzero Channels</th>
          <th>Min kHz/ch</th>
          <th>Max kHz/ch</th>
          <th>CV</th>
          <th>Inspection</th>
          <th>Plot</th>
        </tr>
      </thead>
      <tbody>
{highcycle_rows()}
      </tbody>
    </table>

    <h2>Phase-6 Mask Response</h2>
    <p>
      These are the requested <code>pulse_high=5</code> physical-mask checks.
      The ASIC set masks lanes in the LVDS controller and should remove whole
      32-channel blocks. The channel set leaves all ASIC lanes enabled, reloads
      every ASIC with the same random 32-bit TDC-test/channel mask, performs
      the CML <code>0-8-0</code> flush, and should remove that repeated channel
      pattern from each ASIC. The plots are DISLIN bar histograms from 1 s
      System Console CSV captures.
    </p>
    <div class="plot-grid">
{mask_response_figures()}
    </div>
{mask_response_raw_summary()}
    <table>
      <thead>
        <tr>
          <th>Kind</th>
          <th>Case</th>
          <th>Total Mhit/s</th>
          <th>Mean kHz/ch</th>
          <th>Nonzero Channels</th>
          <th>Max kHz/ch</th>
          <th>CV</th>
          <th>Plot</th>
        </tr>
      </thead>
      <tbody>
{mask_response_rows()}
      </tbody>
    </table>
    <table>
      <thead>
        <tr>
          <th>Kind</th>
          <th>Case</th>
          <th>Expected On</th>
          <th>Observed Nonzero</th>
          <th>Observed >=50k</th>
          <th>Max Off Count</th>
          <th>Min On Count</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
{mask_response_raw_rows()}
      </tbody>
    </table>

    <h2>Physical Debug Checklist</h2>
    <table>
      <thead>
        <tr>
          <th>Check</th>
          <th>Expected Response</th>
          <th>Current Checkpoint</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>Channel mask sanity</td>
          <td>Masked channels vanish from the 256-bin rate plot while unmasked channels keep their rate scale.</td>
          <td>The emulator mask matrix now passes upper-only, lower-only, and all-lane rate expectations on the fresh SOF. The real-MuTRiG <code>pulse_high=5</code> mask-response sweep shows LVDS ASIC masks zero whole 32-channel blocks and random channel masks zero the repeated per-ASIC channel pattern, with enabled bins near 100 kHz/channel. ph6/ph7 remain the flattest full-rate starting point, while ph8+ expose likely TDC-line ringing/double-edge sidebands.</td>
        </tr>
        <tr>
          <td>MuTRiG PLL/header-sync tuning</td>
          <td>Starting from no-hit zero <code>vcodelay</code>, restore nonzero ASIC defaults, run <code>RUN_PREPARE</code>, and tune until the delay histogram moves from broad/flat toward one dominant bin.</td>
          <td>The lane-mask/header-channel scan covered ASICs 0..7, but its delay artifact is invalidated because the histogram source was <code>ts_delta</code>. Recompile/regenerate with <code>debug_1/2=debug_ts</code>, then repeat the scan and use the rbCAM <code>0..2000</code> in-window ratio.</td>
        </tr>
        <tr>
          <td>Upper/lower delay input coverage</td>
          <td>Delay histograms must isolate both source 0 (upper MTS) and source 1 (lower MTS), with lower-side evidence covering ASICs 4..7.</td>
          <td>The source Qsys patch now connects <code>mts_preprocessor_0.debug_ts</code> to <code>debug_1</code> and <code>mts_preprocessor_1.debug_ts</code> to <code>debug_2</code>. The current all-ASIC plots remain invalid until a fresh firmware image is compiled and the real-MuTRiG scan is rerun.</td>
        </tr>
        <tr>
          <td>Histogram-bin capture method</td>
          <td>Read all 256 bins from the completed interval before the ping-pong bank is overwritten, preferably by the burst System Console/toolkit path.</td>
          <td>The histogram 26.1.8 fix repaired deferred frozen-bank reads. The current accepted plot source is the 1 s System Console histogram CSV; slow SC bin reads remain diagnostic-only under live traffic.</td>
        </tr>
        <tr>
          <td>Anomaly loop</td>
          <td>Every reviewed plot must state one anomaly or null anomaly and the next hardware hypothesis it supports.</td>
          <td>Current anomaly: the all-eight scan has sharp in-window peaks, but several lanes still show histogram underflow while reading. Treat that as a tail/range diagnostic for rbCAM ingress loss, not as evidence that raw MTS discard is the root metric.</td>
        </tr>
      </tbody>
    </table>

    <h2>MuTRiG Tuning Ledger</h2>
    <p>
      Triples are <code>cnt/vcodelay/hitlogic</code>. The zero point is a
      no-hit control, not a sweep start that should produce valid data. After
      every FEB reconfiguration, reload the SMB XMLs, run through
      <code>RUN_PREPARE</code>, then compare head-sync delay histograms.
    </p>
    <table class="tuning-table">
      <thead>
        <tr>
          <th>ASIC</th>
          <th>SMB</th>
          <th>XML Default</th>
          <th>Restore/Used</th>
          <th>Diagnostic</th>
          <th>Evidence</th>
          <th>Head-Sync Plot</th>
        </tr>
      </thead>
      <tbody>
{tuning_rows()}
      </tbody>
    </table>

    <h2>Evidence Table</h2>
    <p>
      Counter rows show count plus rate. The rate window is the measured
      accumulation window for shaky CSR counters; linked JSON keeps the raw
      before/sample/after snapshots for audit. Rows shorter than 1 s are
      retained only as historical debug and fail the monitor gate.
    </p>
    <table>
      <thead>
        <tr>
          <th>Kind</th>
          <th>Run</th>
          <th>Result</th>
          <th>Scope</th>
          <th>MTS Config</th>
          <th>Monitor / Rate Window</th>
          <th>MTS In / Drop</th>
          <th>Hist In / Drop</th>
          <th>RBCAM In / Out / Reject</th>
          <th>FEB Assembly In / Miss</th>
          <th>LVDS</th>
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
