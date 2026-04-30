# Phase 6 SWB OPQ Live Preflight - 2026-04-30

## Result

`BLOCKED` at the SWB SC reply/capture path. The SWB OPQ image is compiled and
programmed, PCIe is recovered, and reset-link command echo works. A valid SC
read reaches the FEB `sc_hub`, but the reply does not appear in the host-visible
SWB secondary ring.

## Evidence

| Check | Result | Observation |
|---|---|---|
| online_sc OPQ source | `PASS` | commit `ada3aea38`, fixed4 OPQ package `26.5.0.0430`, Mu3e Demo `N_SHD=128`, `N_HIT=255` |
| SWB full compile | `PASS` | `make flow` completed with 0 errors; worst setup slack `+0.024 ns`; worst hold slack `+0.012 ns` |
| SWB programming | `PASS` | `make pgm` programmed `output_files/top.sof`, checksum `0x31AA0589` |
| PCIe recovery | `PASS` | `mudaq_recover_pcie` recovered `0000:0b:00.0`; `/dev/mudaq0` present |
| reset-link stop-reset | `PASS_DIAG` | `rc_tool send stop-reset --feb 7` echoed `RESET_LINK_STATUS_REGISTER_R=0x31000000` |
| reset-link enable | `PASS_DIAG` | `rc_tool send enable --feb 7` echoed `RESET_LINK_STATUS_REGISTER_R=0x32000000` |
| SC link 2 smoke read | `BLOCKED` | `sc_tool 2 read 0x00000 --dump-ring` timed out; secondary delta stayed 0 |
| valid FEB UID read through SC | `PASS_DOWNLINK` | `sc_tool 2 read 0x0C000 1` timed out at host, but FEB `sc_hub` JTAG showed `LAST_RD_ADDR=0x0000C000`, `LAST_RD_DATA=0x52434D48` (`RCMH`) |
| valid-address sweep | `BLOCKED` | `0x0A900`, `0x0C000`, `0xFE84`, and `0xFE8F` all timed out at host; secondary ring delta stayed 0 |
| link-id sweep | `BLOCKED` | `sc_tool <0..15> read 0x0C000 1` all timed out with secondary delta 0 |
| corrected SWB diagnostics | `DIAG` | `LINK_LOCKED_LOW=0x00000F00` / later `0x00002F00`, `LINK_LOCKED_HIGH=0x00000000`; these do not explain away the observed FEB-side `sc_hub` read completion |
| SWB secondary SignalTap | `BLOCKED` | `state.waiting` control trigger passed, but `state.capture_head` around `sc_tool 2 read 0x0C000 1` timed out with `0 triggers seen`; see [`phase6_swb_secondary_stp_capture_20260430.md`](phase6_swb_secondary_stp_capture_20260430.md) |

## Interpretation

The live blocker is before OPQ and DMA, but it is no longer simply "the read
does not reach FEB." The downlink reaches FEB `sc_hub` and performs a valid
external read of the run-control management UID. The SignalTap control trigger
passes, but the real `swb_sc_secondary|state.capture_head` trigger does not
fire for the same SC read, so the failing boundary is now before the tapped SWB
secondary packet capture.

Do not credit SWB input counters, OPQ ingress/drop CSRs, host DMA, or disk
decode as FEB end-to-end evidence in this state. The next action is to move the
SignalTap scope upstream to the SC return link FIFO, optical RX/SC lane demux,
or FEB `sc_hub` upload framing and find where the `RCMH` reply disappears.

The active Mu3e Demo OPQ profile is deliberately a one-drop diagnostic profile:
a 256-hit source cluster must deliver 255 same-timestamp hits and account
exactly one OPQ `drop_hit`. A no-loss 256-host-hit claim requires a different
OPQ hit-limit profile.
