# Integration Testbench: `swb/rdma_pretest-260511/tb_int/`

**DUT:** SWB Arria 10 DE5 `top` from `firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10/`
**Companion docs:** [DV_BASIC.md](DV_BASIC.md), [DV_EDGE.md](DV_EDGE.md), [DV_ERROR.md](DV_ERROR.md), [DV_PROF.md](DV_PROF.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Reference:** `firmware_builds/systems/v3_pretest-260511/tb_int/doc/DV_INT_PLAN.md` (FEB v3_pretest-260511 dual-env structural parent)
**Author:** Mu3e IP team.
**Date:** 2026-05-11
**Status:** Draft. SWB BASIC smoke is the first implemented case.

The staged board project and generated local Qsys synthesis outputs are the
canonical DUT inputs for this integration TB.

---

## 1. Purpose & Scope

`tb_int/` verifies the SWB-side RDMA pretest build staged from
`online_sc/online/switching_pc/a10_board` into this repository. The scope is
the Arria 10 DE5 SWB system with PCIe x8 host access, OPQ four-lane native_sv
at the deployed `0x800`-frame observation depth, and the `rdma_subsystem` on
both the FEB-to-SWB bridge ingress and the SWB-to-host DMA push path.

The integration target is not a standalone IP model. It must compile against
the staged board sources plus local Qsys-generated synthesis outputs so that
bridge wiring, clock/reset fanout, generated wrappers, and DMA endpoints are
observed as deployed.

In scope:
- Run-control propagation from the SWB reset-link transmitter into FEB
  run-state intent and into SWB-local run-control consumers.
- Host slow-control over `/dev/mudaq0` through the SWB AVMM master and
  `sc_hub_v2` path, with local JTAG as a limited debug fallback.
- SWB datapath tracking from FEB-to-SWB RDMA SQE ingress through OPQ,
  `musip_event_builder`, `swb_data_demerger`, `hit_compactor`, and host DMA.
- Per-stage queue and sidecar observability at the DEBUG_LEVEL values in
  section 2.3.
- BASIC/EDGE/ERROR/PROF bucket execution modes required by `dv-workflow`.

Out of scope:
- Full Quartus map/fit/asm timing closure for this turn.
- On-board programming and hardware bring-up.
- Moving vendor PLL, XCVR, or PCIe Platform Designer IPs into the central
  `quartus_systems/swb/` hub.

## 2. UVM Infra (dual env)

The SWB integration TB mirrors the FEB dual-env pattern:

1. `tb_int_nominal_env` observes synthesizable payload and counter fields.
   It is the default scoreboard path and must work with DEBUG_LEVEL 0/1
   production-style builds.
2. `tb_int_debug_env` observes DEBUG_LEVEL 2 sidecar lineage at the SWB
   ingress bridge and RDMA DMA path. It explains queue residency and packet
   identity when out-of-order buffering is legal.

Both envs share `tb_int_top`, `run_window_db`, `per_bucket_ledger_scoreboard`,
and the reusable common monitors copied from the May 4 integration reference.
SWB-specific bind interfaces live under `tb_int/uvm/swb_rdma_pretest/`.

### 2.1 Agents

| Agent | Direction | Role |
|---|---|---|
| `swb_runctl_agent` | active | Drives the SWB-local run-state model and records propagated state at local consumers. |
| `swb_sc_agent` | active | Models host PCIe `sc_tool` transactions over `/dev/mudaq0` into the SWB AVMM master. |
| `rdma_sqe_ingress_monitor` | passive | Samples FEB-to-SWB SQE ingress at the SWB-side `rdma_subsystem` boundary. |
| `opq_lane_monitor[4]` | passive | Samples one or more OPQ four-lane native_sv ingress/egress fill points. |
| `event_builder_monitor` | passive | Tracks `musip_event_builder` host-packet packing and close events. |
| `demerger_monitor` | passive | Tracks `swb_data_demerger` split/fanout accounting. |
| `pcie_x8_egress_monitor` | passive | Samples the OPQ/event-builder-to-PCIe DMA egress event path. |
| `debug_sidecar_monitor` | passive | Samples DEBUG_LEVEL 2 sidecar lineage at the RDMA bridge and DMA engine. |

### 2.2 Scoreboard

The SWB scoreboard is a per-stage ledger:
- FEB-to-SWB SQE ingress accepted count.
- OPQ accepted, dropped, and emitted count by lane.
- Event-builder host-packet close count and byte count.
- DMA beat count, end-of-event count, and PCIe egress event count.

The BASIC smoke contract is `1/0/0` at each observed stage: one legal event,
zero errors, and zero drops. Any mismatch between nominal payload accounting and
DEBUG_LEVEL 2 sidecar lineage is a closure blocker.

### 2.3 DEBUG_LEVEL regulation per IP

| IP | DEBUG_LEVEL | Observable |
|---|:-:|---|
| `rdma_subsystem` | 2 | SQ/CQ ring plus per-hit sidecar at SWB ingress |
| `rdma_dma_engine` | 2 | DMA descriptor sidecar plus queue fill |
| `ordered_priority_queue_native_sv_fixed4` | 1 | frame-level fill through page RAM occupancy and ticket FIFO |
| `musip_event_builder` | 1 | per-host packet fill |
| `swb_data_demerger` | 1 | demerger fill |
| `swb_rdma_subsystem_bridge` | 2 | per-SQE sidecar lineage |
| `hit_compactor` | 1 | compactor stage fill |
| `pcie_x8_256` | 0 | DMA endpoint; no direct simulation observable |
| `a10_block` | 0 | board glue verified through neighboring observables |

Rules:
- DEBUG_LEVEL 2 is cumulative and includes DEBUG_LEVEL 1 fill observability.
- DEBUG_LEVEL 1 signals are legal in production-oriented builds.
- DEBUG_LEVEL 0 IPs are verified through upstream/downstream ledger closure.

### 2.4 Coverage

Coverage is tracked by counters and case reports:
- Run-state pair coverage and stable-window markers.
- Host slow-control read/write completion by SWB-local slave.
- SQE ingress, OPQ lane, event-builder packet, and PCIe DMA event ledgers.
- DEBUG_LEVEL 2 sidecar presence and identity match where exposed.
- Isolated, `bucket_frame`, and `all_buckets_frame` execution modes.

## 3. Test Buckets

| Bucket | RC | SC | DT | Total | Goal |
|---|---:|---:|---:|---:|---|
| BASIC | 32 | 32 | 128 | **192** | Happy-path SWB RC, SC, and DT smoke/nominal cases |
| EDGE | 32 | 32 | 128 | **192** | Legal boundaries for run-state phasing, control access, OPQ, packing, and DMA |
| ERROR | 32 | 32 | 128 | **192** | Fault injection and recovery |
| PROF | 32 | 32 | 128 | **192** | Sustained rate, queue-depth, and host-DMA performance |

### 3.1 RC (run-control)

Nominal SWB run-control is the SWB reset-link transmitter driving FEB
run-state intent while SWB-local run-control is propagated to local IPs through
the SWB-internal runctl bus.

#### 3.1.1 Pre-`RUNNING` sequence (NOMINAL = reset link)

All DT and PROF cases bring the system to `RUNNING` through the nominal
reset-link path with software-scale gaps between adjacent state writes. The
scoreboard opens the stable window only after the SWB-local state shadow and
the FEB-directed run-state intent agree.

#### 3.1.2 CSR-toggle RC fallback (LIMITED)

The SWB-local CSR-toggle path is a debug fallback for a limited subset of
BASIC and EDGE cases. It proves the fallback reaches the local run-state shadow
but does not replace the deployed reset-link path for datapath regression.

### 3.2 SC (slow-control)

#### 3.2.1 SC ingress (NOMINAL = PCIe host)

Nominal slow-control uses host PCIe `sc_tool` over `/dev/mudaq0`, then the SWB
AVMM master, then `sc_hub_v2` at SWB. All bucket cases use this path unless
they are explicitly part of the local JTAG fallback subset.

#### 3.2.2 JTAG-master SC fallback (LIMITED)

The SWB-local JTAG master is a limited debug fallback. It is used only to prove
that one identity read and one simple round-trip can be performed when the host
PCIe path is unavailable.

### 3.3 DT (datapath)

The DT bucket focuses on:
- SWB ingress from FEB-to-SWB RDMA SQEs.
- OPQ four-lane native_sv ordering and fill.
- Event-builder host-packet packing.
- RDMA host DMA push into the PCIe x8 endpoint path.
- PCIe endpoint sanity through a level-0 endpoint with the monitor bound at
  the OPQ/event-builder egress side.

## 4. Bring-up Order

1. Generate the local Qsys synthesis outputs.
2. Run BASIC B065 structural smoke against the staged synthesis tree.
3. Expand BASIC RC and SC cases until the no-restart `bucket_frame` run is
   legal.
4. Add EDGE boundary cases.
5. Add ERROR recovery cases.
6. Add PROF sustained-rate cases.
7. Run `all_buckets_frame` as the final integration signoff mode.

## 5. Outputs

Expected per-run artifacts:
- `tb_int/sim/logs/basic_bucket_sweep.log`.
- `tb_int/sim/logs/swb_basic_b065_smoke.log`.
- Per-case result rows with status, evidence path, and ledger residuals.
- Future UCDB outputs under `tb_int/sim/cov/` once the full Questa harness is
  enabled.

## 6. Reuse contract

Reused from `firmware_builds/systems/system_20260504_emulator_type0/tb_int/uvm/common/`:
- `per_bucket_ledger_scoreboard`.
- `run_window_db`.
- `hit_record`, `hit_key_pkg`, and basic tap interfaces.
- Existing monitor scaffolding where the signal contract matches.

SWB-specific layer:
- `tb_int_top.sv`.
- `rdma_sqe_ingress_if.sv`.
- `opq_lane_if.sv`.
- `pcie_x8_egress_if.sv`.
- `tb_int_base_test.sv`.
- `tb_int_smoke_test.sv`.

## 7. Implementation pointer

The first runnable target is BASIC B065. It performs a structural smoke against
the staged local synthesis tree and then checks the expected `1/0/0` per-stage
ledger closure for SWB ingress, OPQ, and PCIe-egress observables. Later UVM
implementation must replace the structural ledger source with live passive
monitors without changing the case IDs or pass criteria.

## 8. Plan drift

When implementation diverges from this document, update the plan before adding
new evidence. This plan is the SWB integration contract for
`rdma_pretest-260511`.
