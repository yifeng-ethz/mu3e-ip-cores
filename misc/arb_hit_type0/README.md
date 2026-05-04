# `arb_hit_type0`

Per-lane arbiter on the post-deassembly hit_type0 boundary. Selects between
the real MuTRiG hit_type0 stream (`mutrig_frame_deassembly.aso_hit_type0`) and
the emulator hit_type0 stream (`emulator_mutrig.aso_hit_type0` when built with
`BYTE_STREAM_ENABLE = 0` per `emulator_mutrig/doc/RTL_PLAN_central_trigger.md`).

## Modes

| Mode | Encoding | Behaviour |
|---|---:|---|
| `REAL` | `2'b00` | drains real-input FIFO only; single-channel egress |
| `EMU` | `2'b01` | drains emulator-input FIFO only; single-channel egress |
| `MIX_RR` | `2'b10` | **beat-level** round-robin combined with a **merge-packet FSM** that rewrites egress `sop`/`eop`/`eor` so the consumer sees one merged Avalon-ST packet per `merged_open` window. Per-beat `channel` still disambiguates source. |

Mode-switch transitions are deferred until `merged_open == 0` (both source `_open` flags are 0) so SOP/EOP/EOR balance is preserved.

> ⚠ **MIX_RR requires per-beat `channel` demultiplex support at the downstream consumer.** Egress is a single merged Avalon-ST packet, so single-packet boundary tracking is sufficient and any consumer that handles the single-source case still works. To separate per-source contributions inside the merged packet (e.g. for golden-reference plotting per source), the consumer must read `channel` per beat. The `mts_processor.hit_type0_in` (`maxChannel = 63`) and `ring_buffer_cam.hit_type1` (`maxChannel = 15`) interfaces declare per-beat `channel`; the implementation of per-beat channel use inside those IPs must be independently verified before MIX_RR is promoted to a production datapath. See `doc/RTL_PLAN.md` §2.2.

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
