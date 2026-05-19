# merger_hit_type0

Per-lane readyless 2:1 mux between the real MuTRiG `hit_type0` stream (post
`mutrig_frame_deassembly`) and the emulator `hit_type0` stream. One CSR bit
picks the source. Replaces the 8-way `emulator_hit_type0_fanout` broadcast
pattern that was the root cause of FEB BUG-028-I (per-lane emulator
broadcast collisions at hist ingress).

## Files

| Path | Role |
|---|---|
| `rtl/merger_hit_type0.sv` | Pure-SystemVerilog implementation |
| `rtl/merger_hit_type0.f` | Filelist for downstream consumers |
| `script/merger_hit_type0_hw.tcl` | Platform Designer manifest |
| `tb/merger_hit_type0_tb.sv` | Directed Questa One self-check TB |
| `tb/Makefile` | Compiles + runs the TB with a fresh work dir (no rm-rf) |
| `syn/quartus/merger_hit_type0_standalone.{qsf,qpf,sdc}` | Standalone Quartus 18.1 project |
| `syn/quartus/merger_hit_type0_standalone_top.sv` | Pin-flattened wrapper |

## Streaming contract

All three Avalon-ST ports (`real_in`, `emu_in`, `out`) are **truly readyless**
per the FEB hit_type0 plane convention - no `ready` port declared, no
auto-inserted Platform Designer timing/channel/error adapters. The Avalon-ST
`channel` field carries the ASIC ID verbatim from the selected source; FEB
SciFi v3 / v4 maps physical lane id 1:1 onto ASIC id with no remap, so the
channel passes through unchanged.

| Field | Width | Notes |
|---|---|---|
| `data` | 45 | FEB hit_type0 payload |
| `valid` | 1 | combinational forward of selected source |
| `channel` | 4 | ASIC id (0..15) - lane id on FEB |
| `error` | 3 | hiterr / frameerr / overflow |
| `startofpacket` | 1 | forwarded |
| `endofpacket` | 1 | forwarded |
| `endofrun` | 1 | forwarded |

## CSR map

| Word | Address | Access | Field | Notes |
|---|---|---|---|---|
| 0 | `0x0` | R | `UID` | `0x4D484754` ("MHGT") |
| 1 | `0x1` | R | `VERSION` | `{MAJOR[8], MINOR[8], PATCH[4], BUILD[12]}` |
| 2 | `0x2` | R | `VERSION_DATE` | YYYYMMDD decimal |
| 3 | `0x3` | RW | `CONTROL` | bit 0: source_sel, `0`=REAL, `1`=EMU |

`SOURCE_SEL_DEFAULT` (HDL parameter) seeds CSR3 bit 0 at reset. Runtime
firmware can re-select via a single CSR write.

## Validation

- **Static screen**: `qverify` Lint / CDC / RDC on the bare RTL is clean (see `SYN_REPORT.md`).
- **TB**: `make -C tb run` exercises CSR identity, source switching via CSR
  bit, packet boundary forwarding, and end-of-run propagation. 17 directed
  checks, 0 errors.
- **Standalone Quartus 18.1**: `flow compile merger_hit_type0_standalone`
  succeeds with 0 errors. Fmax 67 MHz is I/O-bound (chip pin path dominates
  in the standalone build); in-system the merger sits between LVDS-clocked
  registers and never crosses chip pins.

## Integration plan

The merger is intended to replace `emulator_hit_type0_fanout` + the corresponding `arb_hit_type0_supercore` lanes on the FEB SciFi v4 datapath:

```
[old]
  mutrig_frame_deassembly_X.hit_type0   --> arb_hit_type0_supercore_0.real_in_X
                                                                       |
  emulator_mutrig.hit_type0 --> fanout.outX --> arb_hit_type0_supercore_0.emu_in_X
                                                                       |
                                                                       v
                                            arb_hit_type0_supercore_0.selected_out_X
                                                                       |
                                                                       v
                                                            hist_type0_laneX_tap.in

[new]
  mutrig_frame_deassembly_X.hit_type0   --> merger_hit_type0_X.real_in
                                                              |
  emulator_mutrig_laneX_stream.hit_type0 --> merger_hit_type0_X.emu_in
                                                              |
                                                              v
                                                merger_hit_type0_X.out
                                                              |
                                                              v
                                                  hist_type0_laneX_tap.in
```

The emulator must emit 8 independent `hit_type0` streams (one per ASIC id,
channel = ASIC id) instead of one stream broadcast through a fanout. The
emulator-side change is tracked separately under [BUG-028-I] in the FEB
build's BUG_HISTORY.

[BUG-028-I]: ../../firmware_builds/systems/260518-feb-ok/doc/BUG_HISTORY.md
