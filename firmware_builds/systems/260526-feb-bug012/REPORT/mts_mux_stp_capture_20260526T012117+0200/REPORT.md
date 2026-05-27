# MTS / mux per-ASIC ID SignalTap capture

Date: 2026-05-26 01:21 +0200

## Objective

Ground-truth the Type1 per-ASIC ID path after the mts_processor ASIC-ID fix:

```text
hist_type0 lane outputs
  -> hit_type0_readyless_mux4 channel[5:4]
  -> mts_processor hit_out.asic
  -> mts_processor Type1 data[38:35]
  -> histogram Type1 tap input data[38:35]
```

## Build

Build directory:

```text
firmware_builds/systems/260518-feb-ok/syn/board_projects/fe_scifi_feb_v3
```

Edits in this debug image:

- Added preserved SignalTap shadows in `mutrig_timestamp_processor/mts_processor.vhd`:
  - `stp_asi_hit_type0_channel_q[5:0]`
  - `stp_asi_hit_type0_accept_q`
  - `stp_hit_out_asic_q[3:0]`
  - `stp_hit_out_valid_q`
  - `stp_aso_hit_type1_asic_q[3:0]`
  - `stp_aso_hit_type1_valid_q`
- Bumped MTS packaging patch version to 26.3.9.
- Expanded `mutrig_cfg_lvds.stp` `lvds_decoded` with mux/MTS/hist Type1 probes.
- Trigger: `mts_preprocessor_0_hit_type1_out_valid == high`.
- STP trigger CRC remained non-zero: `0x828CC147`.

Compile result:

| Item | Result |
|---|---:|
| Quartus full compile | PASS, 0 errors, 1643 warnings |
| SOF checksum programmed | `0x1A0A4E63` |
| ALMs | 56,346 / 91,680 (61%) |
| Registers | 93,830 |
| Block memory bits | 7,072,396 / 13,987,840 (51%) |
| RAM blocks | 910 / 1,366 (67%) |
| DSP blocks | 0 / 800 |
| PLLs | 7 / 21 |
| Slow 85C setup | -0.119 ns on `lvds_firefly_clk` |
| Worst hold | +0.063 ns |

Routing note: Quartus connected `lvds_decoded` to all 479 required debug inputs and routed successfully. Router estimated 21% average and 41% peak interconnect usage.

## Board setup

Programmed:

```text
quartus_pgm -c "USB-BlasterII [7-2]" -m JTAG -o "p;output_files/top.sof"
```

Post-program steps:

- Waited 20 s.
- `/dev/mudaq0` was present; no PCIe recovery needed.
- Lane-8 soft reset: `sc_tool 2 write 0x04006 0x00000100`.
- Re-ran canonical MuTRiG configure: `SUMMARY pass=24 fail=0`.
- One LVDS sanity read: `PHY_DPALOCK_STATUS @ 0x0400E = 0x000001FF`.
- Injector configured: mode 1, header interval 1, multiplicity 1, header delay 100, header channel 0, pulse high 5.
- Active capture run-control sequence reached `RESET_LINK_STATUS_REGISTER_R = 0x12000004`.
- Stopped cleanly after capture; final status returned to `0x13000000`.

Artifacts:

```text
configure_mutrig.log
dpalock_read.log
injector_config.log
run_start_transcript.log
stp_acquire.log
stp_acquire_active.log
mts_mux_capture_20260526T012117.csv
mts_mux_capture_active_20260526T012117.csv
run_stop_transcript.log
```

## Active capture histograms

The active capture is `mts_mux_capture_active_20260526T012117.csv`.

### Source lane activity

All eight Type0 lane taps are active in the 4096-sample capture:

| Lane | Valid samples |
|---:|---:|
| 0 | 941 |
| 1 | 910 |
| 2 | 923 |
| 3 | 943 |
| 4 | 911 |
| 5 | 923 |
| 6 | 939 |
| 7 | 912 |

This rules out `ONLY_ASIC0_ACTIVE`.

### Mux output channel

`mux_mutrig2processor_out_channel[5:4]` is populated and varies across all four mux slots:

| Probe | valid | slot 0 | slot 1 | slot 2 | slot 3 |
|---|---:|---:|---:|---:|---:|
| mux up `out_channel[5:4]` | 925 | 312 | 165 | 214 | 234 |
| mux down `out_channel[5:4]` | 933 | 305 | 162 | 228 | 238 |
| MTS0 sampled input channel[5:4] | 923 | 310 | 160 | 215 | 238 |
| MTS1 sampled input channel[5:4] | 934 | 304 | 158 | 232 | 240 |

This rules out `BUG_AT_MUX` in the specific "channel[5:4] always 0" sense. The mux is driving the grant slot into `channel[5:4]` as intended by `hit_type0_readyless_mux4.sv:247-257`.

### MTS derived ASIC field

MTS0 output `hit_out.asic` is not restricted to ASIC IDs 0..3. It contains almost every 4-bit value:

