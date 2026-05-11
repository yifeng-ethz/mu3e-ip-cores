# REPORT - B043

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b043.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b043_test.sv`
- run: `make run_B043`

## Scenario

SWB SC single-word RW round-trip on scratch_pad

## Stimulus

write then read one scratch/debug word

## Pass Criteria

readback equals written data and no adjacent slave alias is observed

## Evidence

- Transcript: `tb_int/sim/B043/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
