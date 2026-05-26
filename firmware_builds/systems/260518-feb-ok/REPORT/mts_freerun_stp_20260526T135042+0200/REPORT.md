# MTS Freerun SignalTap Capture Attempt

Date: 2026-05-26

## Objective

Add a guaranteed-firing free-running toggle in the MTS clock domain, compile it into the `mts_debug` SignalTap instance, precondition the board into a stable run state, and capture MTS Type0/Type1 path evidence. The stop condition for this round was explicit: if a free-running toggle trigger still times out, stop and report rather than iterating further.

## RTL And STP Changes

- `mutrig_timestamp_processor/mts_processor.vhd`
  - Version header bumped to `26.3.13`.
  - Added preserved/noprune/keep `stp_mts_freerun_toggle_q`.
  - Reset drives the toggle to `0`; each `i_clk` rising edge toggles it.
  - Existing `26.3.12` fixes were kept: low-channel acceptance gate, `source_asic_pipe`, and Type1 `[38:35]` pack from sideband.
- `mutrig_timestamp_processor/mts_processor_hw.tcl`
  - `VERSION_PATCH_DEFAULT_CONST` bumped to `13`.
- `firmware_builds/systems/260518-feb-ok/script/signaltap/add_mts_debug_instance.py`
  - Regenerated `mts_debug` with `stp_mts_freerun_toggle_q` as probe 0.
  - Compile-time trigger set to rising edge of MTS0 `stp_mts_freerun_toggle_q`.
- `firmware_builds/systems/260518-feb-ok/syn/board_projects/fe_scifi_feb_v3/mutrig_cfg_lvds.stp`
  - Regenerated through the project STP script, then imported with `quartus_stp`.

The generated synthesis copy was synced and verified after `make qsys-syn`:

- `generated/synthesis/feb_system_v4/synthesis/submodules/mts_processor.vhd` contains `Version : 26.3.13`.
- The generated copy contains `stp_mts_freerun_toggle_q` and the preserved toggle process.

## SignalTap Compile-Time Setup

`top.qsf` contains a second SignalTap instance:

- Instance: `mts_debug`
- Sample depth: `4096`
- Data bits: `116`
- Trigger bits: `116`
- Clock assignment: `mu3e_lvds_controller_0_outclock_clk`
- Trigger/data input 0: MTS0 `stp_mts_freerun_toggle_q`
- CRC assignment is non-zero.

Evidence files:

- `stp_generator.log`
- `quartus_stp_import.log`
- `top_qsf_stp_assignments_after_import.log`

## Build Result

Commands:

```sh
make qsys-syn
quartus_sh --flow compile top -c top
```

Result:

- `make qsys-syn`: passed.
- Quartus full compile: passed, `0 errors`, `1666 warnings`.
- Compile elapsed time: `01:03:12`.
- SOF: `syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`
- `cksum`: `673700521 12685853`

Resource summary:

| Resource | Usage |
| --- | ---: |
| ALMs | 57,376 / 91,680 (63%) |
| Registers | 98,079 |
| Block memory bits | 8,261,004 / 13,987,840 (59%) |
| RAM blocks | 1,055 / 1,366 (77%) |
| DSP blocks | 0 / 800 |

Timing summary:

| Check | Worst Slack |
| --- | ---: |
| Setup | `+0.384 ns` |
| Hold | `+0.120 ns` |
| Recovery | `+0.944 ns` |
| Removal | `+0.208 ns` |
| Minimum pulse width | `+0.160 ns` |

## Program Result

Command:

```sh
quartus_pgm -c "USB-BlasterII [7-2]" -m JTAG -o "p;output_files/top.sof"
```

Result:

- Program operation succeeded.
- SOF checksum reported by Quartus Programmer: `0x1D11C2A2`.
- Waited 20 s after programming.

## Board Preconditioning Result

Reusable helper created:

- `setup_for_hist_capture.py`

The helper performs the intended setup sequence:

