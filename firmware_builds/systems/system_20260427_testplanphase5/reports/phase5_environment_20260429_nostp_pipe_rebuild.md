# Phase 5 Environmental Gate - no-STP pipe rebuild

- Timestamp: `2026-04-29`
- FEB image: `top_nostp_pipe.sof`
- Programmed checksum: `0x13C7FEDB`
- JSON evidence: [`phase5_environment_20260429_nostp_pipe_rebuild.json`](phase5_environment_20260429_nostp_pipe_rebuild.json)
- Result: `PASS_WITH_WARN` (`62 PASS / 1 WARN / 0 FAIL`)

## Checks

| Area | Result | Evidence |
|---|---|---|
| OneWire controller | `PASS` | UID `0x4F574D43`; 6 DQ lines; selected-line `sample_valid=1`; no sticky CRC/init errors |
| OneWire temperatures | `PASS` | `30.375`, `32.938`, `21.625`, `22.062`, `40.188`, `39.750` C; no stale `1.0 C` signature |
| Firefly 1 | `PASS_WITH_WARN` | temp `58` C; RX powers `3950`, `3950`, `2780`, `2780`; VCC raw code `58` remains a monitor-scaling WARN |
| Firefly 2 | `PASS` | expected dangling-module sentinel pattern: temp `0`, VCC/RX powers `0xFFFF` |
| Legacy Firefly bridge | `PASS` | one-word reachability probe responds; primary optical monitor remains `firefly_xcvr_ctrl_0` |

## Interpretation

This gate is accepted for Phase 5 board tests on the rebuilt no-STP image. The sole warning matches the prior FF1 VCC raw-code interpretation issue; FF1 temperature and optical-power monitors are live, and FF2 is intentionally not connected in this setup.
