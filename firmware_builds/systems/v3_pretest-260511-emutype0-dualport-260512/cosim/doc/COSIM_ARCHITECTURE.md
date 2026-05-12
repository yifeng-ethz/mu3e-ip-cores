# FEB to SWB Cosim Architecture

## Active harness choice

The cosim lives beside the latest dualport FEB build:

- FEB parent build: `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512`
- FEB cosim target: `tb_int/feb_swb_corun`
- SWB tb_int target: `firmware_builds/systems/swb/rdma_pretest-260511/tb_int`

The older `v3_pretest-260511` tb_int remains the TEST_PLAN reference floor. The
`system_20260504_emulator_type0/tb_int/feb_swb_corun` tree is used as the
tracked corun reference. The dualport `v3_pretest-260511-emutype0-dualport-260512`
tree is the target because it matches the current dualport histogram topology
and the validated on-board sweep evidence from 2026-05-12.

## SWB post-XCVR ingress discovery

The active SWB build is
`firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10`.

The FEB-facing ingress is `XCVR0`, not `XCVR1`.

| Item | Value |
|---|---|
| Boundary | `a10_block.generate_xcvr0_fifo(i).e_xcvr0_fifo.e_rx_fifo` |
| FIFO IP | `xcvr_fifo.vhd` wrapping `ip_dcfifo_v2` |
| FIFO parameters | `g_BYTES=4`, `g_DATA_WIDTH=36`, `g_FIFO_ADDR_WIDTH=6` |
| Write side | XCVR recovered fabric, `i_xcvr_clk=clk_156` |
| Write frequency | 156.25 MHz |
| Read side | SWB fabric, `i_clk=i_xcvr0_clk`, mapped from top-level `pcie0_clk` |
| Read frequency | 250 MHz |
| Raw width | 32 data bits plus 4 datak bits |
| AVST ready | No explicit ready at this post-XCVR stream; FIFO emits idles when empty |

The user hypothesis is therefore mostly correct: the active SWB boundary already
contains a dual-clock FIFO. The precise FIFO is the RX half of `xcvr_fifo`, with
`ip_dcfifo_v2` carrying 36 bits from 156.25 MHz into the 250 MHz SWB fabric.

## Signal mapping

FEB egress is represented by the cosim waveform record, not by a transaction
object. The monitor samples every FEB clock cycle.

| FEB waveform field | Source |
|---|---|
| `data[31:0]` | FEB AVST data word |
| `valid` | FEB AVST valid |
| `sop` | FEB start-of-packet |
| `eop` | FEB end-of-packet |
| `channel` | FEB lane index |
| `error` | 0 in the current corun harness; reserved for real AVST error |
| `ready` | FEB AVST ready |
| `datak[3:0]` | Mu3e 32-bit link K-code sideband |
| `sample_time` | Simulator time at the clock edge |

SWB ingress is the post-XCVR, post-FIFO fabric-side link stream.

| SWB ingress field | Source |
|---|---|
| `data[31:0]` | `feb_rx(i).data` after `to_link` |
| `valid` | Non-idle replay beat from cosim driver |
| `sop` | K28.5 frame start or explicit sideband in the harness |
| `eop` | K28.4 frame end or explicit sideband in the harness |
| `channel` | SWB logical FEB link index |
| `error` | `link32_t.err` when available; 0 in the current wrapper |
| `ready` | Always accepted at this boundary |
| `datak[3:0]` | `feb_rx_datak(i)` after `xcvr_fifo` |

## Packet steering

The SWB fabric steers packets inside `swb_block.vhd`:

- `swb_data_demerger` splits each `feb_rx(i)` stream into data, slow control,
  and run control streams.
- Hit packets flow through `rx_data` into `ingress_egress_adaptor`, OPQ, and the
  RDMA bridge.
- Slow-control packets flow through `rx_sc` into `swb_sc_main` /
  `swb_sc_secondary`.
- Run-control packets flow through `rx_rc` into `run_control`.

The cosim `cosim_packet_steering_monitor` counts packet starts and classifies
the hit stream by the SciFi packet header (`header_id=6'b111000`). The 1 ms
sanity is hit-only, so SC and RC counts must remain zero.

## Metadata contract

The waveform remains the protocol. Per-hit ground truth travels on a separate
analysis stream:

- `hit_id`: monotonically assigned at FEB hit creation.
- `ts_birth`: simulator time at hit creation.
- `channel`: original channel inside the ASIC/lane.
- `lane`: FEB/SWB logical lane.

The SWB side consumes metadata without recomputing `ts_birth`. All lifetime
checkpoints report `ts_checkpoint - ts_birth`.
