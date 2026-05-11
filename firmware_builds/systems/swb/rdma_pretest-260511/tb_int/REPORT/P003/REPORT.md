# REPORT - P003

- bucket: `PROF`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_p003.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_p003_test.sv`
- run: `make run_P003`

## Scenario

watchdog overlap while OPQ drains under load

## Stimulus

overlap watchdog service with a draining OPQ burst

## Pass Criteria

emitted and dropped counts reconcile while DMA events remain closed

## Evidence

- Transcript: `tb_int/sim/P003/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
