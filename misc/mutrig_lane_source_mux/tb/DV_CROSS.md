# DV Cross - mutrig_lane_source_mux

The cross baseline uses `mlsm_bucket_frame_test` to execute the directed cases
without resetting between case bodies.

## Execution Modes

| mode | command | scope |
|---|---|---|
| isolated | `make -C misc/mutrig_lane_source_mux/tb/uvm directed64` | B001-B064, one DUT reset per case |
| bucket_frame | `make -C misc/mutrig_lane_source_mux/tb/uvm bucket_frame` | B001-B032 as one frame and B033-B064 as one frame |
| all_buckets_frame | Same as `bucket_frame` for this IP until EDGE/ERROR buckets are added. | BASIC + current PROF hooks |

## Cross Intent

| cross | bins | expected evidence |
|---|---|---|
| mode x real-valid build | real, emulator, mixed x `REAL_ALWAYS_VALID=0/1` | Covered by directed64 and bucket_frame. |
| mixed pressure x drop | paired, odd paired, sparse emulator x drop/no-drop | Covered by B017-B024 and B049-B056. |
| CSR switch x active output | real-to-emulator, emulator-to-mixed, mixed-to-direct | Covered by B025-B032 and B057-B064. |
