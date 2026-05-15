# Pulserdrop RN.BASIC.001 Upstream Trace - 2026-05-13

Scope: RN.BASIC.001 only.

RN.BASIC.001 row source: `TEST_BASIC.md`, `lane_mask=0xFF`,
`channel_mask=0xFFFFFFFF`, injector periodic mode 2, `rate_88fp=0x0040`,
theoretical 31,250 hits in the nominal 1 ms window. The cosim reference
remains the truth source for the expected end-to-end packet shape.

Status: PARTIAL. The missing pulserdrop `arb_hit_type0_supercore`
route was restored through the Tcl regeneration flow, the FEB debug image
was rebuilt/flashed, the live arb CSR aperture is no longer all-zero, and
host-run RN.BASIC.001 now moves emulator hits through arb/histogram with
zero arb drops. Full dispatch PASS is not claimed because OPQ ingress and
OPQ egress STP were not compiled/captured, and the FEB egress STP frames
captured on silicon do not satisfy the requested `sub_count=128` check.

## Step 1 - Qsys Arb Route

The cosim and pulserdrop regenerator Tcl flows were diffed. The
pulserdrop build was missing the generated `arb_hit_type0_supercore`
integration artifacts and the routable CSR/data-path connection that the
cosim tree already had.

Fixes were made only under `script/` and applied through the regenerator:

| File | Purpose |
|---|---|
| `script/build_arb_hit_type0_supercore_qsys.tcl` | builds the supercore Qsys component used by the pulserdrop data path |
| `script/refresh_feb_system_v3_datapath_instance.tcl` | refreshes the generated data-path instance after the arb component is present |
| `script/apply_pulserdrop_arb_qsys.sh` | applies the pulserdrop arb route recipe |
| `script/qsys_search_path.sh` | includes the regenerated arb component in the Qsys catalog path |
| `script/generate_feb_system_v3.sh` | regenerates the FEB Qsys tree and enforces read-only generated outputs |
| `script/clone_refactor_v3_emulator_type0_qsys.tcl` | aligns the pulserdrop data-path topology with cosim and configures readyless run-control splitters for board debug |

No generated `.qsys`, `.sopcinfo`, IPX, or `synthesis/` tree was
hand-edited. Regeneration command:

```sh
QSYS_GENERATE_STAMP=20260513_pulserdrop_arb_live_sc_csr6_readyless_v2 \
  firmware_builds/systems/v3_pretest-260511-pulserdrop-260512/script/generate_feb_system_v3.sh
```

Regeneration result:

| Check | Result |
|---|---|
| status file | `syn/feb_system_v3_qsys_generate_20260513_pulserdrop_arb_live_sc_csr6_readyless_v2_isolated.status` |
| qsys-generate exit | `exit_code=0`, `error_count=0` |
| generated tree protection | generated `.qsys`, `.sopcinfo`, and `synthesis/` outputs set read-only by the wrapper |
| live arb CSR | `0x088A0` reads UID `0x41486430`, version `0x1A060200` |
| live arb CSR write/readback | control write/readback at `0x088A4` succeeded (`0x000001F4`) |

`emulator_mutrig/emulator_mutrig_hw.tcl` was also fixed to export
`CSR_ADDR_WIDTH=6` and version `26.3.1.0513`, because the live board CSR
map needs upper word `0x12` for `LANE_ENABLE`. Post-flash readback showed
UID `0x454D5554`, version `0x1A0301FA`, and `LANE_ENABLE=0x000000FF` at
`0x08812`.

## Step 2 - SignalTap

FEB egress SignalTap was added and compiled into the FEB debug image:

