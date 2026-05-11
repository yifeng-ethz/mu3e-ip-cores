# SWB rdma_pretest-260511 Integration TB

This tree verifies the staged SWB Arria 10 DE5 build under
`../syn/board_projects/swb_a10` against the local Qsys synthesis outputs.

Useful targets:
- `make check` regenerates and lints the DV bucket documents and bug ledger.
- `make smoke` compiles the UVM shell and runs the `B065` smoke.
- `make regress_selected` runs the selected 22-case BASIC/EDGE/ERROR/PROF
  sweep.

Primary outputs:
- `sim/B065/transcript`
- `sim/<case>/transcript` for each selected case
- `sim/logs/regress_selected_22.log`
- `DV_REPORT.md`, `DV_COV.md`, and `REPORT/`
