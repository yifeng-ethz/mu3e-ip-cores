# Phase 6 SWB OPQ Live Preflight - 2026-04-30

## Result

`BLOCKED` at SWB input link lock. The SWB OPQ image is compiled and programmed,
PCIe is recovered, and reset-link command echo works, but FEB SC link 2 is not
locked at the SWB.

## Evidence

| Check | Result | Observation |
|---|---|---|
| online_sc OPQ source | `PASS` | commit `ada3aea38`, fixed4 OPQ package `26.5.0.0430`, Mu3e Demo `N_SHD=128`, `N_HIT=255` |
| SWB full compile | `PASS` | `make flow` completed with 0 errors; worst setup slack `+0.024 ns`; worst hold slack `+0.012 ns` |
| SWB programming | `PASS` | `make pgm` programmed `output_files/top.sof`, checksum `0x31AA0589` |
| PCIe recovery | `PASS` | `mudaq_recover_pcie` recovered `0000:0b:00.0`; `/dev/mudaq0` present |
| reset-link stop-reset | `PASS_DIAG` | `rc_tool send stop-reset --feb 7` echoed `RESET_LINK_STATUS_REGISTER_R=0x31000000` |
| reset-link enable | `PASS_DIAG` | `rc_tool send enable --feb 7` echoed `RESET_LINK_STATUS_REGISTER_R=0x32000000` |
| SC link 2 secondary read | `BLOCKED` | `sc_tool 2 read 0x00000 --dump-ring` timed out; secondary delta stayed 0 |
| corrected SWB diagnostics | `BLOCKED` | `LINK_LOCKED_LOW=0x00000F00`, `LINK_LOCKED_HIGH=0x00000000`, so bit 2 is clear |

## Interpretation

The live blocker is before OPQ and DMA. With link 2 unlocked, SWB input counters,
OPQ ingress/drop CSRs, host DMA, and disk decode cannot be credited as FEB
end-to-end evidence. The next action is to resolve FEB image, optical link,
cable, or reset alignment until link 2 locks, then rerun the P6-SWB-IN gate and
only then proceed to OPQ/DMA capture.

The active Mu3e Demo OPQ profile is deliberately a one-drop diagnostic profile:
a 256-hit source cluster must deliver 255 same-timestamp hits and account
exactly one OPQ `drop_hit`. A no-loss 256-host-hit claim requires a different
OPQ hit-limit profile.