| Field | valid | top values |
|---|---:|---|
| `mts_preprocessor_0 stp_hit_out_asic_q` | 921 | 0:244, 8:122, 12:78, 14:76, 13:63, 4:61, 10:52, 7:42, 6:35, 3:35, 1:27, 11:26, 5:26, 15:17, 9:17 |
| `mts_preprocessor_0 stp_aso_hit_type1_asic_q` | 925 | 0:247, 8:121, 12:77, 14:77, 13:67, 4:58, 10:53, 7:42, 3:37, 6:33, 11:27, 5:25, 1:25, 15:19, 9:17 |
| `mts_preprocessor_0 Type1 data[38:35]` | 917 | 0:247, 8:120, 14:79, 12:76, 13:67, 4:61, 10:51, 7:39, 6:34, 3:32, 1:26, 11:26, 5:26, 9:18, 15:15 |
| `hist Type1-up tap data[38:35]` | 921 | 0:246, 8:121, 14:77, 12:76, 13:65, 4:62, 10:52, 7:42, 6:35, 3:35, 11:26, 1:26, 5:25, 9:17, 15:16 |

The Type1 pack stage and the histogram Type1-up tap preserve the same field. The bad value is already present at `hit_out.asic`.

### Down-bank observation

The down-bank path is not silent at the STP tap:

| Field | valid | top values |
|---|---:|---|
| `mts_preprocessor_1 Type1 data[38:35]` | 919 | 0:246, 8:120, 14:77, 12:77, 13:70, 4:59, 10:51, 7:43, 6:34, 3:33, 5:26, 11:25, 1:24, 9:17, 15:17 |
| `hist Type1-down tap data[38:35]` | 925 | 0:250, 8:117, 12:78, 14:77, 13:67, 4:61, 10:51, 7:43, 3:37, 6:34, 5:27, 1:26, 11:25, 15:16, 9:16 |

This means the earlier Type1-down histogram `TOTAL_HITS=0` observation is not explained by a dead MTS1 output or a disconnected Type1-down tap. It is likely downstream histogram configuration, source-select, or internal histogram-bank gating.

## File-line evidence

Mux RTL:

- `misc/hit_type0_readyless_mux4/rtl/hit_type0_readyless_mux4.sv:247-257` unpacks the stored low channel bits into `aso_out_channel[3:0]` and assigns `aso_out_channel[5:4] <= grant_idx`.

MTS RTL:

- `mutrig_timestamp_processor/mts_processor.vhd:528-542` defines `mux_slot_to_global_asic()`, intended to use `channel_v(5 downto 4)` plus the `BANK` offset.
- `mutrig_timestamp_processor/mts_processor.vhd:1820-1822` assigns `hit_in.asic <= mux_slot_to_global_asic(BANK, asi_hit_type0_channel)`.
- `mutrig_timestamp_processor/mts_processor.vhd:2081-2103` packs `hit_out.asic` into both Type1 `data[38:35]` and the STP shadow.

Generated wrapper:

- `firmware_builds/systems/260518-feb-ok/generated/synthesis/feb_system_v4/synthesis/submodules/feb_system_v4_data_path_subsystem.vhd:5684-5706` instantiates MTS0 with `BANK => "UP"` and feeds `mux_mutrig2processor_out_channel`.
- `firmware_builds/systems/260518-feb-ok/generated/synthesis/feb_system_v4/synthesis/submodules/feb_system_v4_data_path_subsystem.vhd:5743-5764` instantiates MTS1 with `BANK => "DW"` and feeds `mux_mutrig2processor_0_out_channel`.

## Verdict

Bug classification: `BUG_AT_MTS_DERIVATION`.

Reason: mux channel[5:4] is not stuck and all source lanes are active, but `hit_out.asic` is already not a valid per-bank ASIC index before the Type1 pack. The Type1 pack and histogram tap preserve that same bad 4-bit field, so this is not primarily a Type1 pack loss and not explained by a dead mux output.

More precise diagnosis: the compiled/observed MTS behavior still looks like it is carrying the hit channel nibble into the ASIC field, not the mux slot. The active capture's MTS0 `hit_out.asic` distribution closely resembles the lower-nibble channel distribution instead of the `channel[5:4]` slot distribution.

## Proposed next fix

Do not edit in this round. The smallest next RTL change should make the ASIC derivation explicit and hard to mis-synthesize:

```vhdl
if (BANK = "DW" or BANK = "DOWN") then
    hit_in.asic <= "01" & asi_hit_type0_channel(5 downto 4); -- ASIC4..7
else
    hit_in.asic <= "00" & asi_hit_type0_channel(5 downto 4); -- ASIC0..3
end if;
```

Apply this at `mutrig_timestamp_processor/mts_processor.vhd:1820-1822`, replacing the current function call. Optionally remove or keep `mux_slot_to_global_asic()` after the directed test is updated.

Recommended verification for that fix:

1. Standalone MTS directed sim: drive all four mux slots with distinct low channel nibbles and assert `data[38:35]` only follows the slot, not the low hit channel.
2. Recompile debug image with the same STP probes.
3. Re-capture MTS0 and MTS1:
   - MTS0 Type1 `data[38:35]` must contain only 0, 1, 2, 3.
   - MTS1 Type1 `data[38:35]` must contain only 4, 5, 6, 7.
4. Only after that, re-test histogram `KEY_VALUE = i << 16`. If the hist still rejects a value that appears at the Type1 tap, then classify the remaining issue as `BUG_AT_HIST_FILTER`.
