# Phase 6 ASIC0 MuTRiG Emulator Groups - 2026-05-02

## Scope

This report uses the existing ASIC0 MuTRiG emulator JTAG histogram CSV captures
from `reports/phase6_emulator_asic0_*_cluster31_20260502.*`. No new live
hardware access was taken while regenerating these figures.

Rendered artifacts:

- `reports/assets/phase6_emulator_asic0_20260502/phase6_emulator_asic0_groups.html`
- `reports/assets/phase6_emulator_asic0_20260502/phase6_emulator_asic0_group_stats.json`

The current capture uses cluster size 31 because the programmed 5-bit cluster
CSR wraps 32 to 0 in this image.

## Periodic Rate Group

![ASIC0 emulator rate group](assets/phase6_emulator_asic0_20260502/phase6_emulator_asic0_rate_group.png)

![ASIC0 emulator rate saturation](assets/phase6_emulator_asic0_20260502/phase6_emulator_asic0_rate_saturation.png)

| Request | Target kHz/ch | Observed mean kHz/ch | Min kHz/ch | Max kHz/ch | Total hits | Nonzero bins |
|---:|---:|---:|---:|---:|---:|---:|
| 10k | 10.000 | 9.999 | 9.999 | 9.999 | 309969 | 31 |
| 100k | 100.000 | 99.840 | 99.840 | 99.840 | 3095040 | 31 |
| 500k | 500.000 | 163.891 | 108.807 | 232.335 | 5080635 | 31 |
| 1M | 1000.000 | 163.891 | 40.005 | 297.815 | 5080635 | 31 |

Interpretation:

- The 10 kHz/channel and 100 kHz/channel periodic points track the request.
- The 500 kHz/channel and 1 MHz/channel requests saturate at the same aggregate
  count in this image, with a channel-dependent occupancy slope.

## Header-Sync Delay Multiplicity Group

![ASIC0 emulator delay multiplicity](assets/phase6_emulator_asic0_20260502/phase6_emulator_asic0_delay_multiplicity.png)

| Multiplicity | Total hits | Nonzero bins | Peak center | q05 | q95 | q95-q05 | In [0,2000] | In % | Out % | Low out | High out |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 2499995 | 12 | 1072.0 | 1072.0 | 1232.0 | 160.0 | 2499995 | 100.000000 | 0.000000 | 0 | 0 |
| 2 | 4999990 | 21 | 1232.0 | 1088.0 | 1376.0 | 288.0 | 4999990 | 100.000000 | 0.000000 | 0 | 0 |
| 3 | 4999990 | 21 | 1232.0 | 1088.0 | 1376.0 | 288.0 | 4999990 | 100.000000 | 0.000000 | 0 | 0 |
| 4 | 5067281 | 23 | 1232.0 | 1088.0 | 1392.0 | 304.0 | 4999988 | 98.672010 | 1.327990 | 0 | 67293 |
| 5 | 5067281 | 23 | 1232.0 | 1088.0 | 1392.0 | 304.0 | 4999988 | 98.672010 | 1.327990 | 0 | 67293 |

Interpretation:

- The delay block widens from multiplicity 1 to 2, then plateaus for 2/3 and
  again for 4/5 in this programmed image.
- The delay population is inside the rbCAM [0,2000] cycle window for
  multiplicities 1..3. Multiplicities 4 and 5 have a 1.328% high-side out tail.
