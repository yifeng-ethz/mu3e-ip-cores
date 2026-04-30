# Phase 6 SWB Secondary SignalTap Capture - 2026-04-30

## Result

`BLOCKED` before `swb_sc_secondary` packet capture. A SignalTap control trigger
on `state.waiting` passed and exported data, but the real trigger on
`state.capture_head` timed out while the same SC read reached the FEB `sc_hub`
and completed a valid external read.

## Evidence

| Check | Result | Observation |
|---|---|---|
| active STP compatibility | `PASS` | `top_sc_link2_rx_only.stp` ran on SWB hardware `DE5 [3-6.2]` without instance or checksum errors |
| SignalTap control trigger | `PASS` | trigger `swb_sc_secondary|state.waiting == high` completed with `RUN_RC=0`, exported CSV, 1036 CSV rows |
| SC read stimulus | `PASS_TX` | `sc_tool 2 read 0x0C000 1` wrote `0x1C0002BC`, `0x0000C000`, `0x00000001`, `0x0000009C`; SC main ready in 58 us |
| SWB host secondary read | `BLOCKED` | same stimulus timed out after 400925 us; secondary before/after stayed `0x0000`; secondary delta `0` |
| SignalTap target trigger | `BLOCKED` | trigger `swb_sc_secondary|state.capture_head == high` timed out after 8 s with `0 triggers seen`; no CSV generated |
| FEB `sc_hub` correlation | `PASS_DOWNLINK` | post-capture JTAG snapshot showed `LAST_RD_ADDR=0x0000C000`, `LAST_RD_DATA=0x52434D48` (`RCMH`) |

Raw local artifacts:

```text
/tmp/phase6_stp_swb_secondary_20260430/capture_head_sc_read_0x0C000_20260430_133507.log
/tmp/phase6_stp_swb_secondary_20260430/control_waiting_20260430_133622.log
/tmp/phase6_stp_swb_secondary_20260430/control_waiting_20260430_133622.csv
/tmp/phase6_feb_schub_after_stp_capture_20260430.log
```

## Interpretation

The previous evidence proved that the request reaches the FEB `sc_hub`. This
capture proves the SWB SignalTap/STP session itself is healthy, then shows that
the FEB reply is not observed at the tapped `swb_sc_secondary` capture boundary.

The next useful scope is upstream of `swb_sc_secondary`: SC return link FIFO,
optical RX/SC lane demux, or FEB `sc_hub` upload framing. OPQ, DMA, and disk
decode remain invalid as Phase-6 evidence until this return/input boundary is
closed.
