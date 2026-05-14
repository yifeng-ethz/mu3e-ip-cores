# BUG_HISTORY.md - swb rdma_pretest-260511 tb_int DV bug ledger

Class legend:
- `R` = RTL / DUT integration bug
- `H` = harness / testcase / reporting bug

Severity legend:
- `soft error` = the bad packet/data flushes through the stream and does not leave the later datapath stuck
- `hard stuck error` = the bug poisons later packet handling and typically needs a functional reset / fresh restart to recover
- `non-datapath-refactor` = observability, reporting, harness, or naming/accounting consistency work with no direct packet-contract effect

Encounterability legend:
- practical severity is `severity x encounterability`, so the index must say how likely a reader is to hit the bug in normal use rather than only when it first appeared in one simulation log
- nominal datapath operation = legal SWB RDMA ingress, OPQ four-lane traffic, event-builder packing, host DMA push, and no forced error injection or artificially pathological stalls
- nominal control-path operation = routine bring-up / CSR program / readback / clear-counter sequences
- `common (...)` = readily hit in nominal operation
- `occasional (...)` = hit in nominal operation without heroic setup, but not in every short run
- `rare (...)` = legal in nominal operation, but usually needs long runtime or unlucky alignment
- `corner-only (...)` = requires a legal but non-nominal stress or corner profile
- `directed-only (...)` = requires targeted error injection, formal/probe flow, reporting-only flow, or another non-operational stimulus

Fix status detail contract for active entries and future updates:
- `state` = fixed / open / partial plus the current verification gate
- `mechanism` = how the implemented repair changes the RTL or harness behavior
- `before_fix_outcome` and `after_fix_outcome` = concise evidence showing what changed
- `potential_hazard` = whether the fix looks permanent or is still provisional / profile-limited
- `Claude Opus 4.7 xhigh review decision` = explicit review state; use `pending / not run` until that review has actually happened

Historical formal note:
- This ledger starts with the SWB rdma_pretest-260511 integration harness on 2026-05-11.
- Historical standalone IP formal notes remain in the source IP repositories.

## Index

