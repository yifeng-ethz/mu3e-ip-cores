# REPORT - E002

- bucket: `EDGE`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_e002.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_e002_test.sv`
- run: `make run_E002`

## Scenario

state CSR co-write during RUN_PREP edge

## Stimulus

co-write the state CSR while the reset-link edge is sampled

## Pass Criteria

the structural state shadow resolves to one legal value with no duplicate transition

## Evidence

- Transcript: `tb_int/sim/E002/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
