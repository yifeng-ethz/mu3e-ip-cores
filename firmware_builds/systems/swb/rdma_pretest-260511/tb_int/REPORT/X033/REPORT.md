# REPORT - X033

- bucket: `ERROR`
- status: `PASS`
- alias: n/a
- sequence: `uvm/swb_rdma_pretest/sequences/tb_int_x033.sv`
- test: `uvm/swb_rdma_pretest/tests/tb_int_x033_test.sv`
- run: `make run_X033`

## Scenario

illegal PCIe BAR write to RO field

## Stimulus

drive one write attempt against the read-only structural aperture

## Pass Criteria

error path is contained and datapath counters remain unchanged

## Evidence

- Transcript: `tb_int/sim/X033/transcript`
- UVM_ERROR: `0`
- UVM_FATAL: `0`
- Scoreboard: selected-case ledger reconciled
