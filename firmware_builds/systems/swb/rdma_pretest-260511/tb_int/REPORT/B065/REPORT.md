# REPORT - B065

- bucket: `BASIC`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b065.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b065_test.sv`
- run: `make run_B065`

## Scenario

SWB DT one SQE ingress through OPQ to PCIe DMA egress

## Stimulus

inject one FEB-to-SWB RDMA SQE, one OPQ packet, and one host-DMA beat

## Pass Criteria

scoreboard reconciles one ingress, zero drops, and one PCIe egress event

## Evidence

- Transcript: `tb_int/sim/B065/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
