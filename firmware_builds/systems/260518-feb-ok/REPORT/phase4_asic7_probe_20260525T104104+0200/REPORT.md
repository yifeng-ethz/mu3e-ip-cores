# Phase 4 Unit A - ASIC7 Quick Probe

Date: 2026-05-25

## Scope

Classify why ASIC7 stayed quiet in the Phase 3 3 s run after ASIC0-6 showed
advancing frame-deassembly debug headers.

## Injector CSR

Read command:

```text
~/.local/bin/swb_ring_lock sc_tool 2 read 0x06C80 8 --quiet
```

Payload:

| Word | Register | Value | Decode |
| --- | --- | --- | --- |
| 0 | UID | 0x4D494E4A | `MINJ` |
| 1 | META | 0x1A011205 | version/meta |
| 2 | MODE | 0x00000001 | header-sync mode |
| 3 | HEADER_DELAY | 0x00000064 | 100 |
| 4 | HEADER_INTERVAL | 0x00000001 | 1 |
| 5 | INJECTION_MULTIPLICITY | 0x00000001 | 1 pulse/header |
| 6 | HEADER_CH | 0x00000000 | selected header channel 0 |
| 7 | PULSE_INTERVAL | 0x000003E8 | 1000 |

Source map: `charge_injection/script/mutrig_injector_multiheader_hw.tcl`
documents words 2-8 as mode, header delay, header interval, injection
multiplicity, header channel, pulse interval, and pulse high cycles. There is
no per-ASIC enable mask in this CSR window, and no mask write was performed.

## ASIC7 Nearby Offset Probe

ASIC7 nearby baseline:

```text
~/.local/bin/swb_ring_lock sc_tool 2 read 0x05E24 12 --quiet
payload = 00000000 00000000 00000000 00000000 00000001 00000000 00000000 00000000 00000000 00000000 00000000 00000000
```

ASIC7 nearby after a 10 s run:

```text
~/.local/bin/swb_ring_lock sc_tool 2 read 0x05E24 12 --quiet
payload = 00000000 00000000 00000000 00000000 00000001 00000000 00000000 00000000 00000000 00000000 00000000 00000000
```

No nearby offset changed, so this does not look like a misaligned CSR window.

## 10 s Run

Run command:

```text
~/.local/bin/swb_ring_lock rc_tool send start-sequence --run 8 --quiet
```

Run-control accepted the sequence:

```text
STATUS=0x12000004
run number=8
runctl LAST_CMD=0x12
runctl RUN_NUMBER=8
```

Frame-deassembly word 3 changed for ASIC0-6 but not ASIC7:

| ASIC | Base | Baseline word3 | After 10 s word3 | Verdict |
| --- | --- | --- | --- | --- |
| 0 | 0x04428 | 0xC4009731 | 0xC400B8E1 | OK |
| 1 | 0x04628 | 0xC4009731 | 0xC400F9C5 | OK |
| 2 | 0x04A28 | 0xC4009731 | 0xC400380E | OK |
| 3 | 0x04E28 | 0xC4009731 | 0xC4007C35 | OK |
| 4 | 0x05228 | 0xC4009731 | 0xC400B97E | OK |
| 5 | 0x05628 | 0xC4009731 | 0xC400F75C | OK |
| 6 | 0x05A28 | 0xC4009731 | 0xC4003B1B | OK |
| 7 | 0x05E28 | 0x00000000 | 0x00000000 | QUIET |

## Classification

**LIKELY_PHYSICAL**: ASIC7 remains quiet after a 10 s run while ASIC0-6 advance,
the injector CSR exposes no per-ASIC mask, and nearby ASIC7 offsets show no
activity that would indicate a wrong CSR offset.

Raw transcripts:

- `baseline_reads.log`
- `run8_10s_after_reads.log`
- `pre_stop_status.log`
- `post_stop_status.log`
