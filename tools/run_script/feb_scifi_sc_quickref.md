# FEB SciFi — Slow Control Quick Reference

## Critical: Address Convention

The sc_hub packet address field is **word-addressed** (NOT byte-addressed).

| Tool | Address format | Notes |
|------|---------------|-------|
| `test_slowcontrol` | 16-bit word address | Any value accepted |
| `sc_tool` | Word address (must be divisible by 4) | "4-byte alignment" check on raw input |

**Conversion**: Qsys byte address / 4 = packet word address.

## SC Slave Address Map (FEB SciFi)

| Slave | Qsys Byte | **Packet Word** | Regs | sc_tool base | Notes |
|-------|-----------|-----------------|------|-------------|-------|
| scratch_pad_ram | 0x00000 | **0x0000** | 256 | 0x00000 | R/W scratchpad |
| onewire_master_controller_0 | 0x11000 | **0x4400** | 8 | 0x04400 | 1-Wire temp sensors |
| max10_prog_avmm_0 | 0x12000 | **0x4800** | 15+64 | 0x04800 | MAX10 flash programmer |
| charge_injection_pulser_0 | 0x13000 | **0x4C00** | 1 | 0x04C00 | Write-only CSR |
| firefly_xcvr_ctrl_0 | 0x14000 | **0x5000** | 14 | 0x05000 | FireFly I2C monitor |
| on_die_temp_sense_ctrl | 0x15000 | **0x5400** | 1 | 0x05400 | FPGA die temperature |
| mm_bridge | 0x20000 | **0x8000** | - | 0x08000 | Bridge to datapath subsystem |
| mutrig_cfg_ctrl_0.avmm_csr | 0x3F010 | **0xFC04** | 4 | N/A (0xFC04%4!=0) | MuTrig config controller |
| sc_hub internal CSR | - | **0xFE80** | 32 | N/A | Hub diagnostics (use test_slowcontrol) |

## Programming

```bash
# FEB SciFi via USB-BlasterII [7-2]
quartus_pgm -c "USB-BlasterII [7-2]" -m JTAG -o "P;output_files/top.sof"

# SWB (A10 DE5) via DE5 [3-6.2] — USE online_sc REPO, NOT online_dpv2!
# quartus_pgm -c "DE5 [3-6.2]" ...
```

## Common Test Commands

### Read hub diagnostic counters
```bash
sc_tool 2 diag
```

### Read hub UID (expect 0x53434842 = "SCHB")
```bash
test_slowcontrol 2 --read 0xFE80 1 --once
```

### Read hub CSR (32 words from 0xFE80)
```bash
test_slowcontrol 2 --read 0xFE80 32 --once
```

### Read max10_prog_avmm ID (expect 0x4D3128xx)
```bash
test_slowcontrol 2 --read 0x4800 1 --once
# Or burst first 15 regs:
sc_tool 2 read 0x04800 15 --quiet
```

### Read onewire capability (expect 0x00000006)
```bash
test_slowcontrol 2 --read 0x4400 1 --once
```

### Read FPGA die temperature
```bash
test_slowcontrol 2 --read 0x5400 1 --once
# Result: bits[7:0] = signed temperature in degrees C
```

### Read FireFly sensor data (14 regs)
```bash
sc_tool 2 read 0x05000 14 --quiet
```

### Write/readback scratchpad
```bash
test_slowcontrol 2 --write 0x0000 0xDEADBEEF --once
test_slowcontrol 2 --read 0x0000 1 --once
```

### Write/readback max10_prog_avmm SCRATCH (word 0x4806)
```bash
test_slowcontrol 2 --write 0x4806 0xCAFEBABE --once
test_slowcontrol 2 --read 0x4806 1 --once
```

### Burst write + readback (scratchpad, 64 words)
```bash
sc_tool 2 write 0x00000 0x11111111 0x22222222 0x33333333 --quiet
sc_tool 2 read 0x00000 3 --quiet
```

### Non-incremental read (same address repeated)
```bash
sc_tool 2 read 0x00000 4 --noninc --quiet
```

## Run Control (via SWB reset link, NOT SC ring)

