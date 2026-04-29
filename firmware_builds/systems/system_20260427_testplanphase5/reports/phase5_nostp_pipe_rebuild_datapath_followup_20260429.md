# Phase 5 no-STP pipe rebuild datapath follow-up

- Date: `2026-04-29`
- Target revision: `top_nostp_pipe`
- Rebuilt SOF: `output_files_pipe/top_nostp_pipe.sof`
- Programmed checksum: `0x13C7FEDB`
- Compile log: [`../syn/logs/quartus_compile_top_nostp_pipe_rebuild_20260429.console.log`](../syn/logs/quartus_compile_top_nostp_pipe_rebuild_20260429.console.log)
- Environmental gate: [`phase5_environment_20260429_nostp_pipe_rebuild.md`](phase5_environment_20260429_nostp_pipe_rebuild.md), [`phase5_environment_20260429_nostp_pipe_rebuild.json`](phase5_environment_20260429_nostp_pipe_rebuild.json)

## Why this rerun was needed

The previously programmed no-STP image was checksum `0x13B82BDB` and behaved like a stale build relative to the current generated sources:

| Evidence | Result | Boundary |
|---|---|---|
| [`phase5_injector_emulator_l0_nostp_pipe_smoke_20260429.md`](phase5_injector_emulator_l0_nostp_pipe_smoke_20260429.md) | `FAIL` | emulator frames advanced (`61,250`) but MTS and histogram deltas stayed zero (`blocked_before_mts`) |
| [`phase5_injector_real03_ch16_repeat100_250ms_nostp_pipe_20260429.md`](phase5_injector_real03_ch16_repeat100_250ms_nostp_pipe_20260429.md) | `FAIL` | 100/100 windows had selected source-mux beats, but zero frame/MTS/histogram hit deltas (`blocked_before_emulator`) |

Because the debug runctl/MTS-stage image had already shown real-lane 0/3 traffic could reach the frame/MTS/histogram path, the correct next step was to rebuild the timing-clean no-STP image from the same generated firmware tree instead of accepting the stale-image failure as a datapath bug.

## Rebuild and board gate

| Step | Result |
|---|---|
| Full Quartus compile | `PASS`: 0 errors / 1731 warnings; elapsed `00:45:40` |
| Fitter | `PASS`: 63,112 / 91,680 ALMs (69%), 82,925 registers, 546 / 1,366 RAM blocks |
| STA | `PASS`: slow 85 C setup WNS `+0.080 ns`, LVDS `pll_sclk` setup slack `+0.216 ns`, all shown TNS `0.000` |
| FPGA programming | `PASS`: `quartus_pgm` programmed checksum `0x13C7FEDB` on Arria V JTAG ID `0x02A020DD` |
| PCIe/UIO recovery | `PASS`: `/usr/local/sbin/mudaq_recover_pcie` unloaded/reloaded `mudaq` |
| Run-control reset | `PASS`: `stop-reset` echoed `0x31` |
| SC bridge audit | `PASS`: initial quiet histogram UID read retried with bounded verbose `sc_tool`; payload returned UID `0x48495354`, then full `check_sc_bridges.py --skip-jtag` passed |
| Environmental gate | `PASS_WITH_WARN`: 62 PASS / 1 WARN / 0 FAIL; all six OneWire sensors live and FF2 correctly absent |

## Injector datapath reruns

| Run | Source setup | Result | Key deltas |
|---|---|---|---|
| [`phase5_injector_emulator_l0_nostp_pipe_rebuild_smoke_20260429.md`](phase5_injector_emulator_l0_nostp_pipe_rebuild_smoke_20260429.md) | emulator lane 0, periodic mode, interval 12500, 250 ms | `PASS` (1/1) | histogram `31,284`, MTS `24,647`, frame actual `30,745`, zero drops/discards/errors |
| [`phase5_injector_real03_ch16_repeat20_250ms_nostp_pipe_rebuild_20260429.md`](phase5_injector_real03_ch16_repeat20_250ms_nostp_pipe_rebuild_20260429.md) | mixed source, real lanes 0/3 selected, channel-16 periodic mode, 20 x 250 ms | `PASS` (20/20) | histogram `628,660`, MTS `497,335`, frame actual `620,124`, zero drops/discards/errors |
| [`phase5_injector_real03_ch16_repeat100_250ms_nostp_pipe_rebuild_20260429.md`](phase5_injector_real03_ch16_repeat100_250ms_nostp_pipe_rebuild_20260429.md) | same as above, 100 x 250 ms accepted soak | `PASS` (100/100) | histogram `3,185,632`, MTS `2,485,619`, frame actual/declared `3,103,835`, zero histogram drops, zero MTS discards, zero ring input errors, zero frame CRC errors, zero missing hits, zero SC-hub error/drop flags |

## Scoreboard interpretation

The timing-clean no-STP image now carries the accepted zero-discard real-lane 0/3 soak that was missing after the runctl/MTS-stage debug image. The Phase-5 real-source gate still remains `BLOCKED` for full closure because lanes 1/2/4/5/6/7 are not recovered or waived in the scoreboard, but the previous "needs longer accepted zero-discard soak" caveat is closed for the lane 0/3 channel-16 setup.