| bug_id | class | severity | encounterability | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| [BUG-001-H](#bug-001-h-swb-tb-int-had-no-local-synthesis-tree-for-basic-smoke) | H | non-datapath-refactor | `directed-only (harness preflight)` | fixed | `B065` structural preflight | `pending` | SWB tb_int could not run its first BASIC smoke until a local staged board project and Qsys synthesis outputs existed. |
| [BUG-002-H](#bug-002-h-phase-1-link-2-legacy-lvds-smoke-bypassed-the-physical-link-boundary) | H | non-datapath-refactor | `directed-only (hardware debug repro)` | open | `B067` Phase 1 legacy-link preflight | `pending` | Existing SWB tb_int cases pass through abstract RDMA/OPQ/DMA interfaces and do not exercise firefly lock, LVDS word alignment, or LINK_LOCKED[2]. |
| [BUG-003-H](#bug-003-h-legacy-swb-dma-path-stripped-mu3e-wire-frame-structure) | H | datapath-contract | `always-on (every SWB DMA capture)` | partial | `RN.BASIC.050` cosim / `#109` host rxbuffer trace | `pending` | The legacy SWB DMA path emitted flat 64-bit hit records instead of full Mu3e wire-frame words. |
| [BUG-004-R](#bug-004-r-swb-firmware-left-dirty-k284-trailer-metadata-and-no-idle-sop-guard) | R | datapath-contract | `always-on (OPQ egress marker contract)` | partial | `RN.BASIC.001` RDMA popup / K-symbol audit | `pending` | SWB firmware could forward a true K28.4 trailer with nonzero metadata bits and had no simulation guard for illegal Idle-frame SOPs at the OPQ-to-DMA boundary. |
| [BUG-005-H](#bug-005-h-swb-opq-signaltap-used-optimized-wrapper-aliases) | H | non-datapath-refactor | `directed-only (SignalTap compile gate)` | fixed-debug-loadable | RN.BASIC.001 SWB OPQ STP Node Finder | `d0b58930` / `bc192229` | The OPQ STP targeted wrapper-local aliases that Quartus optimized or exposed only as aggregate nodes, so the debug image could not prove the OPQ-to-DMA boundary. |
| [BUG-006-H](#bug-006-h-board-rate-hist-readout-sampled-the-empty-post-run-1-ms-bank) | H | non-datapath-refactor | `common (1 ms board histogram readback after END_RUN)` | fixed-harness / board-rerun-pending | RN.BASIC.001 pre/post rbCAM board pair, 2026-05-14 | `pending` | The board runner compared post-END `hist_bin` data even though the 1 ms ping-pong histogram had already advanced into empty post-run intervals. |
| [BUG-007-R](#bug-007-r-histogram-ingress-bridge-can-remain-pending-on-a-stale-packet-state) | R | non-datapath-refactor | `common (pre/post histogram source switching after partial traffic)` | open | RN.BASIC.001 live RUNNING hist samples, 2026-05-14 | `pending` | The histogram ingress bridge can report a pending pre/post switch while a stale packet-active bit prevents the requested source from becoming live. |

## 2026-05-14

### BUG-006-H: Board rate hist readout sampled the empty post-run 1 ms bank
- First seen in:
  - `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/REPORT/rn001_rbcam_rate_pre_post_pair_20260514_1637.json`
  - `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/REPORT/STP_OPQ_RN001_PRE_RATE_MIDRUN_20260514_164249/board/RN.BASIC.001_swb_dma_packer_20260514_164250/board_summary.json`
- Symptom:
  - Four `RN.BASIC.001` pre/post rbCAM runs all reported `hist_bin` sums of
    zero when the script read bins after `END_RUN`.
  - Two pre-rbCAM runs still had decoded RDMA data (`3381` and `193`
    canonical 128-subheader frames), while both post-rbCAM runs produced zero
    RDMA bytes. Those two nonzero rxbuffer runs are not treated as clean PASS
    evidence because the later runs are empty and the DMA buffer may contain
    stale/drained data.
  - The mid-run board attempt had nonzero histogram CSR evidence before END:
    `TOTAL_HITS = 3835`, `LAST_INTERVAL_TOTAL_HITS = 8225`,
    `INTERVAL_CFG = 125000`, and `PORT_STATUS = 0x000200FF`; the post-END
    summary then read `TOTAL_HITS = 0`, `LAST_INTERVAL_TOTAL_HITS = 0`, and
    zero bins.
- Root cause:
  - The board runner configured `INTERVAL_CFG = 125000` (1 ms at 125 MHz) but
    read all 256 histogram bins only after `END_RUN` plus terminate/drain time.
  - `histogram_statistics_v2` defines `TOTAL_HITS` as a live current-interval
    counter, `LAST_INTERVAL_TOTAL_HITS` as the most recent completed interval,
    and `hist_bin` as the frozen completed ping-pong bank. After the run stops,
    later 1 ms empty intervals legitimately overwrite the visible completed
    interval with zeros.
- Fix status:
  - state:
    - fixed-harness for the readout phase; board rerun with the new harness is
      pending
  - mechanism:
    - `run_swb_dma_packer_rn001_board.py` now owns SC reads through the same
      open `/dev/mudaq0` MMIO mapping used for the run-control sequence, so it
      can sample histogram CSR words and optional 256-bin snapshots during
      RUNNING without launching a competing `sc_tool` process
    - `run_rn001_rbcam_pre_post_pair.py` now requests RUNNING histogram CSR
      probes and one 256-bin RUNNING sample by default
    - board summaries keep post-run histogram bins as teardown evidence but
      select RUNNING-phase bins for rate/delay comparisons when available
  - before_fix_outcome:
    - `rate_comparison.active_bin_sum = 0` and `inactive_bin_sum = 0` on all
      four pre/post runs, including runs with nonzero decoded RDMA frames
  - after_fix_outcome:
    - `tools/run_script/sc_tool.cpp` now has a single-process `histbins`
      command so the runner can read 256 bins during RUNNING without reopening
      the control path 256 separate times
    - `RN.BASIC.001_swb_dma_packer_20260514_170457` completed a clean
      RUNNING read of 256 bins with `error_count = 0`; the bin sum `8172`
      agrees with `LAST_INTERVAL_TOTAL_HITS = 8174` to within two hits
    - the same run is not accepted as a pre-rbCAM rate comparison because
      `ingress_status.bank0 = 0x00000105`, which decodes as live post,
      requested pre, switch pending, and `pre_packet_active = 1`
    - `RN.BASIC.001_swb_dma_packer_20260514_170640` showed post-run bins are
      not useful for the 1 ms setting and the RUNNING sample itself had
      `histbins` `error_count = 3`; it is therefore not accepted as a
      47-channel post-rbCAM physics result
    - `RN.BASIC.001_swb_dma_packer_20260514_171247` used the guarded runner and
      explicitly reported `post_run_rate_comparison.evidence_valid = false`
      with the reason that post-run bins are expected to reflect empty 1 ms
      intervals after `END_RUN`
  - potential_hazard:
    - medium; single-word reads of 256 bins during RUNNING can span multiple
      1 ms completed banks, so the result is acceptable only for stable-flow
      min/p50/max checks, not for exact same-interval per-bin conservation
    - high if the histogram ingress source status is not decoded; a pre/post
      key can be programmed while the bridge is still live on the other source
  - Claude Opus 4.7 xhigh review decision:
    - pending / not run in this turn
- Expected RN.BASIC.001 histogram targets:
  - rate preset: `256` active channels, `31264` hits/ms total,
    `122.125` hits/channel/ms; acceptable per-channel bins should cluster at
    `122` or `123` counts for a 1 ms interval
  - delay preset: range `[-1000, 3096)` cycles with 16-cycle bins; expected
    pre-rbCAM min/p50/max is approximately `27/536/1043` cycles and expected
    post-rbCAM min/p50/max is approximately `2000/2100/2196` cycles
- Commit:
  - pending

### BUG-007-R: Histogram ingress bridge can remain pending on a stale packet state
- First seen in:
  - `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/REPORT/RN.BASIC.001_swb_dma_packer_20260514_170457/board_summary.json`
  - `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/REPORT/RN.BASIC.001_swb_dma_packer_20260514_170640/board_summary.json`
  - `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/REPORT/RN.BASIC.001_swb_dma_packer_20260514_171247/board_summary.json`
- Symptom:
  - The runner requested the pre-rbCAM histogram source and programmed the pre
    rate key `KEY_LOC = 0x2623251E`, but the bridge status read
    `ingress_status.bank0 = 0x00000105`.
  - Decoding `histogram_ingress_bridge.vhd` status bits gives:
    `select_post_live = 1`, `select_post_req = 0`, `switch_pending = 1`, and
    `pre_packet_active = 1`.
  - The resulting RUNNING histogram bins are not meaningful for the requested
    source. In the `170457` run only seven bins were nonzero even though
    RN.BASIC.001 expects all 256 channels active at about `122/123`
    hits/channel/ms.
  - The guarded `171247` rerun again decoded `bank0` as `0x00000105`; it set
    `hist_evidence.valid_for_comparison = false` and carried the concrete
    invalid reasons into `rate_comparison.evidence_invalid_reasons`.
- Root cause:
  - `histogram_ingress_bridge.vhd` only changes the live source when
    `switch_safe = 1`.
  - `switch_safe` requires both packet-active flags low and both pre/post valid
    inputs low. A stale or unterminated pre packet can therefore keep the
    bridge in `switch_pending = 1` and leave the histogram live on the old
    source.
- Fix status:
  - state:
    - open; board harness now decodes the selector status and marks histogram
      comparisons invalid unless the requested source is actually live and the
      pre-run packet state is idle
  - mechanism:
    - no RTL repair yet
    - next RTL candidate is a controlled packet-state clear or a source-select
      reset path that is safe to assert before `RUN_PREPARE`, plus a status
      proof that `STATUS[2:0]` reaches `0x0` for pre or `0x3` for post before
      a RUNNING bin sample is compared
  - before_fix_outcome:
    - the harness reported active-channel counts directly even when the source
      bridge status showed requested source and live source did not match
  - after_fix_outcome:
    - harness guard validated on `RN.BASIC.001_swb_dma_packer_20260514_171247`;
      rate comparison was kept failed because the requested histogram source
      was not actually selected
    - RTL fix and board rerun with `STATUS[2:0] = 0x0` for pre or `0x3` for
      post are still pending
  - potential_hazard:
    - medium for histogram evidence; the datapath can still have live hits, but
      rate/delay comparisons are untrustworthy until selector status is stable
  - Claude Opus 4.7 xhigh review decision:
    - pending / not run in this turn
- Commit:
  - pending

### BUG-005-H: SWB OPQ SignalTap used optimized wrapper aliases
- First seen in:
  - RN.BASIC.001 SWB OPQ ingress/egress STP preparation on 2026-05-14.
- Symptom:
  - Node Finder found only 206 of 503 requested probes in
    `rn001_opq_ingress_egress.stp`.
  - The missing set was concentrated at `swb_block:e_swb_block|opq_egress_*`
    and `swb_block:e_swb_block|opq_dma_*`.
  - After the first retargeted import, Quartus map still reported
    `Critical Warning (35025)`: `rn001_opq_ingress_egress` was connected to
    only 1103 of 1113 required inputs. The exact missing sources were the
    aggregate wrapper counter/status nodes `opq_dma_status`,
    `opq_dma_input_words`, `opq_dma_output_words`, `opq_dma_event_count`, and
    `opq_dma_halt_count`, duplicated once in trigger inputs and once in data
    inputs.
- Root cause:
  - `opq_egress_*` are generated by
    `ingress_egress_adaptor:e_ingress_egress_adaptor`; the wrapper-local VHDL
    aliases are not stable bit-level STP leaves after synthesis elaboration.
  - `opq_dma_data`, `opq_dma_wren`, and `opq_dma_endofevent` are wrapper-local
    aliases around `swb_opq_dma_pipeline:e_opq_dma_pipeline` outputs and the
    top-level DMA port. Quartus exposed some aliases only as aggregate nodes,
    not as the bit-expanded leaves requested by the generator.
  - The remaining five `opq_dma_*` status/counter probes were scalar STP
    requests against 32-bit VHDL vectors. Pre-synthesis lookup accepted the
    aggregate names, but the imported SignalTap map resolved them to GND/missing
    instead of stable bit-level tap leaves.
- Fix status:
  - state:
    - fixed-debug-loadable for STP probe naming, imported-QSF map connectivity,
      and SWB SOF generation; board capture is still pending
  - mechanism:
    - retargeted raw OPQ egress probes to
      `swb_block:e_swb_block|ingress_egress_adaptor:e_ingress_egress_adaptor|`
    - retargeted the OPQ-to-DMA pipeline and 256-bit DMA write payload probes
      to `swb_block:e_swb_block|swb_opq_dma_pipeline:e_opq_dma_pipeline|`
    - kept the registered `opq_dma_input_*` wrapper boundary as the one-cycle
      handoff check between adaptor egress and the packer input
    - removed the five aggregate wrapper counter/status probes from SignalTap;
      their underlying status bits are already covered by scalar control probes
      or CSR readout, while the debug image must prioritize packet-bearing OPQ
      and DMA boundary evidence
  - before_fix_outcome:
    - `probes total=503 found=206 missing=297 errors=0`
    - retargeted pre-synthesis Node Finder passed with
      `probes total=540 found=540 missing=0 errors=0`, but the first imported
      map was still partial:
      `rn001_opq_ingress_egress` connected to 1103 of 1113 required inputs
  - after_fix_outcome:
    - regenerated STP has 535 logical probes, imported into `top.qsf` as 535
      `acq_trigger_in[]` and 535 `acq_data_in[]` connections
    - `output_files/top.map.rpt` reports
      `Info (35024): Successfully connected in-system debug instance
      "rn001_opq_ingress_egress" to all 1103 required data inputs, trigger
      inputs, acquisition clocks, and dynamic pins`
    - full compile completed successfully with 0 errors and 369 warnings;
      `output_files/top.sof` SHA256 is
      `a9328549290d492cfc0bd2c5dbabee88ffdaba45d1ed3753daf87848f5822c36`
  - potential_hazard:
    - low for STP naming; medium for production timing because STA still has
      slow-corner setup residuals (-0.121 ns at 100 C, -0.109 ns at 0 C);
      hardware conclusions remain provisional until the rebuilt image captures
      nonzero OPQ/RDMA traffic on board
  - Claude Opus 4.7 xhigh review decision:
    - pending / not run in this turn
- Runtime / coverage context:
  - failing Node Finder report:
    `syn/board_projects/swb_a10/rn001_opq_ingress_egress_nodecheck_20260514.md`
  - passing Node Finder report:
    `syn/board_projects/swb_a10/rn001_opq_ingress_egress_nodecheck_20260514_retargeted.md`
  - imported map gate:
    `syn/board_projects/swb_a10/output_files/top.map.rpt`
  - full compile log:
    `syn/board_projects/swb_a10/codex_swb_opq_stp_imported_fix_compile_20260514_160813.log`
  - generated debug SOF:
    `syn/board_projects/swb_a10/output_files/top.sof`
  - SOF SHA256:
    `a9328549290d492cfc0bd2c5dbabee88ffdaba45d1ed3753daf87848f5822c36`
  - programmed/recovered board image:
    - `quartus_pgm -c "DE5 [3-6.2]"` succeeded with checksum `0x31A81F8C`
    - PCIe recovered to `/dev/mudaq0`; SWB `VERSION_REGISTER_R` read
      `0x2B87D22A`
  - runtime STP capture:
    `tb_int/REPORT/STP_OPQ_RN001_PRE_RATE_20260514_164001/opq_capture.csv`
  - runtime STP result:
    - OPQ egress valid for `22` words, registered `opq_dma_input_*` one cycle
      later, and three 256-bit DMA writes at samples `523`, `531`, and `537`
    - decoded words form a clean short startup frame:
      `K28.5` header, count word `0x00100000`, sixteen `K23.7` subheaders
      `0x70..0x7F`, and clean `K28.4` trailer `0x0000009C`
    - this proves live OPQ-to-DMA-pack boundary wiring on board, but does not
      prove the full RN.BASIC 128-subheader packet reaches OPQ egress/RDMA
  - generator:
    `script/generate_rn001_opq_stp.py`
  - regenerated STP:
    `syn/board_projects/swb_a10/rn001_opq_ingress_egress.stp`
- Commit:
  - `d0b58930` / `bc192229`

## 2026-05-13

### BUG-004-R: SWB firmware left dirty K28.4 trailer metadata and no Idle-SOP guard
- First seen in:
  - `RN.BASIC.001` RDMA popup review of
    `firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/doc/PHASE4_5_SWEEP_REPORT_5TAB.html`
  - 2026-05-13 K-symbol audit after the popup showed apparent Idle frames and
    trailer-like words with nonzero upper bytes
- Symptom:
  - the original report decoder scanned 32-bit words by low byte only, so
    payload data with byte `0xBC` or `0x9C` could be mislabeled as Idle or
    trailer structure when the dump did not carry `datak`
  - the actual SWB firmware boundary also allowed a true K28.4 trailer word to
    retain metadata in bits above `data[7:0]`
  - no simulation assertion failed the run if OPQ egress transmitted an Idle
    frame SOP or a dirty true K28.4 trailer toward the DMA packer
- Root cause:
  - `time_merger_tree.vhd` built `trailerHit(i).data` from upstream header and
    overflow fields plus trailing byte `0x9C`, so a K-marked trailer could carry
    nonzero `data[31:8]`
  - the OPQ egress / DMA packer observation path did not preserve `datak` in the
    cosim dump, forcing report-side pure-hex marker detection
  - the maintained SWB DMA packer path did not yet canonicalize true trailers or
    assert against Idle SOPs and dirty trailers during simulation
  - the FEB/SWB corun UVM package used a stale K28.4 byte constant (`8'hdc`)
    instead of `8'h9c`, weakening the marker audit
- Fix status:
  - state:
    - partial; RTL, corun, cosim, and report-side decoding are fixed and
      simulation-verified
    - a full SWB Quartus rebuild, reflash, and board rxbuffer capture with this
      exact guard/canonicalization patch are still pending
  - mechanism:
    - changed `time_merger_tree.vhd` to emit a clean K28.4 trailer data word:
      `x"000000000000009C"`
    - changed `ingress_egress_adaptor.vhd` to export OPQ egress data plus
      `datak`, canonicalize true K28.4 trailer data to `x"0000009C"`, and add
      translate-off assertions for Idle SOP and dirty K28.4 trailer transmission
    - added the SWB firmware `swb_opq_dma_pipeline.sv` boundary that detects
      markers from `datak`, canonicalizes true trailers before DMA packing, and
      fatals in simulation on Idle SOP or dirty trailer words
    - carried `datak` through the FEB/SWB corun packer trace and cosim report
      path, then made the RDMA decoder structural instead of a low-byte hex scan
    - fixed the UVM K28.4 constant to `8'h9c`
  - before_fix_outcome:
    - the report popup could decode payload byte collisions as Idle frames
      because the dump lacked K-symbol provenance
    - the SWB merger RTL could form a true trailer marker whose upper data bits
      were nonzero
  - after_fix_outcome:
    - `RN.BASIC.001` datak-aware decode reports `66` frames, `0` idle SOPs,
      `0` dirty true trailers, and `25,600` labeled hits
    - `/tmp/feb_swb_corun_kcheck_20260513` completed with
      `FEB_SWB_CORUN_TRACE_PASS`; trace summary showed `datak` present, `66`
      frames, `0` bad frames, `0` dirty true trailers, and DISLIN `PASS`
    - `make -C firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/tb_int/feb_swb_corun compile_swb_corun`
      completed with `0` errors and `0` warnings
    - standalone `vlog` of the shared packer plus
      `swb_opq_dma_pipeline.sv` completed with `0` errors and `0` warnings
    - `make -C firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/tb_int/feb_swb_corun/uvm compile`
      completed with `0` errors and `0` warnings
  - potential_hazard:
    - medium until the new firmware image is rebuilt and checked on the board;
      current closure proves the marker contract in simulation and regenerated
      report evidence, not yet in a freshly programmed SWB SOF
    - PCIe packet out-of-order write behavior is not modeled in this fix; the
      current rxbuffer frame latch strategy assumes the host-visible buffer is
      continuous after scatter-gather ordering
  - Claude Opus 4.7 xhigh review decision:
    - pending / not run in this turn
- Runtime / coverage context:
  - corun evidence:
    `/tmp/feb_swb_corun_kcheck_20260513`
  - regenerated HTML report:
    `firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/doc/PHASE4_5_SWEEP_REPORT_5TAB.html`
  - generated per-frame DISLIN histograms:
    `firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/doc/rdma_channel_hist/RN.BASIC.001/`
- Commit:
  - pending

### BUG-003-H: Legacy SWB DMA path stripped Mu3e wire-frame structure
- First seen in:
  - `#109` SWB rdma rxbuffer debug showing host-format 64-bit hit records
  - `RN.BASIC.050` cosim rxbuffer evidence before the packer switch
- Symptom:
  - `/dev/mudaq0` and cosim `rdma_rxbuffer.bin` carried flattened hit records
    instead of full Mu3e wire-frame words
  - the legacy path dropped the K28.5 preamble, timestamp/debug header words,
    subheader role boundaries, and K28.4 trailer before data reached the DMA
    host payload slots
- Root cause:
  - `musip_mux_4_1` unpacked OPQ egress frames and asserted
    `next_64bit_word_valid` only for hit payloads
  - `musip_event_builder` then serialized those hit payloads as host-format
    records, so CSR tuning could not recover the missing frame structure
- Fix status:
  - state:
    - partial; SWB RTL, Quartus compile, static screen, RN.BASIC.050 cosim,
      SWB flash, PCIe recovery, and RN.BASIC.001 board-attempt evidence are
      complete
    - board wire-format verification is blocked by missing upstream OPQ input
      on the live FEB/SWB chain, not by a decoded host-format DMA stream
  - mechanism:
    - marked the legacy `musip_mux_4_1`, `musip_event_builder`, and interim
      `swb_rdma_subsystem_bridge` path as `LEGACY_DMA_DEAD`
    - routed raw OPQ egress words through `swb_opq_dma_pipeline` and the
      maintained `swb_opq_dma_packer`
    - packed the original 32-bit Mu3e wire-frame words into 256-bit DMA
      payloads without stripping preamble, subheaders, hits, or trailer
  - before_fix_outcome:
    - initial RN.BASIC.050 rxbuffer began with `0x80` hit-record data
    - wire-frame decoder reported `frames_decoded = 0`
  - after_fix_outcome:
    - focused packer static screen: lint error `0`, CDC violations `0`, RDC
      violations `0`
    - Quartus full compile of SWB `top` completed with `0` errors and timing
      positive at all four integration corners
    - RN.BASIC.050 cosim rxbuffer first bytes:
      `bc 00 00 e0 00 00 00 00 00 00 00 00 80 00 04 00`
    - RN.BASIC.050 decoded `62` wire-format frames; frame `0`
      `packet_timestamp = 0`; inter-frame timestamp delta histogram
      `{0x800: 61}`; K28.4 trailer count `62`
    - SWB flash via `DE5 [3-6.2]` succeeded with `0` programmer errors and
      `0` programmer warnings; `mudaq_recover_pcie` exited `0`
    - RN.BASIC.001 board sanity passed:
      `scratch_pad_ram = 0x5AA55A5A`, `sc_hub_uid = 0x53434842`, and
      runctl `RX_CMD_COUNT` advanced by `4`
    - RN.BASIC.001 board DMA did not prove wire-format because the live run
      generated no packer input: `rdma_rxbuffer.bin` was `0` bytes,
      `frames_decoded = 0`, packer/DMA counters stayed `0`, and histogram
      `TOTAL_HITS = 0`
  - potential_hazard:
    - high for board-level closure until the upstream live traffic source is
      restored; the programmed SWB image cannot prove wire-frame DMA capture
      without OPQ egress words entering the packer
  - Claude Opus 4.7 xhigh review decision:
    - pending / not run in this turn
- Runtime / coverage context:
  - compile log:
    `firmware_builds/systems/swb/rdma_pretest-260511/syn/board_projects/swb_a10/codex_swb_opq_compile_20260513.log`
  - SOF SHA256:
    `7b85a2607c48ec677427c348a39f8ed24e71950b8889211bb00cc518f873a7f5`
  - cosim row evidence:
    `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/cosim/REPORT/RN.BASIC.050/rdma_rxbuffer_summary.json`
  - HTML report:
    `firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/doc/PHASE4_5_SWEEP_REPORT_5TAB.html`
  - board evidence:
    `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/REPORT/RN.BASIC.001_swb_dma_packer_20260513_111043/board_summary.json`
  - board flash log:
    `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/REPORT/swb_dma_packer_quartus_pgm_20260513T090601Z.log`
- Commit:
  - pending

## 2026-05-11

### BUG-002-H: Phase 1 link-2 legacy LVDS smoke bypassed the physical-link boundary
- First seen in:
  - Apr 27 FEB SOF plus May 11 SWB SOF empty-frame smoke on `2026-05-11`
  - on-board symptom:
    - `VERSION_REGISTER_R = 0xE774D90D`
    - `LINK_LOCKED_LOW_REGISTER_R = 0x13000000`
    - `LINK_LOCKED_HIGH_REGISTER_R = 0x00000F00`
    - expected SciFi FEB link-2 lock bit was not set
  - Phase 1 baseline sim:
    - `make run_B067 SIM_ROOT=sim_phase1_20260511_legacy_link2 WORK=work_tb_int_phase1_legacy_link2`
- Symptom:
  - `B067` passes with one RQE, one CQE, one OPQ emit, and one DMA event
  - the pass does not prove the requested legacy FEB-to-SWB lock path because
    the selected SWB tb_int filelist does not compile a legacy LVDS stream
    source, firefly lock model, word-align observation, or LINK_LOCKED CSR
    mirror
  - the compiled structural path starts at `rdma_rqe_ingress_if`, `opq_lane_if`,
    and `pcie_dma_egress_if`, so it bypasses the board-failing boundary
- Root cause:
  - the Phase 1 debug target crosses from the Apr 27 FEB legacy LVDS/firefly
    boundary to the May 11 SWB RDMA ingress abstraction without a live
    link-lock/word-align handshake in tb_int
- Fix status:
  - state:
    - open; no RTL or Qsys fix was applied in this iteration
  - mechanism:
    - none yet; the next valid Phase 1 step is to promote tb_int with either a
      live real-DUT bind for the top-level firefly/LVDS path or a focused
      link-2 adapter model that drives legacy 8b10b symbols through the same
      lock and CSR mirror signals used by the SWB SOF
  - before_fix_outcome:
    - B067 structural sim passes while board `LINK_LOCKED_LOW[2]` remains low,
      so the sim cannot reproduce or exonerate the board failure
  - after_fix_outcome:
    - not available; this iteration intentionally stopped before changing RTL,
      Qsys, or Signal Tap setup
  - potential_hazard:
    - high for board-debug conclusions that rely on current tb_int selected
      cases, because a direct RDMA-side pass can mask failures at the optical
      link, XCVR lock, LVDS word-align, or link-lock CSR boundary
  - Claude Opus 4.7 xhigh review decision:
    - pending / not run in this turn
- Runtime / coverage context:
  - transcript:
    `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/sim_phase1_20260511_legacy_link2/B067/transcript`
  - B067 result:
    - `B067 PASS title="FEB-side RDMA RQE sidecar lineage" rqe=1 cqe=1 opq=1/1 drop=0 dma=1/1 sidecar_matched=1`
    - `UVM_ERROR : 0`
    - `UVM_FATAL : 0`
  - static audit:
    - `tb_int/script/tb_int.f` includes `rdma_rqe_ingress_if.sv`,
      `opq_lane_if.sv`, and `pcie_dma_egress_if.sv`
    - no compiled tb_int filelist entry binds `lvds_phy_if.sv`,
      `mutrig_phy_agent.sv`, firefly lock, word-align, or `LINK_LOCKED`
  - SWB top-level lane map evidence:
    - current SWB `top.vhd` maps `QSFPC RX(8)` to `feb_rx(2)`
    - legacy `online_sc/online/switching_pc/a10_board/top.vhd` uses the same
      `QSFPC RX(8)` to `feb_rx(2)` mapping
- Commit:
  - pending

### BUG-001-H: SWB tb_int had no local synthesis tree for BASIC smoke
- First seen in:
  - `B065` structural preflight for `swb/rdma_pretest-260511/tb_int`
- Symptom:
  - the mu3e-ip-cores workspace had no SWB-local staged board project under
    `firmware_builds/systems/swb/rdma_pretest-260511/`
  - BASIC smoke could not bind against a durable local Qsys synthesis tree
- Root cause:
  - the SWB project still lived in the read-only `online_sc` source location
    and had not been minted into the mu3e-ip-cores firmware-build layout
- Fix status:
  - state:
    - fixed for the structural B065 preflight
  - mechanism:
    - staged the SWB board project locally
    - copied the SWB-owned OPQ Platform Designer Tcl/Qsys files into
      `quartus_systems/swb/`
    - added the SWB `tb_int` plan, bucket files, and first BASIC smoke
      harness
  - before_fix_outcome:
    - no local SWB `syn/board_projects/swb_a10` tree existed
  - after_fix_outcome:
    - qsys-generate preflight exits `0`; see
      `firmware_builds/systems/swb/rdma_pretest-260511/syn/swb_qsys_generate_20260511_1232.status`
    - BASIC B065 structural smoke passes `1/0/0` at each observed stage; see
      `firmware_builds/systems/swb/rdma_pretest-260511/tb_int/sim/logs/swb_basic_b065_smoke.log`
  - potential_hazard:
    - low for structural preflight; full live UVM closure still depends on
      later bind-point refinement against generated hierarchy names
  - Claude Opus 4.7 xhigh review decision:
    - pending / not run in this turn
- Runtime / coverage context:
  - first case implemented is `B065`
  - remaining bucket cases are planned and pending implementation
- Commit:
  - pending
