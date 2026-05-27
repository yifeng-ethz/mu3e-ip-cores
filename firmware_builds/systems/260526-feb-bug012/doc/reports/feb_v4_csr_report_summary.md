# FEB v4 CSR Report — Cross-IP Summary (2026-05-18)

**Source:** `feb_v4_csr_report_20260518.md` (full per-word per-IP report
from `python3 script/probe_feb_ip_inventory.py --link 2 --mode report
--burst 256`, on-board, post-Phase-B v4 rewire).

## Top-line counts

22 endpoints walked (control_path: 7, data_path via ctrl2data bridge:
14, sc_hub internal: 1). 2596 words probed (each via single read AND
via burst read, capped at 256 words/IP).

| count | meaning |
|---|---|
| 20 | words where single read matches the SVD-declared `resetValue` |
| 32 | words where single read DRIFTS from the SVD-declared `resetValue` |
| 10 | words where single read differs from the burst read at the same offset (live counter snapshot drift, NOT a bridge bug — see sc_hub `GTS_SNAP_*`/`FIFO_STATUS`) |
| 2534 | words with no `resetValue` declared in the SVD (CSR offsets not yet documented) |

## Per-IP rollup

| IP | match | drift | burst≠single | no-svd-reset | total |
|---|---|---|---|---|---|
| `scratch_pad_ram.s1` | 0 | 0 | 0 | 256 | 256 |
| `max10_prog_avmm_0.csr_avmm` | 1 | 1 | 0 | 254 | 256 |
| `on_die_temp_sense_ctrl.csr` | 0 | 0 | 0 | 4 | 4 |
| `onewire_master_controller_0.csr` | 1 | 0 | 0 | 63 | 64 |
| `firefly_xcvr_ctrl_0.firefly` | 0 | 0 | 7 | 121 | 128 |
| `mutrig_cfg_ctrl_0.avmm_csr` | 0 | 0 | 0 | 16 | 16 |
| `lvds_rx_controller_pro_0.csr` | 12 | 8 | 0 | 44 | 64 |
| `emulator_mutrig_qsys_inst.csr` | 0 | 6 | 0 | 250 | 256 |
| `arb_hit_type0_supercore_0_csr_pipe_0.s0` | 0 | 0 | 0 | 128 | 128 |
| `arb_hit_type0_supercore_0_csr_pipe_1.s0` | 0 | 0 | 0 | 128 | 128 |
| `arb_hit_type0_supercore_0_csr_pipe_2.s0` | 0 | 0 | 0 | 128 | 128 |
| `arb_hit_type0_supercore_0_csr_pipe_3.s0` | 0 | 0 | 0 | 128 | 128 |
| `arb_hit_type0_supercore_0_csr_pipe_4.s0` | 0 | 0 | 0 | 128 | 128 |
| `arb_hit_type0_supercore_0_csr_pipe_5.s0` | 0 | 0 | 0 | 128 | 128 |
| `arb_hit_type0_supercore_0_csr_pipe_6.s0` | 0 | 0 | 0 | 128 | 128 |
| `arb_hit_type0_supercore_0_csr_pipe_7.s0` | 0 | 0 | 0 | 128 | 128 |
| `mts_preprocessor_0.csr` | 0 | 0 | 0 | 32 | 32 |
| `mts_preprocessor_1.csr` | 0 | 0 | 0 | 32 | 32 |
| `histogram_statistics_0.csr` | 0 | 3 | 0 | 125 | 128 |
| `histogram_statistics_0.hist_bin` | 0 | 3 | 0 | 253 | 256 |
| `mutrig_injector_0.csr` | 5 | 11 | 0 | 48 | 64 |
| `sc_hub.internal_csr` | 1 | 0 | 3 | 12 | 16 |
| **TOTAL** | **20** | **32** | **10** | **2534** | **2596** |

## Drift hot-spots — offset 0x000 UID mismatch

These 4 IPs declare a `UID` register at offset 0x00 in their SVD but
the live RTL reads back something else, i.e. the RTL does not
implement the META header convention even though the SVD documents it.
This is what the next round of RTL work fixes (each IP needs a
`UID_CONST` / `META[0]=VERSION_CONST` insert into its
`csr_read_data` case statement; existing CSR layout shifts by 2 words).

| IP | SVD UID (resetValue) | live RTL reads | what to fix |
|---|---|---|---|
| `lvds_rx_controller_pro_0.csr` | `0x4C564453` ("LVDS") | `0x00FA0009` | add META header in `mu3e_lvds_controller/lvds_rx_controller_pro.terp.vhd` |
| `histogram_statistics_0.csr` | `0x48495354` ("HIST") | `0x00000000` | add META header in `histogram_statistics/rtl/histogram_statistics.vhd` |
| `histogram_statistics_0.hist_bin` | `0x48495354` ("HIST") | `0x20000010` | hist_bin is a memory aperture, not a CSR; SVD should NOT claim UID here (drop the UID register from the hist_bin SVD overlay or move it to the csr SVD overlay only) |
| `mutrig_injector_0.csr` | `0x4D494E4A` ("MINJ") | `0x00000000` | add META header in `charge_injection/rtl/vhdl/mutrig_injector_multiheader.vhd` |

## BURST≠SINGLE hot-spots — live state changing between probes

The single-read loop takes seconds per IP; the burst is captured in
one transaction. Live counters / snapshots therefore disagree across
the two reads. This is NOT a bridge bug.

| IP | offsets with BURST≠SINGLE | reason |
|---|---|---|
| `firefly_xcvr_ctrl_0.firefly` | 7 words | firefly I2C heartbeat / Rx status updates between reads |
| `sc_hub.internal_csr` | 3 words | `GTS_SNAP_LO`, `GTS_SNAP_HI`, `FIFO_STATUS` |

## drift NOT due to missing UID

Several IPs show drift on registers OTHER than UID — these are SVDs
where the declared `resetValue` is wrong (the RTL reset constant
differs from the SVD constant). Worth a low-priority cleanup pass on
each IP's `cmsis_svd.tcl`:

- `histogram_statistics_0.csr` drift on `CONTROL` (SVD `0x00000100` vs
  live `0x00000000`) and `KEY_LOC` (SVD `0x26231D11` vs live
  `0x00000000`): SVD's reset constants assume the META-header shift
  that the RTL hasn't implemented; once the RTL shift lands, these
  drifts go away (they'll appear at offsets +0x08 and +0x18 instead).
- `mutrig_injector_0.csr` 11 drifts: same story.
- `emulator_mutrig_qsys_inst.csr` 6 drifts: same story.
- `max10_prog_avmm_0.csr_avmm` 1 drift, `lvds_rx_controller_pro_0.csr`
  8 drifts: per-IP SVD reset-value cleanup.

## Next actions

1. Add META header (`UID_CONST` + `meta_readdata` mux) to the 3 IPs
   above (lvds_rx, histogram_statistics, mutrig_injector). The pattern
   is documented in `emulator_mutrig/rtl/frontend/frontend_csr.sv` and
   `misc/arb_hit_type0/rtl/arb_hit_type0_csr.sv`. Each adds ~12 lines
   to the IP's CSR case statement; existing offsets shift by +2 words.
2. Bump each IP's `hw.tcl` VERSION (YY.MINOR.PATCH.MMDD).
3. Drop the spurious UID overlay from `hist_bin` SVD (it's a pure
   memory aperture, not a CSR).
4. Regenerate FEB Qsys + full flow + reprogram + re-run
   `probe_feb_ip_inventory.py --mode report`. Target: 20 → ~24 match,
   32 → ~16 drift (only the bona-fide live-counter drifts left).
