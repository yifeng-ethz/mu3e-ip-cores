# DV Coverage - mutrig_lane_source_mux

Coverage is collected by Questa code coverage and the `mlsm_coverage`
functional covergroup in `uvm/mlsm_env_pkg.sv`.

## Coverage Category Status

| metric | status | note |
|---|---|---|
| stmt | supported_with_target | Questa `+cover=bcesft` enabled. |
| branch | supported_with_target | Questa `+cover=bcesft` enabled. |
| fsm_state | supported_with_target | No explicit FSM in DUT; reported if inferred by tool. |
| fsm_trans | supported_with_target | No explicit FSM in DUT; reported if inferred by tool. |
| toggle | supported_with_target | Questa `+cover=bcesft` enabled. |
| functional | supported_with_target | Case, mode, real-valid build, input-valid, and drop coverpoints. |

## Isolated Execution Order

| bucket | ordered case IDs | command |
|---|---|---|
| BASIC | B001-B064 | `make -C misc/mutrig_lane_source_mux/tb/uvm directed64` |
| PROF | P001-P003 | `make -C misc/mutrig_lane_source_mux/tb/uvm soak SOAK_ITERS=<host-calibrated>` |

## Continuous-Frame Baseline

| run | command | expected result |
|---|---|---|
| valid-qualified bucket frame | `make -C misc/mutrig_lane_source_mux/tb/uvm run REAL_ALWAYS_VALID=0 TEST=mlsm_bucket_frame_test CASE_ID=0 SEED=11` | PASS |
| validless bucket frame | `make -C misc/mutrig_lane_source_mux/tb/uvm run REAL_ALWAYS_VALID=1 TEST=mlsm_bucket_frame_test CASE_ID=32 SEED=12` | PASS |

## Current Evidence

| date | run | result | artifact |
|---|---|---|---|
| 2026-05-03 | `directed32_rav0` as part of `directed64` | PASS | `tb/uvm/logs/mlsm_directed_test_rav0_case*_s1.log` |
| 2026-05-03 | `directed32_rav1` as part of clean `directed64` rerun | PASS | `tb/uvm/logs/mlsm_directed_test_rav1_case*_s1.log` |
| 2026-05-03 | bucket-frame baseline, seeds 11/12 | PASS | `tb/uvm/logs/mlsm_bucket_frame_test_rav*_case*_s*.log` |
| 2026-05-03 | P001 30s soak, seed 101 | PASS, 34s, `UVM_ERROR=0`, `UVM_FATAL=0` | `tb/uvm/logs/mlsm_soak_test_rav0_case0_s101.log` |
| 2026-05-03 | P002 30s soak, seed 102 | PASS, 37s, `UVM_ERROR=0`, `UVM_FATAL=0` | `tb/uvm/logs/mlsm_soak_test_rav1_case32_s102.log` |
| 2026-05-03 | P003 30s soak, seed 103 | PASS, 36s, `UVM_ERROR=0`, `UVM_FATAL=0` | `tb/uvm/logs/mlsm_soak_test_rav1_case32_s103.log` |
