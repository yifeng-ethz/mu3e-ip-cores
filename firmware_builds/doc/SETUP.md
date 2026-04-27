# SETUP.md - FEB SciFi Phase-5 hardware setup reference

Date: 2026-04-27

This is the centralized hardware setup note for real FEB SciFi / MuTRiG debug.
Load this file before running live-board Phase-5 work.

## System Topology

- The FEB SciFi prototype is reached through the SWB on slow-control link 2.
- There are two SciFi Module Boards (SMBs), each connected to four MuTRiG3 ASICs.
- Each MuTRiG3 ASIC contributes one 1.25 Gbps LVDS link.
- The datapath is segmented into two hit-stack subsystems. One SMB feeds one hit-stack subsystem.
- Upper side: SMB3, lanes 0..3.
- Down side: SMB5, lanes 4..7.

## Firmware Images

| Board | Image source | Notes |
|---|---|---|
| SWB A10 | `online_sc/online/switching_pc/a10_board/output_files/top.sof` | Source of truth for `/dev/mudaq0`, reset link, and SC bridge behavior. Do not use the `online_dpv2` SWB SOF for this bring-up. |
| FEB SciFi | `board_projects/fe_scifi_feb_v3/output_files/top.sof` or the active `top_nostp_pipe` SOF | Built from this repo and the active system under `firmware_builds/systems/system_20260427_testplanphase5/`. |

Cold-start sequence:

1. Program the SWB from `online_sc`.
2. Program the FEB SciFi image from this repo.
3. Run `sudo -n /usr/local/sbin/mudaq_recover_pcie` after any SWB reflash or if `/dev/mudaq0` returns all ones.
4. Verify `lsmod | grep mudaq` and `ls /dev/mudaq0`.
5. Build local tools with `firmware_builds/systems/system_20260427_testplanphase5/script/build_local_tools.py`.
6. Check SC with `firmware_builds/systems/system_20260427_testplanphase5/bin/sc_tool 2 read 0x00000`.

The detailed board-test playbook remains `firmware_builds/doc/TEST_PLAN.md`.

## MuTRiG Configuration Files

The MuTRiG Controller hardware is intentionally simple: it writes SPI bitmap
payloads and toggles control strobes. The complex part is software-side
conversion from `.txt` or `.xml` configuration files into the bitstream and
write sequence.

Known useful examples:

| Use | File | Scope |
|---|---|---|
| TDC injection, SMB3 | `board_test_system/trash_bin/good_ribbon_0/config_smb3_tdc.txt` | Upper side reference. |
| TDC injection, SMB3 XML | `board_test_system/trash_bin/ribbon_eth_0/config_smb003_tdc_all_OK.xml` | Upper side lanes 0..3 only. Good for rate/channel alive-dead tests, but PLL lock is not guaranteed. |
| TDC injection, SMB5 | `board_test_system/trash_bin/good_ribbon_0/config_smb5_tdc.txt` | Down side reference. Should be preferred for SMB5 PLL-lock bring-up. |
| Analog mode, SMB3 | `board_test_system/trash_bin/good_ribbon_0/config_smb3_ana_asic-0123.txt` | Upper side analog-input reference. |
| Analog mode, SMB5 | `board_test_system/trash_bin/good_ribbon_0/config_smb5_ana_alt-asic2-fineTune.txt` | Down side analog-input reference. Some ASICs may still need PLL tuning. |

## Injection and Analog Modes

MuTRiG3 has two relevant bring-up modes:

- TDC injection on: the analog frontend input is cut off. The external trigger
  connected to the shared MuTRiG injector physical bus injects into the digital
  TDC fine/coarse counters and submits hits.
- Analog frontend on: the analog CML driver is enabled. In XML configs this is
  the `<cml>` setting; change `<cml>0</cml>` to `1` when moving from injection
  to analog-input testing.

For rate and channel alive/dead testing, keep the MTS timestamp-delay error
sideband asserted and forwarded. In the active upper-side path, the histogram
tap sits before the ring-buffer CAM filter, so `histogram_statistics_0` can
still accumulate rate while downstream decides whether to trim bad timestamps.
The ring-buffer CAM filter is `CTRL[4] filter_inerr` and defaults to on.

Only use MTS CONTROL_STATUS bit 5 when a local MTS trim is explicitly wanted:

```bash
firmware_builds/systems/system_20260427_testplanphase5/script/probe_phase4_stage_counters.py \
  --mts-drop-delay-error on
```

For PLL-lock validation, leave MTS local drop off and observe the error rate:

```bash
firmware_builds/systems/system_20260427_testplanphase5/script/probe_phase4_stage_counters.py \
  --mts-drop-delay-error off
```

## Slide References

- `docs/Archive/testbeam-2025_data_format.pptx`, slides 29..35:
  Histogram Statistics IP delay signatures. Slide 29 is a good locked case,
  slide 31 shows hot noise, slide 32 shows PLL fine-tuning reducing TDC noise,
  slides 33..34 show fully unlocked broad timestamp distributions, and slide
  35 shows the timestamp-aliasing view when the local histogram timestamp guess
  is disabled.
- `docs/Archive/eth_mu3e_jamboree.pptx`, slides 2..10:
  MuTRiG timestamp to global timestamp math, plus system-latency and
  resequencing-buffer context.

## Open Items To Confirm

- Exact production helper to convert the listed `.txt`/`.xml` MuTRiG configs
  into the `mutrig_cfg_ctrl_0` staged bitmap for this standalone board-test
  flow.
- Whether any SMB5 analog config has a newer PLL-tuned replacement after
  `config_smb5_ana_alt-asic2-fineTune.txt`.
- Any board-specific power, ribbon, or injector-bus caveats not captured above.
