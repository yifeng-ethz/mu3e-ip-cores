# Histogram Bin Readout Visibility - 2026-05-25

## Scope

Focused no-compile board round. No RTL files were edited, no commits were made,
and no LVDS controller CSR reads were performed. Every `sc_tool` and `rc_tool`
command in the live experiment was wrapped with `~/.local/bin/swb_ring_lock`.

## Unit A - RTL Pinpoint

### Ping-Pong / Interval Control Surface

| Action | CSR or trigger | Effect | Source |
|---|---|---|---|
| Read visible bins | `hist_bin` slave at SC `0x06800..0x068FF` | Host read follows the frozen bank, which is `not active_bank` in ping-pong mode. | `histogram_statistics/rtl/pingpong_sram.vhd:205-216`, `:499-508`, `histogram_statistics/rtl/histogram_statistics_v2.vhd:1766-1795` |
| Periodic bank swap | `INTERVAL_CFG` word 10 at SC `0x0690A` | Timer fires when `timer_count = i_interval_clocks - 1`; swap flips `active_bank`, asserts `interval_pulse`, and exposes the just-frozen bank. | `histogram_statistics/rtl/histogram_statistics_v2.vhd:2044`, `:2152-2153`, `histogram_statistics/rtl/pingpong_sram.vhd:460-468` |
| Force interval pulse | No software CSR | Internal only: termination path asserts `force_interval_pulse` when terminating, armed, pipeline idle, and `csr_total_hits != 0`. | `histogram_statistics/rtl/histogram_statistics_v2.vhd:1172-1195`, `histogram_statistics/rtl/pingpong_sram.vhd:423-427`, `:479-481` |
| Clear histogram | Write `0` to `hist_bin` SC `0x06800` | Asserts `measure_clear_pulse`, clearing ingress/queue/stats and ping-pong state. | `histogram_statistics/rtl/histogram_statistics_v2.vhd:1064-1065`, `:1458-1484`, `histogram_statistics/rtl/pingpong_sram.vhd:360-371` |
| Bank status | `BANK_STATUS` word 11 at SC `0x0690B` | `[0]=active_bank`, `[1]=flushing`, `[15:8]=flush_addr`; no bank-select CSR and no fill-count fields. | `histogram_statistics/rtl/histogram_statistics_v2.vhd:1969-1984`, `histogram_statistics/histogram_statistics.svd:300-352` |

### Accept To Bin-Write Path

The front-end `LAST_INTERVAL_TOTAL_HITS` counter is before the divider/bin-write
visibility point:

| Stage | Gate | Source |
|---|---|---|
| Type1 extended sample | `port_valid(0)` selects EXT0/EXT1 by `cfg_in_port`; `port_ts(0)` uses data `[86:39]`. | `histogram_statistics/rtl/histogram_statistics_v2.vhd:976-1013` |
| Accept pulse | `accept_pulse(idx) <= sampled_v`; readyless EXT paths sample whenever valid and no apply is pending. | `histogram_statistics/rtl/histogram_statistics_v2.vhd:1293-1349` |
| Write request | In mode 1, key is `GTS - ts_sideband[47:0]`; filter controls whether `ingress_write_req` is asserted. | `histogram_statistics/rtl/histogram_statistics_v2.vhd:889-909`, `:1375-1401` |
| FIFO / arbiter | `ingress_stage_write_req` writes FIFO if not full; rr arbiter forwards to divider. | `histogram_statistics/rtl/histogram_statistics_v2.vhd:1444-1525` |
| Divider | Range check uses active `cfg_left_bound`, `cfg_right_bound`, `cfg_bin_width`; overflow/underflow samples do not write bins. | `histogram_statistics/rtl/histogram_statistics_v2.vhd:1527-1605`, `histogram_statistics/rtl/bin_divider.vhd:139-153`, `:163-172` |
| Queue to SRAM | Only `divider_valid and not underflow and not overflow` becomes `queue_hit_valid`, then drains to `pingpong_sram`. | `histogram_statistics/rtl/histogram_statistics_v2.vhd:1607-1644`, `:1766-1783` |

### Missing Knob

