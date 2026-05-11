# REPORT - E066

- bucket: `EDGE`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_e066.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_e066_test.sv`
- run: `make run_E066`

## Scenario

maximum legal RQE packet at host segment boundary

## Stimulus

drive one maximum-size legal RQE and matching completion

## Pass Criteria

RQE and CQE lineage closes while the DMA burst stays segment-local

## Evidence

- Transcript: `tb_int/sim/E066/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
