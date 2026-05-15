# v3_pretest-260511 tb_int

This directory contains the integration UVM harness for the v3_pretest-260511
FEB SciFi build. It reuses the Apr 27 common agents through symlinks where the
contracts match, adds v3-specific sidecar monitors, and provides a dual
nominal/debug environment for the B065 through B069 datapath sequences.

## Layout

- `uvm/common/` - reusable agents and shared monitors; most files are symlinks to the Apr 27 reference, with v3-specific sidecar monitors authored locally.
- `uvm/v3_pretest-260511/` - DUT bind interfaces, dual environment, base test, BASIC sequences, and B065 through B069 tests.
- `script/tb_int.f` - Questa compile filelist for the harness.
- `script/qip_to_filelists.py` - QIP extractor for generated `feb_system_v3` synthesis filelists.
- `REPORT/` - per-case evidence and dashboard notes.

## Usage

- `make smoke` runs B065 in harness-shell mode.
- `make regress_basic` runs B065 through B069 in harness-shell mode.
- `make run_RC_EMUL` runs the run-control emulator-directed sequence.
- `make run_source_mux_frame_parser_cosim` runs the source-mux/frame-parser cosim.
- `make comp_dut` compiles the generated `syn/feb_system_v3/synthesis/` tree plus the local board-package dependencies needed by the generated tree.
- `make run_B067 BIND_REAL_DUT=1` compiles and instantiates the generated DUT as `u_dut` while retaining the old dual UVM scoreboard path.
- `make check_dut_contract` checks whether the generated tree exposes the FEB upload path through `feb_frame_assembly` and `upload_pkt_mux`.

## Current DUT Scope

The generated `feb_system_v3` synthesis tree is a FEB-only build. The upload subsystem exposes the legacy `feb_frame_assembly` plus `upload_pkt_mux` path, so the nominal tb_int egress monitor binds there. RDMA SQE/CQE cosim is a separate FEB+SWB task and is intentionally excluded from this harness.