| File | Purpose |
|---|---|
| `script/generate_pulserdrop_rn001_feb_egress_stp.py` | generates the FEB egress STP with 36b `{datak,data}` and valid |
| `syn/board_projects/fe_scifi_feb_v3/pulserdrop_rn001_feb_egress.stp` | default valid-rise capture |
| `syn/board_projects/fe_scifi_feb_v3/pulserdrop_rn001_feb_egress_hitcount.stp` | debug trigger variant used while trying to avoid idle frames |
| `script/capture_signaltap_vcd_hw.tcl` | noninteractive Quartus STP capture and VCD export |
| `script/decode_rn001_feb_egress_vcd.py` | VCD decoder for K28.5/K28.4/K23.7 frame fields |

SWB OPQ STP was staged as
`firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10/rn001_opq_ingress_egress.stp`,
but the SWB image was not recompiled, reflashed, or captured in this
dispatch. The SWB DMA packer files were not touched.

## Step 3 - FEB Compile And STA

Compile command:

```sh
cd firmware_builds/systems/v3_pretest-260511-pulserdrop-260512/syn/board_projects/fe_scifi_feb_v3
quartus_sh --flow compile top -c top
```

Log: `codex_pulserdrop_feb_rn001_stp_compile_csr6_readyless_20260513.log`.

| Stage | Result |
|---|---|
| Analysis and Synthesis | successful, 0 errors, 1915 warnings |
| Fitter | successful, 0 errors, 32 warnings |
| Assembler | successful, 0 errors, 1 warning |
| Timing Analyzer | successful, 0 errors, 26 warnings |
| Full compile | successful, 0 errors, 1974 warnings |
| STP instance | `rn001_feb_egress` generated and connected |

STA result under the requested STP-debug relaxation:

| Corner | Worst setup slack | Verdict |
|---|---:|---|
| Slow 1100 mV 85 C | `-0.944 ns` | FAIL for production, accepted for debug |
| Slow 1100 mV 0 C | `-0.748 ns` | FAIL for production, accepted for debug |
| Fast 1100 mV 85 C | `+0.442 ns` | PASS |
| Fast 1100 mV 0 C | `+0.666 ns` | PASS |

Debug-image timing verdict: 2/4 corners pass, acceptable for this STP
debug dispatch. This is not production timing signoff.

Output hashes are recorded in
`codex_pulserdrop_feb_rn001_stp_csr6_readyless_sha256_20260513.txt`.
The flashed `top.sof` hash was:
`e6f31c1da1981cd14eac40a7dfa02da406db017b0d7e19d7b6a2a64b219e882d`.

## Step 4 - Reflash And Board Evidence

Bench claim:
`/home/yifeng/packages/mu3e_ip_dev/.bench_queue/ticket_20260513T193643Z_codex_pulserdrop_arb_stp_recompile.txt`.

FEB flash used:

```sh
tools/run_script/program_feb.sh \
  firmware_builds/systems/v3_pretest-260511-pulserdrop-260512/syn/board_projects/fe_scifi_feb_v3/output_files/top.sof
```

Programming through `USB-BlasterII [7-2]` succeeded, followed by the
mandatory 20 s post-program settle. PCIe recovery via
`sudo -n /usr/local/sbin/mudaq_recover_pcie` recovered device
`0000:0b:00.0` and reloaded `mudaq`.

Board helper:
`script/run_rn001_direct_periodic_board.py`.

Run-control observation:

| Source | Evidence | Result |
|---|---|---|
| `dbg_mm2runctrl_0` | `RN.BASIC.001_readyless_run_20260513_224637/board_summary.json` | all 4 debug commands accepted, but arb/hist counters stayed zero |
| `runctl_mgmt_host_0` | `RN.BASIC.001_readyless_run_20260513_224837/board_summary.json` | arb ingress delta `155744`, arb egress delta `155744`, arb drops delta `0`, histogram total delta `336083` |
| `runctl_mgmt_host_0` | `RN.BASIC.001_readyless_periodic_20260513_225431/board_summary.json` | arb ingress delta `212032`, arb egress delta `212032`, arb drops delta `0`, histogram total delta `433917` |

