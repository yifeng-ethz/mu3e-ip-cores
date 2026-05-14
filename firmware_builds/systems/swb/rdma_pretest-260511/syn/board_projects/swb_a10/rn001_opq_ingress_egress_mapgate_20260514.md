# RN.BASIC.001 SWB OPQ SignalTap Map Gate - 2026-05-14

## Scope

- Project: `firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10`
- STP: `rn001_opq_ingress_egress.stp`
- Instance: `rn001_opq_ingress_egress`
- Compile log: `codex_swb_opq_stp_imported_fix_compile_20260514_160813.log`

## Probe Set

- Logical probes: 535
- Imported QSF connections:
  - `acq_trigger_in[]`: 535
  - `acq_data_in[]`: 535
  - `acq_clk`: `swb_block:e_swb_block|i_clk`
  - post-fit CRC dynamic pins: 32

The five removed probes were aggregate wrapper vectors that passed
pre-synthesis lookup but failed the imported map gate:

- `swb_block:e_swb_block|opq_dma_status`
- `swb_block:e_swb_block|opq_dma_input_words`
- `swb_block:e_swb_block|opq_dma_output_words`
- `swb_block:e_swb_block|opq_dma_event_count`
- `swb_block:e_swb_block|opq_dma_halt_count`

These were not packet-bearing interface signals. The packet-bearing coverage
kept in the STP is OPQ ingress lanes, raw OPQ egress, registered
OPQ-to-packer handoff, packer control, and 256-bit DMA output payload.

## Map Evidence

`output_files/top.map.rpt` contains:

```text
Info (35024): Successfully connected in-system debug instance "rn001_opq_ingress_egress" to all 1103 required data inputs, trigger inputs, acquisition clocks, and dynamic pins
```

No `; missing ;` SignalTap rows remain in the current map report.

## Current Closure State

This closes the SWB STP compile-gate blocker. Board closure is still open until
the rebuilt image is programmed and two independent STP captures show nonzero
OPQ ingress/egress and DMA-side traffic consistent with RN.BASIC.001 cosim.
