# Dual-Port Histogram Signoff

## Summary

`v3_pretest-260511-emutype0-dualport-260512` fixes the Phase 4.5 histogram ingress topology so both MTS banks feed `histogram_statistics_0`.

## Description

- Port 0: lanes 0..3 via `mts_preprocessor_0 -> histogram_ingress_bridge_0 -> histogram_statistics_0.hist_fill_in`.
- Port 1: lanes 4..7 via `mts_preprocessor_1 -> histogram_ingress_bridge_1 -> histogram_statistics_0.fill_in_1`.
- `histogram_statistics_0.N_PORTS` is `2`.
- The top-level Qsys version is `3.0.5.0512`.
- The arb-to-MTS path uses readyless hit_type0 muxes and the MTS `hit_type0_in` sink no longer declares `ready`.
- The FEB top-level SC map binds the current datapath component, not the stale eight-emulator map:
  - `data_path_subsystem_emulator_mutrig_qsys_inst.csr`: `0x2000..0x2100`.
  - `data_path_subsystem_dbg_mm2runctrl_0.csr`: `0x2200..0x2240`.
  - `data_path_subsystem_histogram_ingress_bridge_0.csr`: `0xAC00..0xAC10`.
  - `data_path_subsystem_histogram_ingress_bridge_1.csr`: `0xAC10..0xAC20` (`0x0AB04` SC word base).

## File Structure

- Qsys recipe: `script/update_dualport_histogram_topology.tcl`.
- Qsys apply wrapper: `script/apply_dualport_histogram_topology.sh`.
- Top metadata and CSR-map recipe: `script/update_feb_system_v3_dualport_version.tcl`.
- Focused sim harness: `tb_int/hist_dualport/`.
- Simulation reports: `tb_int/REPORT/dualport_smoke.md` and `tb_int/REPORT/100k_single_channel_soak.md`.
- Board long-soak helper: `scripts/cotest/phase4_5_longsoak.py`.

## Usage

Generate the Qsys tree through the build-local script:

```sh
firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/script/generate_feb_system_v3.sh
```

Run the board long-soak through the ring lock:

```sh
PHASE4_5_BUILD_DIR=/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512 \
  /home/yifeng/.local/bin/swb_ring_lock \
  python3 scripts/cotest/phase4_5_longsoak.py --rate-88fp 0x21
```

## Test

- Qsys generation: PASS, `*_qsys_generate_20260514_addrmap_fix_clean.status`, all four generated systems report exit code 0 and error count 0 after the FEB top CSR-map fix.
- Qsys generation: PASS, `feb_system_v3_qsys_generate_20260512_133806_isolated.status`, exit code 0.
- Simulation smoke: PASS, 1000 observed hits, port0 handshakes 500, port1 handshakes 500, `hist_bin` writes 844.
- Simulation 100k soak: PASS, 100000 observed hits, port0 handshakes 50000, port1 handshakes 50000, `hist_bin` writes 100000.
- Quartus compile: PASS, `output_files/top.sof`, SHA-256 `f6c6c8c55f846287`.
- Setup slack: slow 85C `-0.245 ns`, slow 0C `0.015 ns`, fast 85C `0.620 ns`, fast 0C `0.763 ns`.
- Board sweep: 25 PASS / 7 FAIL with CSR 13 nonzero on the previously missing bank-1 lane rows.
- Board long-soak: PASS, 97652 observed hits vs 100000 target, tolerance 4000, 10 interval bin snapshots, no toggle misses.

## Documentation

`BUG_HISTORY.md` records BUG-006-I closure with residuals. The remaining residual is the sweep harness readout timing: END_RUN clears the frozen histogram bank on this image, so per-row `hist_bin` evidence must be sampled while RUNNING.
