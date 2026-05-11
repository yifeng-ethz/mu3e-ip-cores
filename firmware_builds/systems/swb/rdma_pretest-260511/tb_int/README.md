# SWB rdma_pretest-260511 Integration TB

This tree verifies the staged SWB Arria 10 DE5 build under
`../syn/board_projects/swb_a10` against the local Qsys synthesis outputs.

Useful targets:
- `make check` regenerates and lints the DV bucket documents and bug ledger.
- `make basic` dispatches the implemented BASIC bucket smoke (`B065`) and
  records the remaining BASIC cases as pending.

Primary outputs:
- `sim/logs/swb_basic_b065_smoke.log`
- `sim/logs/basic_bucket_sweep.log`
