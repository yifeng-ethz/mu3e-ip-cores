# FEB SciFi v4 Run-Control Lane-8 Handover

Date: 2026-05-25

## Executive Summary

The original symptom was that `rc_tool send start-run` did not advance the FEB-side `runctl_mgmt_host`: `LAST_CMD` stayed 0, `RX_CMD_COUNT` stayed 0, and lane-8 receive debug first looked like an LVDS decode fault. SignalTap and CSR evidence disproved both lane-8 polarity and bit-order hypotheses: the FEB lane-8 PHY and decoder were healthy with `RX_BITREV[8]=0`, and the real fault was that the SWB `a10_reset_link` FSM silently ignored an out-of-sequence bare `start-run` when it was not in the proper pre-start state. The closeout shipped a safer run-control host tool sequence, kept an optional LVDS `RX_BITREV` CSR for future flexibility, made FEB ACK symbols regen-safe at 0xFE/0xFD, added a tb_int BUG-014 integration reproduction, and captured the remaining ASIC7 quiet-lane follow-up as likely physical.

## Bug Tree

| Hypothesis or issue | Disposition | Evidence |
| --- | --- | --- |
| H1: lane-8 polarity inversion, fixed by `RX_INVERT` XOR | DISPROVED | Triple SignalTap characterization showed decoded idle was clean without polarity inversion. The polarity edit was converted rather than kept. |
| H2: LVDS PHY bit-endianness mismatch, fixed by `RX_BITREV` bit-reverse | DISPROVED for this board image | Triple capture showed the lane-8 raw symbol ordering was already standard IEEE and `RX_BITREV[8]=0` was the correct runtime setting. `RX_BITREV` remains as a default-off per-lane flexibility CSR. |
| H3: SWB `a10_reset_link` drops out-of-sequence rc commands | REAL BUG | The full legal sequence `end-run/abort-run -> run-prepare -> sync -> start-run` produced non-idle bytes on FEB lane 8, FEB decoded 0x10/0x11/0x12, `LAST_CMD` latched 0x12, and `RX_CMD_COUNT` advanced. |
| Side issue: FEB ACK symbol literals mis-encoded | FIXED | Qsys bare decimal literals `11111110` and `11111101` were truncated to 0xC6/0xBD. The upstream default is now 0xFE/0xFD and regenerated FEB wrappers preserve that value. |

## Evidence Pointers

| Round | Key artifact | Result |
| --- | --- | --- |
| Lane-8 raw/decode capture | `firmware_builds/systems/260518-feb-ok/REPORT/lane8_stp_capture_20260525T054728Z/` | FEB lane-8 path was observable through raw symbol, decoded byte/error, synclink, and recv FSM probes. |
| RX_BITREV triple capture | `firmware_builds/systems/260518-feb-ok/REPORT/lane8_stp_triple_20260525T060520Z/REPORT.md` | `RX_BITREV[8]=0` was correct; `RX_BITREV[8]=1` broke decode for this image. |
| SWB reset-link debug | `firmware_builds/systems/260518-feb-ok/REPORT/swb_rc_tx_20260525T062626Z/REPORT.md` | Pivoted the bug from FEB lane 8 to SWB command sequencing. |
| Legal sequence proof | `firmware_builds/systems/260518-feb-ok/REPORT/legal_sequence_20260525T064323Z/REPORT.md` | Legal reset-link sequence reached FEB `LAST_CMD=0x12` and advanced `RX_CMD_COUNT`. |
| MuTRiG configure and hit-stream check | `firmware_builds/systems/260518-feb-ok/REPORT/phase3_mutrig_20260525T102602+0200/REPORT.md` | Configure passed 24/24; ASIC0-6 advanced; ASIC7 was quiet in the 3 s run. |
| ASIC7 quick probe | `firmware_builds/systems/260518-feb-ok/REPORT/phase4_asic7_probe_20260525T104104+0200/REPORT.md` | ASIC7 stayed quiet after a 10 s run while ASIC0-6 advanced; classification is `LIKELY_PHYSICAL`. |

## What Shipped