The host-run deltas are a live data-flow proof, not a rate claim. The
existing host runner includes SC/log-drain overhead around the nominal
1 ms row window, so the absolute hit counts are larger than the row's
theoretical 31,250-hit 1 ms value.

## Step 5 - STP Decode

The VCD decoder samples one exported `i_clk_156` phase and decodes the
FEB wire frame as emitted by `feb_frame_assembly`: K28.5 start at word
LSB, two data headers, two debug headers, K23.7 subheaders, payload
hits, and K28.4 trailer.

Captured FEB egress STP evidence:

| Capture | Trigger | K28.5 | K28.4 | Closed frames | Subheaders | Hits in decoded frame | Verdict |
|---|---|---:|---:|---:|---:|---:|---|
| `RN.BASIC.001_readyless_stp_20260513_2247/feb_egress_decode.json` | valid rising edge during dbg/host run sequence | 1 | 1 | 1 | 257 | 16 | FEB egress nonzero, sub-count FAIL |
| `RN.BASIC.001_readyless_stp_20260513_2257/feb_egress_decode.json` | valid rising edge immediately before host run | 1 | 1 | 1 | 257 | 0 | idle/transition frame, sub-count FAIL |
| `RN.BASIC.001_readyless_stp_hitcount_20260513_2259/feb_egress_decode.json` | attempted hit-count bit trigger | 1 | 1 | 1 | 256 | 0 | trigger caught a header/frame-id transition, sub-count FAIL |

The important positive result is that FEB egress is no longer lossy-zero:
K28.5 and K28.4 are both visible on silicon after the arb restoration.
The important negative result is that no captured FEB egress frame had
`sub_count=128`; captured debug headers reported 256 or 257 subheaders.
That is not cosim-equivalent to the user-stated RN.BASIC.001 frame
contract and remains open.

## PASS Criteria

| Criterion | Result |
|---|---|
| FEB egress STP K28.5 count > 0 | PASS: FEB egress captures have K28.5=1 |
| FEB egress K28.5 count equals K28.4 count | PASS for captured frames: 1 / 1 |
| Every captured FEB frame has `sub_count == 128` | FAIL: captured subheader counts were 256 or 257 |
| Arb CSR aperture no longer all-zero | PASS: `0x088A0` reads UID `0x41486430`, version `0x1A060200` |
| Arb CSR write/readback works | PASS: control write/readback at `0x088A4` succeeded |
| Host-run arb ingress equals arb egress with zero drops | PASS: observed deltas `155744 == 155744`, later `212032 == 212032`, drops `0` |
| OPQ ingress STP count > 0 and equals FEB egress | NOT RUN: SWB STP not compiled/flashed/captured |
| OPQ egress STP count > 0 and equals FEB egress | NOT RUN: SWB STP not compiled/flashed/captured |
| BU012/013/014/020/025 all flip to PASS | NOT RUN as a BU bucket; BU014's live arb aperture prerequisite is fixed |
| Standalone tb for touched IP RTL | N/A: no IP RTL functional change was made |
| Cosim RN.BASIC.001 still PASSes | Not rerun after the board dispatch; prior cosim evidence remains the reference baseline |

Final verdict: PARTIAL. The dispatch successfully restored the missing
arb route and proved nonzero FEB egress frames on silicon, but it did not
close the requested silicon packet-shape contract or the OPQ checkpoint
chain.

## Follow-Up

1. Add or retarget the FEB STP trigger to capture only a nonempty K23.7
   subheader (`datak[0]=1`, `data[7:0]=0xF7`, and hit-count bits nonzero)
   rather than the first valid/idle frame.
2. Debug why live FEB egress frames report 256/257 subheaders when the
   requested RN.BASIC.001 contract expects 128.
3. Compile/flash the staged SWB OPQ STP only after the FEB frame-shape
   issue is understood, leaving the SWB DMA packer path untouched.

## Bench Claim

`status=RELEASED`

`released_at=2026-05-13T20:56:18Z` (`2026-05-13T22:56:18+02:00`)
