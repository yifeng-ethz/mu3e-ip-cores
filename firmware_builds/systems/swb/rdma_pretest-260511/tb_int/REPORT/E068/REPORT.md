# REPORT - E068

- bucket: `EDGE`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_e068.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_e068_test.sv`
- run: `make run_E068`

## Scenario

all-lane cluster burst at CQ turnaround boundary

## Stimulus

drive equal cluster pressure on all four lanes

## Pass Criteria

OPQ emits all packets and the DMA scoreboard observes two closed events

## Evidence

- Transcript: `tb_int/sim/E068/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