The previous scout windows changed `LEFT_BOUND` and `BIN_WIDTH` but did not
program `RIGHT_BOUND`. In the loaded RTL, `cfg_right_bound` is copied from
`csr_right_bound` on `CONTROL.apply`; it is not recomputed from
`LEFT_BOUND + BIN_WIDTH * N_BINS` at apply time
(`histogram_statistics/rtl/histogram_statistics_v2.vhd:2027-2045`,
`:2138-2143`).

The smoking-gun pre-snapshot before this experiment was:

| CSR | Value | Meaning |
|---|---:|---|
| `LEFT_BOUND` | `0x00018000` | Last previous scout left bound. |
| `BIN_WIDTH` | `0x00000080` | 128-cycle scout width. |
| `RIGHT_BOUND` | `0x00000100` | Stale reset/default 256-cycle right edge. |

So the supposed wide windows were not real 32k windows. Samples were accepted by
the front end, then dropped by the divider range gate before bin write.

## Unit B - Single CSR Experiment

Experiment knob: explicitly write `RIGHT_BOUND = LEFT_BOUND + 256*BIN_WIDTH`
before `CONTROL.apply`.

ASIC0 Type1-up / EXT0 configuration:

| Field | Value |
|---|---:|
| `LEFT_BOUND` | `0` |
| `RIGHT_BOUND` | `32768` (`0x00008000`) |
| `BIN_WIDTH` | `128` |
| `KEY_VALUE` | `0` |
| `CONTROL` | `0x00010115` write, readback `0x00010114` |
| `INTERVAL_CFG` | `125000000` unchanged |
| Injector | mode 1, header interval 1, multiplicity 1, header delay 100, header ch 0, pulse high 5 |

Result:

| Snapshot | Underflow | Overflow | Total hits | Last interval hits | Bank status | Bin sum |
|---|---:|---:|---:|---:|---:|---:|
| active after 5 s | `0` | `0` | `0x000FFFFF` | `0x000FFFFF` | `0x00000001` | not read live |
| post stop | `0` | `0` | `40` | `0x000FFFFF` | `0x00000000` | `2178544` |

`TOTAL_HITS` / `LAST_INTERVAL_TOTAL_HITS` saturated at `0x000FFFFF`, so the
bin sum can exceed the stats counter. The important change is that bins now
contain counts and underflow/overflow remain zero for the wide window.

Top bins:

| Bin | Cycle range | Count |
|---:|---:|---:|
| 8 | `1024..1151` | `302581` |
| 9 | `1152..1279` | `302433` |
| 10 | `1280..1407` | `301715` |
| 11 | `1408..1535` | `299468` |
| 7 | `896..1023` | `297878` |

CSV:

- `unit_b_asic0_rightbound_knob_bins.csv`

Verdict: **YES - bins now show counts.** The visibility bug is the missing
explicit `RIGHT_BOUND` write, not ping-pong bank selection and not a missing
interval pulse.

## Unit C - ASIC0 Calibration

Refine pass used `LEFT_BOUND=896`, `RIGHT_BOUND=1152`, `BIN_WIDTH=1`.

| Metric | Value |
|---|---:|
| Peak cycle | `1032` |
| Peak count | `2655` |
| Weighted center | `1023.75` cycles |
| Captured-window FWHM | `256` cycles |
| Bin sum | `592818` |
| Active underflow | `288455` |
| Active overflow | `547361` |
| Left edge count | `2447` |
| Right edge count | `2146` |

The 1-cycle refine window is clipped: both edge bins are nonzero and active
underflow/overflow counts are large. Treat `FWHM=256` as a lower bound, not the
true ASIC0 width. The center is stable around cycle `1024`.

CSV:

- `unit_c_asic0_refine_left896_width1_bins.csv`

## Overall Verdict

**HIST_VISIBILITY_FIXED with explicit RIGHT_BOUND programming.**

For every histogram window, software must program all three range CSRs before
`CONTROL.apply`:

```text
LEFT_BOUND  = left
BIN_WIDTH   = width
RIGHT_BOUND = left + N_BINS * width
```

The next calibration round should keep this knob and either:

1. run ASIC0 with a wider high-resolution sweep around `512..1664` to measure
   the true FWHM without clipping, then
2. loop ASIC1..6 with the same explicit `RIGHT_BOUND` programming and the
   calibrated Type1 filter settings.

Final run-control status:

```text
RESET_LINK_STATUS_REGISTER_R = 0x13000000
last state byte              = 0x13 (end-run)
```
