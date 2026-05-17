# Upload Ready SC Retest - 2026-05-18

## Scope

This note records the sim-first A/B and board retest for the FEB V3 upload
backpressure regression introduced around `c85daa06`.

Root cause:

```text
data_path_subsystem.hit_type3_upper -> avalon_st_adapter -> upload_subsystem.upload_data
```

The inserted adapter removed the upstream ready contract for the histogram
upper stream. Upload input 0 could remain selected while the downstream side
was stalled, which blocked upload input 1 slow-control packets and starved
input 2 IDLE/K28.5 generation. On the board this showed up as no matching SC
secondary reply.

Fix under test:

```text
hist_post_splitter_0.USE_READY=1
hit_stack_subsystem_0.hit_type3 -> hist_post_splitter_0.in
```

Generated wrapper evidence after regeneration keeps the adapter ready-coupled:

```text
inUseReady => 1
in_0_ready => data_path_subsystem_hit_type3_upper_ready
out_0_ready => avalon_st_adapter_out_0_ready
```

## Sim A/B

Broken repro command:

```text
make -C firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/tb_int/upload_backpressure run MODE=broken
```

Broken marker:

```text
UPLOAD_BACKPRESSURE_BROKEN_REPRO in0_valid_held=80 in0_ready_pulses=69 in1_sc_valid_held=11487 in1_sc_ready_pulses=0 sc_words=0 in2_ready_pulses=1 idle_words=1 missed_eop=10
```

Fixed ready-adapter command:

```text
make -C firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/tb_int/upload_backpressure run MODE=ready_adapter
```

Fixed marker:

```text
UPLOAD_BACKPRESSURE_FIXED_PASS in0_valid_held=234 in0_ready_pulses=72 in1_sc_ready_pulses=4 sc_words=4 sc_eop_accepted=1 in2_ready_pulses=11770 idle_words=11769 eop_accepted=9
```

Interpretation: the broken Qsys contract reproduces the no-SC condition in
`tb_int` before the source fix. The ready-coupled path accepts the SC EOP and
keeps the IDLE generator alive.

## Build Evidence

Qsys generation:

```text
status: syn/feb_system_v3_qsys_generate_upload_sc_ready_fix_20260518_003220_isolated.status
exit_code=0
error_count=0
fanout_guard=passed
nshd_guard=passed
```

Quartus compile:

```text
revision: syn/board_projects/fe_scifi_feb_v3/top
result: Full compilation successful
errors: 0
warnings: 1562
elapsed: 00:53:12
processing ended: 2026-05-18 01:29:45
```

Image checksums:

```text
top.sof sha256=5e878dc1410d49de6a488185cf92047dabd505428feecf590decd12ce8167cec
top.rbf sha256=579e0283afe447ab2dc2c3d426d36d0d8ebf75f49b85fadda6eccd0a858dcc08
quartus_pgm checksum=0x13C1B4E6
```

## Board Baseline

Before programming the fixed image:

```text
SWB_LINK_MASK_SCIFI=0x00000000
LINK_LOCKED_LOW median=0x00000F00
LINK_LOCKED_LOW stable@1 bits=b11,b10,b9,b8
LINK_LOCKED_LOW stable@0 includes b6,b2
LINK_LOCKED_HIGH median=0x00000000
link 2 SC_HUB_UID read: timed out, secondary delta=0 word(s)
```

## Board Retest

Program command:

```text
tools/run_script/program_feb.sh firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/syn/board_projects/fe_scifi_feb_v3/output_files/top.sof --settle 20 --cable "USB-BlasterII [7-2]"
```

Programming result:

```text
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
settle window elapsed
```

Post-program link status:

```text
LINK_LOCKED_LOW median=0x00000F00
LINK_LOCKED_LOW stable@1 bits=b11,b10,b9,b8
LINK_LOCKED_LOW stable@0 includes b6,b2
LINK_LOCKED_HIGH median=0x00000000
```

Post-program SC hub UID read on link 2:

```text
addr=0x0FE80 len=1
timing matched=72 us
secondary delta=5 word(s)
payload[0]=0x53434842
```

Post-program SC diagnostics on link 2:

```text
diag reads matched in 78 us
ERR_FLAGS=0x00000000
ERR_COUNT=0x00000000
PKT_DROP_CNT=0x00000000
```

Data-ingress mask spot checks:

```text
SWB_LINK_MASK_SCIFI=0x00000004
link 2 SC_HUB_UID payload[0]=0x53434842
timing matched=73 us

SWB_LINK_MASK_SCIFI=0x00000044
link 2 SC_HUB_UID payload[0]=0x53434842
timing matched=25243 us
warning: secondary pointer delta did not match packet size; extra traffic present

SWB_LINK_MASK_SCIFI restored to 0x00000000
final link 2 SC_HUB_UID payload[0]=0x53434842
timing matched=69 us
secondary delta=5 word(s)
```

## Conclusion

The no-SC-packet symptom is reproduced by the broken readyless upload path in
`tb_int`, and the ready-restored path fixes the simulated starvation. On
hardware, the fixed SOF restores link 2 slow-control hub replies.

The SWB `LINK_LOCKED_LOW` status still does not show bits 2 or 6 as stable high
even while link 2 SC replies are valid. Treat that as a separate SWB status or
lane-lock indication issue; it is no longer equivalent to "no SC packet reaches
the SC hub" for this fixed image.