| Artifact | Change | Status |
| --- | --- | --- |
| `mu3e_lvds_controller` 26.2.8 | Added `RX_BITREV` CSR at word 28, default 0, with BUG-014-R disposition documenting the disproved bit-order hypothesis. | Pushed on `master` at `7eecd53`. |
| `run-control_mgmt` 26.3.3 | Made ACK defaults regen-safe as 0xFE/0xFD and updated BUG-005-R. | Pushed on `master` at `a063e421`; Phase 1 BUG ledger commit was `e8a9495`. |
| `feb_system_v4` generated wrapper | Regenerated with 0xFE/0xFD ACK symbols, so the earlier hand override is no longer the only protection. | Parent Phase 2 commit `d4619f83`. |
| `rc_tool` | Added state-precondition refusal for bare sends plus `start-sequence` and `stop-sequence`. | Pushed in `online_dpv2` at `8841e31e`. |
| `tb_int/scifi_v4_wrapper` | Added `int_b014_lane8_bitreverse_decode_sequence` and `make int_b014_lane8_bitreverse_decode`. | Parent Unit C commit `000abc8f`; push was retried and blocked by GitHub Internal Server Error during this pane. |
| Phase 4 reports | Added ASIC7 quick-probe report and STP widen plan. | Staged with this handover commit. |

## Operational Guide

Canonical run-control start:

```sh
~/.local/bin/swb_ring_lock rc_tool send start-sequence --run <N> --quiet
```

Canonical stop:

```sh
~/.local/bin/swb_ring_lock rc_tool send stop-sequence --quiet
```

Recovery if the SWB reset-link status byte is stuck or unexpected:

```sh
~/.local/bin/swb_ring_lock rc_tool send abort-run --quiet
~/.local/bin/swb_ring_lock rc_tool send start-sequence --run <N> --quiet
```

MuTRiG configure: use `configure_mutrig_from_xml_v4addr.py` or an explicitly patched `configure_mutrig_from_xml.py` with v4 MCC base `0x01400`. Do not use the older testplanphase5 base `0x0FC04` for this FEB v4 build.

Correct v4 slow-control base corrections discovered during closeout:

| Block | Correct v4 base | Note |
| --- | ---: | --- |
| `frame_deassembly` ASIC0 | `0x04428` | Earlier memory value `0x06228` is not correct for this v4 image. |
| `mutrig_injector_0` | `0x06C80` | Earlier memory value `0x0AC00` is not correct for this v4 image. |

The FEB-local fallback still works and bypasses SWB optical run-control:

```sh
~/.local/bin/swb_ring_lock sc_tool 2 write 0x0C013 0x00000012 --quiet
```

## 2026-05-26 Follow-Up: Histogram Methodology And MTS Per-ASIC Chase

The follow-up work moved from run-control into the Type1 histogram path. Lane 7 was initially classified as `TRAIN_BITSLIPPING`, then the active debug images showed that link and board state can shift after reprogramming; lane 8 was also observed to lock to nonsense in one image and was recoverable with the LVDS soft-reset write `sc_tool 2 write 0x04006 0x00000100`. The stable histogram setup now writes both bounds explicitly: `LEFT_BOUND=0xFFFFFC18` (-1000), `RIGHT_BOUND=0x00000C18` (3096), `BIN_WIDTH=16`, mode-1 signed delay, with the RIGHT_BOUND write required before applying control. ASIC0 peak-structure post-processing showed a central peak plus long background rather than a simple gross-FWHM-only shape, so future analysis should use background-subtracted peak width in addition to raw FWHM.

The MTS per-ASIC discrimination chase produced a standalone-verified RTL series:

| Version | Change | Status |
| --- | --- | --- |
| `mts_processor` 26.3.10 | Inlined ASIC-ID derivation from `asi_hit_type0_channel[5:4]` plus BANK. | Standalone sim/static/syn passed; silicon still did not prove per-ASIC filtering. |
| `mts_processor` 26.3.11 | Added `source_asic_pipe` sideband through accepted hit, padding, prediv, totcalc, divider, and hit_out; Type1[38:35] packs sideband. | Standalone sim/static/syn passed; STP evidence showed accepted samples preserved what reached stage 0. |
| `mts_processor` 26.3.12 | Fixed the input acceptance gate to use local low channel `asi_hit_type0_channel[3:0]`, not the full 6-bit mux channel. | Standalone sim/static/syn passed; on-board MTS visibility still timed out. |
| `mts_processor` 26.3.13 | Added preserved `stp_mts_freerun_toggle_q` as a guaranteed MTS-clock SignalTap trigger. | FEB compile/program passed, but `mts_debug` still timed out; this is the current observability wall. |

