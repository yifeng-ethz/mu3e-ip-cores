# REPORT - P065

- bucket: `PROF`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_p065.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_p065_test.sv`
- run: `make run_P065`

## Scenario

scaled 100 kHz/channel x 4 lanes PROF smoke

## Stimulus

drive a scaled four-lane load preserving the 100 kHz/channel ratio

## Pass Criteria

accepted, dropped, and emitted counts reconcile with zero drops

## Evidence

- Transcript: `tb_int/sim/P065/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
