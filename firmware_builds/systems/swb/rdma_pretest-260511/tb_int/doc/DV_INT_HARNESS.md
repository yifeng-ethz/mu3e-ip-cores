# Integration Harness: SWB rdma_pretest-260511

**DUT:** SWB Arria 10 DE5 `top`
**Date:** 2026-05-11
**Parent:** [DV_INT_PLAN.md](DV_INT_PLAN.md)
**Status:** Draft. Selected 22-case structural UVM sweep implemented.

## 1. Top

`tb_int/uvm/swb_rdma_pretest/tb_int_top.sv` instantiates the staged SWB
`top` entity and declares bind-facing interfaces for RDMA SQE ingress, OPQ
lane observation, and PCIe x8 DMA egress.

## 2. Reuse

`tb_int/uvm/common/` is copied from the May 4 integration reference. The SWB
layer reuses the run-window database, hit records, tap interfaces, and
per-bucket ledger scoreboard contract.

## 3. First Smoke

`B065` is the first smoke case. It checks the UVM shell and records the
expected `1/0/0` per-stage ledger closure: one observed event, zero errors,
and zero drops at each observed stage.

The selected sweep implements 22 cases:
- BASIC: `B001`, `B006`, `B008`, `B033`, `B034`, `B040`, `B043`, `B065`,
  `B066`, `B067`, `B068`, `B069`
- EDGE: `E001`, `E033`, `E043`, `E065`
- ERROR: `X001`, `X033`, `X065`, `X069`
- PROF: `P065`, `P068`

Alias mapping keeps bucket lint legal: `B-RC-CSR-001` is `B008`,
`B-SC-JTG-001` is `B040`, and `E-SC-CONC-001` is `E043`.

## 4. Expansion

The structural sweep is the bring-up seed. Live UVM bind refinement must keep
the same case IDs and replace only the source of the ledger observations.