The 2026-05-26 landing commits are:

| Repo | Branch | Commit |
| --- | --- | --- |
| `mu3e_lvds_controller` | `master` | `c341cf5` |
| `mutrig_timestamp_processor` | `master` | `e47227d` |
| parent `mu3e-ip-cores` | `feb-scifi-v4-bringup-20260521` | `e8d11416` |

What landed in the parent after this follow-up:

- `lvds_decoded` lane-7 debug probe plan and STP wiring.
- `mts_debug` SignalTap instance, regenerated into `mutrig_cfg_lvds.stp` and `top.qsf`.
- Reusable scripts under `firmware_builds/systems/260518-feb-ok/script/signaltap/`:
  - `add_mts_debug_instance.py`
  - `setup_for_hist_capture.py`
  - `stp_acquire_instance.tcl`
  - `decode_mts_debug_stp.py`
  - `decode_mts_freerun_stp.py`
  - `run_per_asic_hist.py`
- Summary reports only; bulky CSVs, logs, captures, and transcripts remain untracked on disk as audit trail.

Outstanding on-silicon items:

| Item | Current status | Next action |
| --- | --- | --- |
| Per-ASIC Type1 histogram discrimination | Not closed. Standalone RTL is fixed, but silicon evidence is blocked by STP observability timeout and unstable SC state. | Restore board/control observability first, then re-run `mts_debug` capture and only then loop per-ASIC hist. |
| Type1-down bank silence | Still open and likely separate from the Type1[38:35] source-ID bug. | Once MTS STP proves Type1-down data at the histogram tap, inspect or patch histogram down-bank accept/control. |
| MTS SignalTap runtime | Current wall. Even a preserved free-running toggle trigger timed out, and the exported buffer was mostly `X`. | Add a minimal always-on control-clock STP sanity instance before more MTS-path debug. |
| SC secondary ring after latest debug image | Unhealthy. Lane-8 soft-reset SC write timed out even after one PCIe recovery. | Start next session with a full board recovery cycle before relying on `sc_tool`. |

Next session checklist:

1. Full board recovery cycle: reprogram FEB, reprogram SWB if needed, run `sudo -n /usr/local/sbin/mudaq_recover_pcie`, and wait 20 s after programming before SC/RC traffic.
2. Add a minimal always-on control-clock SignalTap sanity instance separate from `mts_debug`; trigger it on a free-running toggle in a known live control clock.
3. Verify JTAG/STP runtime capture works on that always-on instance before any more MTS investigation.
4. Re-attempt the existing `mts_debug` freerun capture once SignalTap observability is proven.
5. If MTS path proves clean, run `script/signaltap/run_per_asic_hist.py` with `KEY_VALUE=i<<16`; if ASIC1..3 still reject, inspect histogram filter compare/config.
6. If MTS path still only accepts slot 0 or Type1[38:35] is wrong, use the committed `mts_processor` STP shadows to localize the stage rather than adding another broad probe set.

Relevant report summaries:

