# Integration Harness: SWB rdma_pretest-260511

**DUT:** SWB Arria 10 DE5 `top`
**Date:** 2026-05-11
**Parent:** [DV_INT_PLAN.md](DV_INT_PLAN.md)
**Status:** Draft

## 1. Top

`tb_int/uvm/swb_rdma_pretest/tb_int_top.sv` instantiates the staged SWB
`top` entity and declares bind-facing interfaces for RDMA SQE ingress, OPQ
lane observation, and PCIe x8 DMA egress.

## 2. Reuse

`tb_int/uvm/common/` is copied from the May 4 integration reference. The SWB
layer reuses the run-window database, hit records, tap interfaces, and
per-bucket ledger scoreboard contract.

## 3. First Smoke

`B065` is the first implemented BASIC case. It checks the local synthesis tree
and records the expected `1/0/0` per-stage ledger closure: one observed event,
zero errors, and zero drops at each observed stage.

## 4. Expansion

The structural smoke is the bring-up seed. Live UVM bind refinement must keep
the same case IDs and replace only the source of the ledger observations.
