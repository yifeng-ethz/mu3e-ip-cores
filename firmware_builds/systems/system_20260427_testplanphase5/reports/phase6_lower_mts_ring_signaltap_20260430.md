# Phase 6 Lower MTS/Ring SignalTap Checkpoint

## Purpose

Localize the live FEB blocker before spending another SWB/DMA run. The case is
P6B010: SMB5 ASIC5/6, one TDC-test channel per ASIC, real-source lanes 5+6,
pulse high `4`, pulse interval `1250`, 250 ms window, MTS expected latency
`2000`, T timestamp field, and `drop_delay_error=off`.

## Image and Timing

- Quartus revision: `top_stp_pipe_phase5_frame_hist`
- SignalTap scope: `signaltap/phase6_lower_mts_ring_path.stp`
- Node Finder: `1180/1180` probes found, `0` missing
- Programmed checksum/usercode: `0x16B6BF30`
- SOF SHA256: `080f92844f868d33e142ce6e576911b728f9364fadd1d9c2824addd7d1cff2b9`
- RBF SHA256: `a48b5e6850f04dbe4db996df4f7277891de66bc935487ef1138d0e84b9945792`
- Fitter: `64,197 / 91,680` ALMs, `98,514` registers,
  `668 / 1,366` RAM blocks
- STA: setup WNS `-0.086 ns`, TNS `-0.758` on
  `transceiver_pll_clock[0]`; LVDS `pll_sclk` setup `+0.319 ns`;
  hold/recovery/removal positive

This is an Arria V directed-debug image. The small negative WNS is accepted for
this capture only because the paths are understood and within the clarified
about-200 ps debug tolerance. It is not soak/signoff timing evidence. SWB Arria
10 images still require clean timing closure in all checked corners.

## ASIC Configuration

`configure_mutrig_from_xml.py` loaded the explicit SMB5 XML for ASIC5/6:

| ASIC | XML Local | Opcode | Words | Final Status | Frame Delta | CRC Delta | Result |
|---:|---:|---:|---:|---:|---:|---:|---|
| 5 | 1 | `0x01150054` | 84 | `0x00000000` | 0 | 0 | `PASS` |
| 6 | 2 | `0x01160054` | 84 | `0x00000000` | 0 | 0 | `PASS` |

Overrides: `cml_sc=0`, `recv_all=1`, channel enable mask `0x1`,
TDC-test channel mask `0x1`, `ext_trig_offset=0`, and `sync_ch_rst=1`.

## Live Counter Result

The runner failed as expected for the current blocker:

| Field | Value |
|---|---:|
| Classification | `ring_input_errors_with_histogram_hits` |
| Histogram hits / drops | `74153` / `0` |
| MTS hits / discard | `415630` / `0` |
| Ring input-error delta | `535373` |
| Ring push / pop | `347780` / `347778` |
| Ring cache miss | `347236` |
| Frame actual / CRC / missing | `373144` / `0` / `0` |
| LVDS error delta | `0` |
| LVDS DPA-unlock delta | `0` |
| Post-end clean | `yes` |

The source-mux selected/real/emu deltas in this runner instance are not rate
evidence; they wrapped or share a bad delta path. Use MTS/hist/frame/ring/LVDS
counters and the SignalTap VCD for this checkpoint.

## SignalTap Result

Raw capture exported:
`captures/phase6_lower_mts_ring_p6b010_20260430_1758.vcd`.

Reduced summary:
[`phase6_lower_mts_ring_vcd_summary_20260430.md`](phase6_lower_mts_ring_vcd_summary_20260430.md).

Important VCD events:

| Signal | First high ps | Rising edges | Ever high |
|---|---:|---:|---:|
| `mux5.aso_valid` | 500 | 1 | 1 |
| `mux6.aso_valid` | 500 | 1 | 1 |
| `deasm5.aso_hit_type0_valid` | 111500 | 2 | 1 |
| `deasm6.aso_hit_type0_valid` | 111500 | 2 | 1 |
| `mts1.asi_hit_type0_valid` | 116500 | 1 | 1 |
| `mts1.aso_hit_type1_valid` | 127500 | 1 | 1 |
| `mts1.hit_out_delay_error` | 127500 | 1 | 1 |
| `mts1.aso_hit_type1_error` | 128500 | 1 | 1 |
| `hit_stack1.hit_type_1_valid` | 127500 | 1 | 1 |
| `hit_stack1.hit_type_1_error[0]` | 128500 | 1 | 1 |

At `128500 ps`, the lower MTS output error context is:
`asi_hit_type0_data=0x0C0573820000`,
`asi_hit_type0_channel=0x26`, `asi_hit_type0_error=0x0`,
`aso_hit_type1_data=0x30279B0000`, `aso_hit_type1_channel=0x0`,
`aso_debug_ts_data=0x035D`, and `aso_debug_burst_data=0xB471`.

The downstream ring input-error context in the same window is:
`hit_type_1_data=0x30279B0400`, `hit_type_1_channel=0x0`,
`hit_type_1_error=0x1`, and `frame_debug_ts_data=0x0836`.

Quartus reported `PRE (0 triggers seen)` before `DONE`, yet the exported VCD
contains the expected lower MTS and hit-stack error transitions. Treat the VCD
as supporting causality evidence tied to the failed live counter run, not as an
independent trigger-quality pass.

## Conclusion

The one-channel lower-pair failure is currently real on the timing-closed
Phase-6 debug image. LVDS error and DPA-unlock deltas stayed zero. MTS1 asserts
the delay/error sideband before the hit reaches hit_stack1/ring, and the ring
input-error bit is visible in the same capture window. The next fix should
target the lower MTS timestamp-delay calculation, cross-ASIC ordering/epoch
handling, or the upstream timestamp formation into MTS1, not the ring CAM alone
and not SWB/DMA.
