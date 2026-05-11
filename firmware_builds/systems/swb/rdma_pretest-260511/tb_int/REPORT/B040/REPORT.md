# REPORT - B040

- bucket: `BASIC`
- status: `PASS`
- alias: `B-SC-JTG-001` mapped to lint-legal `B040`
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_b040.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_b040_test.sv`
- run: `make run_B040`

## Scenario

SWB-local JTAG slow-control fallback

## Stimulus

local JTAG master reads one debug-only identity word

## Pass Criteria

fallback read completes without aliasing the PCIe aperture

## Evidence

- Transcript: `tb_int/sim/B040/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
