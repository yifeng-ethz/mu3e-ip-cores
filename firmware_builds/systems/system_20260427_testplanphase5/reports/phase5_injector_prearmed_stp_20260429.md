# Phase 5 Injector Pre-Armed SignalTap Capture

- Date: `2026-04-29`
- Programmed FEB image: `top_stp_pipe_phase5_injector.sof`
- STP: `../signaltap/phase5_injector_path_lvds.stp`
- VCD: `../captures/phase5_injector_path_prearmed_periodic_20260429.vcd`
- Result: `PASS`

## Setup

The SWB was first reprogrammed with the `online_sc` SOF and PCIe was recovered
with `sudo -n /usr/local/sbin/mudaq_recover_pcie`. The SC path was then
validated by reading `histogram_statistics_0.UID` at word address `0x0A900`,
which returned `0x48495354`.

The injector was configured over `sc_tool` before arming SignalTap:

| Register | Value |
|---|---:|
| `mode` | `0x00000000`, then `0x00000002` |
| `header_delay` | `0x00000064` |
| `header_interval` | `0x00000001` |
| `injection_multiplicity` | `0x00000001` |
| `header_channel` | `0x00000000` |
| `pulse_interval` | `0x000030D4` |
| `pulse_high_cycles` | `0x00000005` |
| `prbs_rate` | `0x000003E7` |
| `prbs_pattern` | `0x00000001` |
| `prbs_seed` | `0x0000ACE1` |
| `prbs_ctrl` | `0x00000004` |

Readback matched before `mode` was set to `2`. After the capture, `mode` was
written back to `0` and read back as `0x00000000`.

## SignalTap Result

`quartus_stp` captured immediately on trigger `injector_path_pulse`:

```text
Signal Tap data acquisition is in IDLE state
Signal Tap data acquisition is in FILL state
Signal Tap data acquisition is in DONE state
Wrote captures/phase5_injector_path_prearmed_periodic_20260429.vcd
```

VCD edge summary:

| Signal | Rising edges | Final value |
|---|---:|---:|
| `mutrig_injector_0.csr.mode[1]` | 0 | 1 |
| `mutrig_injector_0.periodic_injector_pulse` | 1 | 0 |
| `mutrig_injector_0.coe_inject_pulse` | 1 | 0 |
| `emulator_inject_fanout.coe_inject_pulse` | 1 | 0 |
| `emulator_inject_fanout.coe_out0_pulse` | 1 | 0 |
| `emulator_mutrig_0.coe_inject_pulse` | 1 | 0 |
| `emulator_mutrig_0.inject_sync[0]` | 1 | 0 |
| `emulator_mutrig_0.inject_sync[1]` | 1 | 0 |
| `emulator_mutrig_0.inject_pulse_clk` | 1 | 0 |
| `mutrig_injector_0.avs_csr_waitrequest` | 0 | 0 |

## Notes

The previous concurrent wrapper, which armed SignalTap and then attempted SC
stimulus, failed because the SC secondary ring did not return a reply while the
capture was armed. Pre-arming the injector through SC and then running
SignalTap avoids this SC/JTAG interaction and is the current safe capture
method.