| Report | Purpose |
| --- | --- |
| `REPORT/legal_sequence_20260525T064323Z/REPORT.md` | Legal SWB reset-link sequence proof. |
| `REPORT/lane7_health_20260525T140946+0200/REPORT.md` | Lane-7 health classification. |
| `REPORT/recover_recapture_20260525T202456+0200/REPORT.md` | Reconfiguration/recovery and lane-7 recapture attempt. |
| `REPORT/softreset_hist_20260525T220520+0200/REPORT.md` | Lane-8 soft-reset recovery and hist remeasure. |
| `REPORT/asic0_peak_structure_20260525T222128+0200/REPORT.md` | ASIC0 background-subtracted peak-structure analysis. |
| `REPORT/hist_visibility_20260525T162704+0200/REPORT.md` | Histogram visibility and RIGHT_BOUND/interval behavior. |
| `REPORT/hist_latency_default_range_20260525T163825+0200/REPORT.md` | Canonical default delay-hist range. |
| `REPORT/mts_asic_id_phase5_20260526T001927+0200/REPORT.md` | First per-ASIC filter attempt with Type1 ID bug. |
| `REPORT/mts_mux_stp_capture_20260526T012117+0200/REPORT.md` | Mux/MTS/Type1 STP proof that source ID was lost downstream of mux. |
| `REPORT/mts_inline_fix_type1_down_20260526T081858+0200/REPORT.md` | Inline MTS fix and Type1-down investigation. |
| `REPORT/mts_sideband_pipeline_20260526T091018+0200/REPORT.md` | Sideband pipeline fix and verification. |
| `REPORT/mts_accept_gate_fix_20260526T111252+0200/REPORT.md` | Low-channel acceptance gate fix. |
| `REPORT/mts_freerun_stp_20260526T135042+0200/REPORT.md` | Freerun-trigger STP compile/program and observability wall. |

## Open Items

| Item | Classification | Next action |
| --- | --- | --- |
| ASIC7 quiet | `LIKELY_PHYSICAL` | Inspect ASIC7 physical/link/config path. Unit A found no injector mask and no nearby frame-deassembly CSR activity after 10 s. |
| `lvds_decoded` all-lane visibility | Planned | Use `firmware_builds/systems/260518-feb-ok/REPORT/stp_widen_lvds_decoded_plan.md` before the next FEB compile/reprogram. |
| `run-control_mgmt` standalone tb cleanup | Fixed | Guarded cleanup landed after the original Phase 2 gap; reruns no longer require `rm -rf`. |
| tb_int BUG-014 integration sequence | PASS | `make int_b014_lane8_bitreverse_decode` passed in `tb_int/scifi_v4_wrapper/REPORT/scifi_v4_wrapper_20260525_110347/elab.log`. |

## Commit Hashes

| Repo | Branch | Commit |
| --- | --- | --- |
| `mu3e_lvds_controller` | `master` | `7eecd53` |
| `run-control_mgmt` | `master` | `e8a9495` Phase 1, `a063e421` Phase 2 |
| parent `mu3e-ip-cores` | `feb-scifi-v4-bringup-20260521` | `e591fc27` Phase 1, `d4619f83` Phase 2, `000abc8f` Unit C |
| `online_dpv2` | `mu3e_ip_dev` | `8841e31e` |
| `mu3e_lvds_controller` | `master` | `c341cf5` 2026-05-26 lane-7 STP mirrors |
| `mutrig_timestamp_processor` | `master` | `e47227d` 2026-05-26 MTS Type1 ASIC-ID / freerun trigger |
| parent `mu3e-ip-cores` | `feb-scifi-v4-bringup-20260521` | `e8d11416` 2026-05-26 MTS debug STP audit trail |

## Memory Updates Landed

These memory slugs should be present for future sessions and are referenced here for traceability:

| Slug | Purpose |
| --- | --- |
| `feedback_swb_rc_fsm_sequencing` | Bare `start-run` is not a legal substitute for the full SWB reset-link sequence. |
| `feedback_qsys_bare_literal_decimal` | Qsys bare numeric literals can be decimal, causing 0xFE-like values to truncate incorrectly. |
| `feedback_mutrig_configure_tool` | Canonical MuTRiG configure tool path and v4 MCC base `0x01400`. |
| `onboard_signaltap_gui_only` | Corrected guidance: Quartus STP headless acquisition is possible with the Tcl flow used in this closeout. |
| `feedback_lvds_soft_reset_recovery` | Lane-8 bad DPA/locked-to-nonsense images can recover through LVDS soft reset at `0x04006`. |
| `feedback_hist_right_bound_explicit` | Delay histogram setup must write RIGHT_BOUND explicitly before applying CONTROL. |
| `project_v4_sc_address_map` | v4 slow-control bases: MCC `0x01400`, LVDS `0x04000`, injector `0x06C80`, runctl `0x0C000`. |