```bash
RW=/path/to/rw

# CMD_RESET: FEB=7 (broadcast), cmd=0x30
$RW wwr 0x28 0xE0000030

# CMD_STOP_RESET: FEB=7, cmd=0x31
$RW wwr 0x28 0xE0000031

# Check reset link status
$RW rr 0x34
```

## Hub Soft Reset (preserving enable)

```bash
# Assert soft_reset + keep enable (CTRL bits: enable=0, soft_reset=2)
test_slowcontrol 2 --write 0xFE82 0x00000005 --once   # bits 2,0 = soft_reset + enable
sleep 0.1
test_slowcontrol 2 --write 0xFE82 0x00000001 --once   # clear soft_reset, keep enable

# WARNING: Writing CTRL=0x04 (soft_reset without enable) then CTRL=0x00
# will leave the hub DISABLED — all subsequent SC reads will time out!
# Always keep bit 0 (enable) set: use 0x05 -> 0x01, NOT 0x04 -> 0x00.
```

## Key Register Quick Reference

### sc_hub CSR (word base 0xFE80)

| WOff | Name | Access | Default | Notes |
|------|------|--------|---------|-------|
| 0x00 | UID | RO | 0x53434842 | "SCHB" |
| 0x02 | CTRL | RW | 0x00000001 | enable[0], diag_clear[1], soft_reset[2] |
| 0x03 | STATUS | RO | 0x00000010 | busy[0], error[1], dl_full[2], bp_full[3], enable_state[4], bus_busy[5] |
| 0x04 | ERR_FLAGS | W1C | 0x00000000 | Write 1 to clear individual bits |
| 0x06 | SCRATCH | RW | 0x00000000 | General-purpose test register |
| 0x17 | PKT_DROP_CNT | RO | 0x00000000 | Dropped packet counter |
| 0x1F | HUB_CAP | RO | 0x0000000E | Hub capability flags |

### max10_prog_avmm (word base 0x4800)

| WOff | Name | Access | Default | Notes |
|------|------|--------|---------|-------|
| 0x00 | ID | RO | 0x4D3128xx | "M10P" variant |
| 0x01 | VERSION | RO | 0x00020000 | Build version |
| 0x02 | CTRL | WO | - | bit 0 = sw_reset (self-clearing pulse) |
| 0x03 | STATUS | RO | 0x00000001 | ready[0], busy[1], fault[2], resetting[3] |
| 0x06 | SCRATCH | RW | 0x00000000 | Test register |

## Troubleshooting

### SC reads time out (no reply)
1. Check link: `sc_tool 2 diag` — look for `LINK_LOCKED_HIGH` including link 2
2. Hub might be disabled: `test_slowcontrol 2 --read 0xFE82 1 --once` — CTRL should be 0x01
3. If hub disabled: `test_slowcontrol 2 --write 0xFE82 0x00000001 --once`
4. If still no reply: reprogram FEB via `quartus_pgm -c "USB-BlasterII [7-2]" -m JTAG -o "P;output_files/top.sof"`

### SC secondary ring flooded / stale data
- Both `sc_tool` and `test_slowcontrol` reset the SC secondary ring at startup
- If reads return garbage: reprogram the FEB (fastest recovery)
- Rapid-fire SC operations without draining replies can flood the ring

### "SLVERR" on test_slowcontrol replies
- **False positive**: test_slowcontrol uses a v1 reply decoder that mis-parses the sc_hub v2 ack overlay as SLVERR
- The payload data is correct; ignore the SLVERR label
- sc_tool correctly decodes v2 replies (shows `rsp: OK`, `ack: 1`)

### sc_tool "address must be 4-byte aligned"
- sc_tool applies a 4-byte alignment check to its input
- For word addresses not divisible by 4 (e.g., mutrig_cfg_ctrl at 0xFC04), use `test_slowcontrol` instead

### BUG: hist_bin burst reads corrupt entire datapath subsystem
- **NEVER** burst-read `histogram_statistics.hist_bin` (word 0x0A800 or 0x0AA00) with burstcount >= 2
- Single-word reads from hist_bin are safe
- A burst read writes 0xEEEEEEEE to ALL registers of ALL IPs behind `mm_bridge`
- Recovery requires FEB reprogramming
- Burst reads from `histogram_statistics.csr` and all other bridge slaves are safe
