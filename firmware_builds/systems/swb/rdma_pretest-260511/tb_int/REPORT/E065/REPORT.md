# REPORT - E065

- bucket: `EDGE`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_e065.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_e065_test.sv`
- run: `make run_E065`

## Scenario

PCIe DMA burst-boundary

## Stimulus

drive a DMA event ending exactly at the selected burst boundary

## Pass Criteria

DMA asserts end-of-event on the expected beat only

## Evidence

- Transcript: `tb_int/sim/E065/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
