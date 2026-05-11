# REPORT - E033

- bucket: `EDGE`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_e033.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_e033_test.sv`
- run: `make run_E033`

## Scenario

OPQ ticket FIFO full boundary

## Stimulus

fill the structural OPQ ticket boundary model to the selected limit

## Pass Criteria

accepted and emitted OPQ counts match without overflow

## Evidence

- Transcript: `tb_int/sim/E033/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
