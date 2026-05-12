# Phase 4 Emulator Type0 Round 3 Board Evidence

## Purpose

Validate the compiled FEB v3 emulator-type0 SOF on the bench after the Qsys
refactor, using only the approved LOCAL_CMD sequence `0x10 -> 0x11 -> 0x12`
and `0x13` end-run. SWB was not reflashed.

## Bench

- Ticket: `ticket_20260512T085937Z_codex_phase4_emutype0_board.txt`
- Agent: `codex_phase4_emutype0_board`
- FEB link: `2`
- Final SOF: `syn/board_projects/fe_scifi_feb_v3/output_files/top.sof`
- SOF sha256: `11cce55e14610d4cf902d6e6fac7de14268b13bcdf6bc0cd6576f052049c615a`
- Quartus programmer checksum: `0x13940890`

## Fix During Board Iteration

The first board probe used a multiword `hist_bin` read. The local SC quickref
documents histogram-bin burst reads as a bridge corruption trigger. The probe
script now reads `hist_bin` one word at a time and records run-control host
`STATUS` and `LAST_CMD` around each LOCAL_CMD write.

## Final Command Sequence

```text
tools/run_script/program_feb.sh syn/board_projects/fe_scifi_feb_v3/output_files/top.sof
sudo -n /usr/local/sbin/mudaq_recover_pcie
/home/yifeng/.local/bin/swb_ring_lock python3 script/run_phase4_emutype0_board_probe.py --link 2 --run-seconds 4.2 --hit-rate 0x0800
```

Final LOCAL_CMD trace from
`reports/phase4_emutype0_board_20260512_111730/phase4_emutype0_board_probe.json`:

```text
0x10 word=0x02F02B10 status=0x80000003 last=0x00000000
0x11 word=0x00000011 status=0x00000003 last=0x00000011
0x12 word=0x00000012 status=0x00000003 last=0x00000012
0x13 word=0x00000013 status=0x00000003 last=0x00000013
```

## Final CSR Snapshot

`after_running`:

```text
hist TOTAL_HITS=7224210 BANK_STATUS=1 PORT_STATUS=0x200FF DROPPED_HITS=0
hist samples BANK_STATUS=[1,1,0,0,1,1,0,0,1]
hist_bin[0..63] sum=7552119
arb ingress_emu_hits=296199983 egress_emu_hits=296200017 drops_emu=0
MTS total_hits=41493308,41522372 discard_hits=0,0 status=0x20000011,0x20000011
rbCAM push_sum=83718920 pop_sum=79661199 inerr_sum=0
FEB frame declared_sum=80586869 actual_sum=80586830 missing_sum=0
```

`after_end_run`:

```text
hist TOTAL_HITS=4745301 BANK_STATUS=0 PORT_STATUS=0x200FF DROPPED_HITS=0
hist_bin[0..63] sum=7553629
arb ingress_emu_hits=340539680 egress_emu_hits=340539680 drops_emu=0
MTS total_hits=42567460,42567460 discard_hits=0,0 status=0x20000010,0x20000010
rbCAM push_sum=85134570 pop_sum=81010952 inerr_sum=0
FEB frame declared_sum=81010952 actual_sum=81010952 missing_sum=0
```

## Iteration Reports

- `reports/phase4_emutype0_board_20260512_110419`: initial PASS on datapath
  counts with long histogram interval, bank toggle not observable.
- `reports/phase4_emutype0_board_20260512_110538`: FAIL after unsafe
  histogram-bin burst read polluted the bridge state.
- `reports/phase4_emutype0_board_20260512_110701`: FAIL confirming the same
  polluted state.
- `reports/phase4_emutype0_board_20260512_111438`: PASS after reflash and
  single-word `hist_bin` reads.
- `reports/phase4_emutype0_board_20260512_111600`: PASS rerun with added
  rbCAM `inerr_count`, but counters were inherited from prior run.
- `reports/phase4_emutype0_board_20260512_111730`: clean final PASS after
  FEB-only reflash.

## Verdict

PASS for the Phase 4 board predicate:

- `TOTAL_HITS > 0`
- `BANK_STATUS` toggles during the run
- `PORT_STATUS != 0xFF`
- arbiter, MTS, rbCAM, FEB frame assembly, and histogram checkpoints all record
  nonzero live traffic
- emulator arbiter drops, MTS discards, rbCAM inerr, histogram dropped hits,
  and frame missing hits remain zero in the final clean run
