# BUG_HISTORY.md - SWB rdma_pretest 260518-swb-ok bug ledger

This ledger records bugs found and fixed against the SWB A10 build that this
260518-swb-ok system carries.  It is the system-doc-level summary; the
per-scenario evidence ledger continues to live in
`tb_int/doc/BUG_HISTORY.md`.

Class legend:
- `R` = RTL / DUT bug in an IP shipped on this build
- `H` = harness / testcase / reporting bug
- `I` = integration / Qsys / wiring bug at the SWB board level

Severity legend:
- `soft error` = the bad packet/data flushes through and does not leave the
  later datapath stuck
- `hard stuck error` = the bug poisons later handling and typically needs a
  functional reset / fresh restart to recover
- `non-datapath-refactor` = packaging, observability, reporting, harness, or
  metadata work with no direct packet-contract effect

## Index

| bug_id | class | severity | encounterability | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| [BUG-001-R](#bug-001-r-swb-opq-egress-advanced-independently-of-rdma-packer-backpressure) | R | hard stuck error | `common (every SWB OPQ-to-DMA push under host TX stalls)` | fixed-rtl / board-rerun-pending | SWB OPQ frame timestamp UVM smoke, 2026-05-17 | `f2cfccfa` | The SWB OPQ output advanced independently of the RDMA packer ready state, so a disabled or backpressured packer could leave accepted OPQ words without matching packed output framing. |
| [BUG-002-R](#bug-002-r-swb-pcie-app-let-posted-writes-and-rx-parser-bypass-completer-credit) | R | hard stuck error | `common (posted host writes and BAR request bursts under HIP TX stalls)` | fixed-rtl / board-rerun-pending | `B065_HOST_REALISTIC` + `PCIE_COMPLETER_RREG_FIFO_LOSS`, 2026-05-17 | `6ccc5ae5` | The legacy PCIe APP let DMA / controlinfo sources advance on raw HIP ready without the matching source grant, and the RX parsers accepted BAR request beats without reserving completer FIFO entries; CQE and other posted host writes could disappear without an ACK. |

## 2026-05-17

### BUG-001-R: SWB OPQ egress advanced independently of RDMA packer backpressure

- First seen in:
  - SWB OPQ frame timestamp UVM smoke under
    `firmware_builds/systems/swb/rdma_pretest-260511/tb_int`
    (`make run_OPQ_FRAME_TS_SMOKE`).
- Symptom:
  - With the RDMA packer disabled or backpressured, OPQ accepted words
    advanced past the packer boundary without a matching packed-output
    framing on the downstream RDMA stream.
  - K28.4 trailers could carry stale payload bits because the trailer cleaner
    was tied to the packer ready / valid handshake that was not being
    enforced.
- Root cause:
  - The SWB OPQ egress stream advanced independently of the RDMA packer ready
    state.  There was no explicit `ready / valid` boundary between
    `swb_opq_dma_pipeline` and the RDMA packer, so a disabled or
    backpressured packer could not stop OPQ from consuming a word from the
    upstream OPQ queue.
- Fix:
  - Route the OPQ output through an explicit `ready / valid` boundary so
    downstream stalls cannot consume packet words early.
  - Clean K28.4 trailer payload bits at the packer output so trailer-only
    cycles do not carry stale data.
  - Expose the packer-credit counters through the existing SWB status
    registers for board-side observability.
- Reproduction:
  - `make QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim run_OPQ_FRAME_TS_SMOKE`
    under `firmware_builds/systems/swb/rdma_pretest-260511/tb_int`.
  - Questa transcript reports `*** TEST PASSED ***` with
    `UVM_ERROR=0` and `UVM_FATAL=0`.
- Fix files (commit `f2cfccfa`, 5 files, +326 / -130):
  - `firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10/a10/merger/ingress_egress_adaptor.vhd`
  - `firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10/a10/swb/swb_block.vhd`
  - `firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10/a10/swb/swb_opq_dma_pipeline.sv` (new)
  - `firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10/a10/swb/include.qip`
  - `firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10/a10/swb/time_merger_tree.vhd`
- Evidence pinned:
  - `tb_int/doc/BUG_HISTORY.md` records the related `BUG-004-R` K28.4 trailer
    and Idle-SOP audit context.
  - The integration audit performed in this conversation confirms
    `swb_opq_dma_pipeline.sv` (126 lines) and the updated `swb_block.vhd`
    (541 lines, last touched by `07a5f8a4` follow-up debug instrumentation)
    are present in the 260518-swb-ok system source tree.
- Residuals:
  - Board retest on the SWB A10 hardware is still pending.

### BUG-002-R: SWB PCIe APP let posted writes and RX parser bypass completer credit

- First seen in:
  - `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/sim/B065_HOST_REALISTIC/transcript`
  - `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/sim/B066_HOST_REALISTIC/transcript`
  - `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/sim/PCIE_COMPLETER_RREG_FIFO_LOSS/transcript`
- Symptom:
  - Host-realistic tb_int (which now models the rc_tool / dma_tool side as
    PCIe posted Memory Writes into host RQ / CQ memory) observed the host
    RQE post plus PCIe RC and HIP RX MWr checkpoints, then saw no internal
    RQE, no CQE, no HIP TX MWr, and no host CQE observation - CQEs and
    other posted host writes disappeared without an ACK.
  - In `PCIE_COMPLETER_RREG_FIFO_LOSS` the BAR request burst beyond the
    32-entry completer FIFO was accepted and silently dropped before any
    PCIe completion was transmitted.
- Root cause:
  - The legacy PCIe APP let `DMA` / `controlinfo` sources observe raw HIP
    ready without the matching source grant from the arbitration FIFO, so
    posted-write lineage could disappear without an ACK.
  - The RX parser side accepted BAR request beats without reserving
    completer FIFO entries, making all PCIe APP request classes vulnerable
    to silent loss under HIP TX stalls.
- Fix:
  - Gate posted-write source advancement on the owning arbitration credit:
    DMA / controlinfo sources may only advance when they hold the
    arbitration grant.
  - Gate RX parser acceptance on the completer FIFO credit so a BAR request
    is only accepted when there is a guaranteed completer FIFO slot.
  - Regenerate the SWB Qsys outputs to point at the pushed OPQ / RDMA
    submodule fixes.
  - Size the realistic host rxbuffer model for 10 ms of jitter (128 MiB
    aggregate pool with at most two 2 MiB SGL segments per RQE).
- Reproduction (Questa One 2026.1):
  - `make QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim DEBUG_LEVEL=2 run_B065 run_B066`
  - `make QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim DEBUG_LEVEL=2 run_PCIE_COMPLETER_RREG_FIFO_LOSS`
  - `make QUESTA_HOME=/data1/questaone_sim-2026.1_1/questasim DEBUG_LEVEL=2 run_B067 run_B068 run_B069 run_E065`
  - All under `firmware_builds/systems/swb/rdma_pretest-260511/tb_int`.
- Qsys regeneration:
  - `OPQ_SOURCE_ROOT=/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/packet_scheduler bash firmware_builds/systems/swb/rdma_pretest-260511/script/regenerate_swb_qsys.sh`
- Fix files (commit `6ccc5ae5`):
  - Source-of-truth scripts:
    `firmware_builds/systems/swb/rdma_pretest-260511/script/regenerate_swb_qsys.sh`,
    `regenerate_opq_upstream_4lane.tcl`,
    `syn/board_projects/swb_a10/Makefile`.
  - OPQ submodule changes in `packet_scheduler/rtl/sv_ver/.../monolithic_sv/`
    (ingress_parser, page_allocator) propagated via the regenerated Qsys
    artifacts.
- Evidence pinned:
  - `tb_int/doc/BUG_HISTORY.md` records `BUG-009-R` and `BUG-010-R` with the
    full PCIe loss evidence, the OPQ-only-drop rule, and the 10 ms aggregate
    host rxbuffer sizing.
  - `DV_INT_PLAN.md` and `AGENTS.md` document the 128 MiB aggregate
    rxbuffer pool with at most two 2 MiB SGL segments per RQE.
  - The integration audit performed in this conversation confirms the OPQ
    native-SV path `syn/board_projects/swb_a10/a10/merger/qsys/opq_upstream_4lane_native_sv/`
    is present in 260518-swb-ok with the same OPQ IP version `26.5.0.430`
    as the golden lossless SWB build.
- Residuals:
  - Board retest on the SWB A10 hardware is still pending.
