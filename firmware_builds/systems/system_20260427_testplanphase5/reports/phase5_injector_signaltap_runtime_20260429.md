# Phase 5 Injector SignalTap Runtime Report

- Date: `2026-04-29`
- Revision: `top_stp_pipe_phase5_injector`
- Status: `BLOCKED_HOST_SC`
- Board action: programmed once

## Programming Evidence

The rebuilt micro STP SOF was programmed through `USB-BlasterII [7-2]`.

| Item | Evidence |
|---|---|
| SOF | `output_files_pipe_phase5_injector_stp/top_stp_pipe_phase5_injector.sof` |
| Program log | `program_top_stp_pipe_phase5_injector_microstp_20260429.log` |
| Checksum | `0x13EBA600` |
| Result | Quartus Programmer successful, 0 errors, 0 warnings; device `5AGXBA7D4F31@1` configured |

## Capture Attempt

| Item | Evidence |
|---|---|
| STP | `signaltap/phase5_injector_path_lvds.stp` |
| Capture log | `reports/phase5_injector_signaltap_capture_20260429_025745.log` |
| Runner report | `reports/phase5_injector_emulator_periodic_signaltap_20260429_025745.md` |
| Runner JSON | `reports/phase5_injector_emulator_periodic_signaltap_20260429_025745.json` |

SignalTap opened the programmed image and armed `auto_signaltap_0`, signal set `phase5_injector_path_lvds`, trigger `injector_path_pulse`. No VCD was exported because the acquisition timed out with 0 triggers seen.

The injector runner failed before it could configure the datapath. The first `sc_tool` write to injector base word `0x0AC80` timed out waiting for a matching secondary reply. The verbose retry reported `PLL_LOCKED_REGISTER_R`, `LINK_LOCKED_*`, `RESET_LINK_STATUS_REGISTER_R`, SC main status, and SC state all as `0xFFFFFFFF`.

## Recovery Attempt

The PCIe/UIO rescan helper was run after the all-ones SC response:

```text
pcie_uio_rescan 1172:0004
Removing PCIe device 0000:0b:00.0
Rescanning PCIe bus
Bound 0000:0b:00.0 (1172:0004) to uio_pci_generic
UIO node: /dev/uio0
```

This restored PCIe visibility but bound the endpoint to `uio_pci_generic`, while the current board-test tools require the `mudaq` driver and `/dev/mudaq0`. Post-checks showed:

- `/dev/mudaq0` no longer exists after the UIO rescan.
- `sc_tool --device /dev/uio0` cannot open the endpoint (`mmap region 4` invalid).
- Arbitrary `sudo -n` rebind/load commands are not available in this session, so the endpoint could not be rebound to `mudaq`.
- A direct System Console JTAG read probe did not return promptly and was stopped; no JTAG-driven injector write was attempted.

## Interpretation

This run does not disprove the injector datapath. The programmed STP image is timing-clean and visible to Quartus SignalTap, but no injector pulse was generated because the host control path failed before the first CSR write.

## Next Action

Restore the endpoint to the `mudaq` driver with root or a whitelisted helper, confirm `/dev/mudaq0` exists, and run one read-only SC post-check before retrying `INJ-P1-EMU-LIVE`. If `/dev/mudaq0` cannot be restored, add a dedicated JTAG/System Console injector-control script that writes the datapath CSR window directly and uses that to trigger the STP capture.
