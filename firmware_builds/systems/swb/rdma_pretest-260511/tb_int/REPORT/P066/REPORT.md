# REPORT - P066

- bucket: `PROF`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_p066.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_p066_test.sv`
- run: `make run_P066`

## Scenario

host CQE turnaround under balanced four-lane load

## Stimulus

drive 64 RQEs with matching CQEs under balanced four-lane pressure

## Pass Criteria

sidecar lineage closes and host DMA events remain bounded

## Evidence

- Transcript: `tb_int/sim/P066/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