1. Recover PCIe if `/dev/mudaq0` is missing.
2. `rc_tool send stop-sequence`.
3. Lane-8 soft reset: `sc_tool 2 write 0x04006 0x00000100 --quiet`.
4. Canonical `configure_mutrig_from_xml_v4addr.py`.
5. One `PHY_DPALOCK` read.
6. Injector setup.
7. ASIC0 Type1-up histogram setup.
8. `rc_tool send start-sequence --run 9000`.
9. Headless STP acquisition/export.
10. `rc_tool send stop-sequence`.

The helper failed at the lane-8 soft-reset SC write:

```sh
~/.local/bin/swb_ring_lock sc_tool 2 write 0x04006 0x00000100 --quiet
```

Observed failure:

- `sc_tool` exit code: `4`
- Failure mode: timeout waiting for matching secondary reply.
- Secondary stream showed many invalid packets and no matching write reply.
- `/dev/mudaq0` was present.

One PCIe recovery was performed as allowed:

```sh
sudo -n /usr/local/sbin/mudaq_recover_pcie
```

Recovery completed and `/dev/mudaq0` was present, but the next helper run failed at the same SC write with the same secondary-ring timeout/corruption signature. I stopped further SC attempts.

Evidence files:

- `setup_for_hist_capture_transcript.first_sc_timeout.log`
- `mudaq_recover_after_sc_timeout.log`
- `setup_for_hist_capture_transcript.log`

## JTAG-Only Freerun STP Attempt

Because SC preconditioning was blocked but JTAG was still reachable, I ran one direct headless STP acquisition of `mts_debug` without additional SC/RC traffic:

```sh
quartus_stp -t stp_acquire_instance.tcl USB-BlasterII 5AG \
  syn/board_projects/fe_scifi_feb_v3/mutrig_cfg_lvds.stp \
  mts_debug mts_debug mts_debug_trig \
  mts_debug_freerun_capture_no_sc.csv \
  mts_debug_freerun_no_sc_log 30
```

Result:

- Hardware found: `USB-BlasterII [7-2]`.
- Device found: `5AGT.../5AGXBA7D4`.
- SignalTap session opened.
- Acquisition timed out:
  - `ERROR: Trigger did not occur in timeout period. Make sure trigger conditions are valid and/or increase timeout period.`
- Export still produced a CSV, but it is not a valid triggered capture.

CSV decode:

```json
{
  "rows": 4098,
  "probe_count": 117,
  "classification": "NO_TYPE0_TRAFFIC_AT_MTS"
}
```

The decode saw only one concrete MTS0 freerun sample (`0`) and no usable MTS1 freerun samples. Most probe values in the exported buffer are `X`, so this does not prove MTS path behavior.

Evidence files:

- `stp_acquire_no_sc.log`
- `mts_debug_freerun_capture_no_sc.csv`
- `mts_debug_freerun_decode_no_sc.json`

## Verdict

Free-running STP trigger captures cleanly: **NO**.

This is the user-defined stop condition. Even with a preserved MTS-clock free-running toggle compiled into the SignalTap trigger path, `mts_debug` timed out and did not produce a valid capture. I did not run the per-ASIC histogram loop.

MTS path classification: **BLOCKED: FUNDAMENTAL_OBSERVABILITY_ISSUE**.

The current evidence does not distinguish between:

- the selected `mts_debug` sample clock not actually being the active MTS clock in this board state,
- the MTS clock domain not running after this programming/precondition failure,
- the STP runtime/trigger setup still not matching the compiled SLD instance despite QSF assignments,
- or the board SC/control state preventing the MTS subsystem from entering a meaningful run state.

The SC secondary path is also currently unhealthy after programming this image: the lane-8 soft-reset write fails repeatedly even after one PCIe recovery.

## Recommended Next Step

Do not continue with MTS histogram or per-ASIC filter debug until observability is restored.

The smallest next compile/debug step is to add a second minimal always-on control-clock SignalTap sanity instance with a free-running toggle on a known live clock, while keeping the MTS freerun instance. That would separate "SignalTap runtime/JTAG setup is broken" from "the selected MTS sample clock is not running or not the clock we think it is." In parallel, the SC secondary-ring timeout should be cleared by a board-level reset/reprogram recovery before attempting more `sc_tool` writes.

No commits or pushes were made.
