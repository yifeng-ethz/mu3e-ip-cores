# Phase 6 RTL ASIC0 Emulator Groups - 2026-05-02

## Scope

This report is local RTL integration evidence from `tb_int`; it is not board
evidence. The bench ticket for updated hardware plots is queued behind the
active hardware capture ticket.

All cases use:

- `TB_DP_SOURCE_OVERRIDES=1`
- `TB_DP_ACTIVE_LANE_MASK=0x01`
- real/LVDS lanes forced off in the testbench
- injector fanout enabled, with all non-ASIC0 emulators disabled

Raw artifacts:

- `model/phase4/inputs/rtl_asic0_emulator_groups_20260502/`
- `reports/assets/phase6_rtl_asic0_emulator_groups_20260502/rtl_asic0_emulator_groups.html`
- `reports/assets/phase6_rtl_asic0_emulator_groups_20260502/rtl_asic0_emulator_group_stats.json`

## Header-Sync Delay Multiplicity

![RTL ASIC0 header multiplicity latency](assets/phase6_rtl_asic0_emulator_groups_20260502/rtl_asic0_header_multiplicity_latency.png)

![RTL ASIC0 header multiplicity width](assets/phase6_rtl_asic0_emulator_groups_20260502/rtl_asic0_header_multiplicity_width.png)

| Multiplicity | Accepted hits | Active channel bins | Latency samples | Latency min | Latency max | Active latency bins |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 54 | 1 | 0 | n/a | n/a | 0 |
| 2 | 108 | 2 | 54 | 813 | 813 | 1 |
| 3 | 162 | 3 | 108 | 813 | 818 | 2 |
| 4 | 216 | 4 | 162 | 813 | 823 | 3 |
| 5 | 270 | 5 | 216 | 813 | 828 | 4 |

Interpretation:

- The hit count scales exactly with requested multiplicity: `54 * M`.
- The latency span prolongs monotonically by one emitted hit per cycle:
  multiplicity 2..5 produces 1..4 active latency bins.
- Multiplicity 1 has valid accepted-hit counts but zero dispatch-latency samples
  in this monitor because the latency queue pairs queued cluster hits after the
  first egress word.

## Periodic Rate Sweep

![RTL ASIC0 periodic rate saturation](assets/phase6_rtl_asic0_emulator_groups_20260502/rtl_asic0_periodic_rate_saturation.png)

![RTL ASIC0 periodic channel rates](assets/phase6_rtl_asic0_emulator_groups_20260502/rtl_asic0_periodic_channel_rates.png)

| Request | Period cycles | Expected hits | Observed hits | Observed kHz/ch | Active bins | Hist dropped | Hist under | Hist over |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 10k | 12500 | 310 | 310 | 10.000 | 31 | 0 | 0 | 0 |
| 100k | 1250 | 3100 | 3100 | 100.000 | 31 | 0 | 0 | 0 |
| 500k | 250 | 15500 | 8695 | 280.484 | 31 | 0 | 0 | 0 |
| 1M | 125 | 31000 | 8695 | 280.484 | 31 | 0 | 0 | 0 |

Interpretation:

- ASIC0 isolation is correct: all runs report zero hits on lanes 1..7.
- The rate path is exact at 10 kHz/channel and 100 kHz/channel.
- The 500 kHz/channel and 1 MHz/channel requests saturate at about
  `280.5 kHz/channel` for this RTL integration path and run window.
- Histogram CSR status remains clean (`dropped=0`, `under=0`, `over=0`) in all
  four rate cases. The high-rate trace mismatch counters are diagnostic queue
  artifacts from the non-trace closure monitor and are not used as timestamp
  equivalence evidence.

