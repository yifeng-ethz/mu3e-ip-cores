# `arb_hit_type0`

Per-lane arbiter on the post-deassembly hit_type0 boundary. Selects between
the real MuTRiG hit_type0 stream (`mutrig_frame_deassembly.aso_hit_type0`) and
the emulator hit_type0 stream (`emulator_mutrig.aso_hit_type0` when built with
`BYTE_STREAM_ENABLE = 0` per `emulator_mutrig/doc/RTL_PLAN_central_trigger.md`).

## Modes

| Mode | Encoding | Behaviour |
|---|---:|---|
| `REAL` | `2'b00` | drains real-input FIFO only |
| `EMU` | `2'b01` | drains emulator-input FIFO only |
| `MIX_RR` | `2'b10` | round-robin between sources at packet boundary |

Mode change is deferred until the active source is between packets so SOP/EOP/EOR atomicity is preserved end-to-end.

## Per-instance resources

- 16-deep ingress FIFO per source (real and emulator)
- 64-bit saturating counters with `_L`/`_H` pair atomicity (latched-on-read):
  - `INGRESS_REAL_HITS`, `INGRESS_EMU_HITS`
  - `DROPS_REAL`, `DROPS_EMU`
  - `EGRESS_REAL_HITS`, `EGRESS_EMU_HITS`
- AVMM CSR slave, 4-bit word address, 32-bit data, single clock domain

The CSR map and wave-level field meaning live in `arb_hit_type0_hw.tcl` (owned
by the `ip-packaging` skill). DV bucket files do not duplicate the CSR map.

## Documentation

- [`doc/RTL_PLAN.md`](doc/RTL_PLAN.md) — architecture, resource and timing model
- [`tb/DV_PLAN.md`](tb/DV_PLAN.md) — verification plan
- [`tb/DV_HARNESS.md`](tb/DV_HARNESS.md) — UVM harness architecture
- [`tb/DV_BASIC.md`](tb/DV_BASIC.md), [`tb/DV_EDGE.md`](tb/DV_EDGE.md), [`tb/DV_PROF.md`](tb/DV_PROF.md), [`tb/DV_ERROR.md`](tb/DV_ERROR.md), [`tb/DV_CROSS.md`](tb/DV_CROSS.md) — bucket files
- [`tb/DV_COV.md`](tb/DV_COV.md) — coverage tracking
- [`tb/BUG_HISTORY.md`](tb/BUG_HISTORY.md) — append-only bug log

## System-level integration

The IP is wired into the focused single-lane bring-up build
`top_nostp_emulator_type0` documented at
[`firmware_builds/systems/system_20260504_emulator_type0/doc/SYSTEM_PLAN.md`](../../firmware_builds/systems/system_20260504_emulator_type0/doc/SYSTEM_PLAN.md).
That build is **not** derived from the legacy 8-lane scifi system; it is a
focused topology with known-good SC and RC paths and a single ASIC0 / lane 0
datapath, used to compare a real-MuTRiG golden reference against the emulator
output stage by stage.
