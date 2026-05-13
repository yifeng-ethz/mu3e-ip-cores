# Pulserdrop BU/RN001 Diagnosis

Date: 2026-05-13
Scope: source inspection plus saved cosim/board evidence only. No bench access, no
Qsys/RTL/TEST_BU patch, and no cosim rerun were used.

## Phase A arb_hit_type0_supercore canonical Qsys finding

The requested root scan:

```text
grep -n "arb_hit_type0\|arb_hit_type" quartus_systems/*.qsys
```

finds only description text in the canonical root Qsys files:

- `quartus_systems/scifi_datapath_system_v3_lat4.qsys:7`
- `quartus_systems/scifi_datapath_system_v3_pipe.qsys:7`

There is no `arb_hit_type0_supercore` module instance in canonical
`quartus_systems/*.qsys`.

The generated pulserdrop top map also has no arb route:

- `firmware_builds/systems/v3_pretest-260511-pulserdrop-260512/syn/feb_system_v3.qsys`
  `AUTO_AVMM_PORT_ADDRESS_MAP` lists emulator CSRs at data-path local
  `0x2000..0x2200`, then `dbg_mm2runctrl_0.csr` at `0x2200..0x2240`,
  then skips to backpressure FIFO `0x2860`; it contains no
  `data_path_subsystem_arb_hit_type0_supercore_0_lane_*` entry.
- The same absence is present in the checked cosim top map at
  `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/syn/feb_system_v3.qsys`.

The IP is present only in the dual-port cosim subsystem Qsys, not in the current
canonical root:

- `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/quartus_systems/scifi_datapath_system_v3_pipe.qsys`
  instantiates `arb_hit_type0_supercore_0`.
- Its lane CSR ports sit behind `mm_pipeline_lvds_csr_emu_dbg.m0` at subsystem
  offsets `0x0280, 0x0300, 0x0380, 0x0400, 0x0480, 0x0500, 0x0580, 0x0600`.
- With the existing data-path debug aperture, those become data-path local
  offsets `0x2280..0x2600`; TEST_BU's board-tool address convention expects
  lane 0 at `0x22280 / 0x088A0`.
- Parent chain for the routable design should be:
  slow-control/sc_hub -> root `data_path_subsystem.avmm_port` ->
  subsystem `mm_pipeline_lvds_csr_emu_dbg.m0` ->
  `arb_hit_type0_supercore_0.csr_[0..7]`.

Git history identifies the drop from the generated top map:

- `47efa242 [NEW] HW: add dual-port histogram ingress build` added the
  dual-port build with arb lane CSR map rows.
- `b8107d97 [PATCH] HW: v3_pretest-260511 refresh cosim qsys dut` removed the
  `data_path_subsystem_arb_hit_type0_supercore_0_lane_0..7.csr` rows from
  `syn/feb_system_v3.qsys`, while the derived subsystem still had the arb
  instance.

Verdict: `topology`. The current canonical pulserdrop image is missing the arb
route expected by TEST_BU, and the current root Qsys sources do not instantiate
the supercore.

## Phase B per-IP BU012 / BU013 / BU014 verdict with cosim cross-check

Saved cosim `REPORT/` data does not contain BU012/BU013/BU014 identity CSR
readback snapshots. I did not launch a new sim. The cross-check below therefore
uses saved cosim functional counters where available, plus source/Qsys/board
readback evidence.

| BU | IP | Expected from current source | Live board readback | Saved cosim readback/counter evidence | Verdict | Reason |
|---|---|---:|---:|---|---|---|
| BU012 | `histogram_statistics_v2` | Source defaults UID `0x48495354`, VERSION `0x1A0201FF` from 26.2.0.0511. Canonical `scifi_datapath_system_v3.qsys` overrides the instance to `BUILD=0`, `VERSION_MINOR=0`, `VERSION_PATCH=0`, so the instantiated Qsys value is `0x1A000000`. | `0x48495354`, `0x1A000000` at `0x0A900` | No saved identity CSR readback. RN.BASIC.001 cosim hist counters are live: `TOTAL_HITS=31264`, `LAST_INTERVAL_TOTAL_HITS=31264`. | `plan` | Silicon matches the generated Qsys instance override, not the raw source default. TEST_BU is comparing against source/catalog metadata without accounting for the Qsys instance parameter override. |
| BU013 | `mts_preprocessor_0/1` | Package metadata gives UID const `0x4D546350` and VERSION `0x1A030200` for 26.3.0.0512, but current `mts_processor.vhd` does not expose UID/META CSRs. CSR word 0 is control/status; word 1 is discard-hit count. | Both apertures return `0x20000010`, `0x00000000`, `0x000007D0`, `0x00000000`, `0x00000000`. | No saved identity CSR readback. The source RTL map predicts control/status and counters at those words, not UID/META. | `plan` | TEST_BU expects identity metadata from an IP CSR map that currently has no identity surface. This is not evidence of stale silicon. |
| BU014 | `arb_hit_type0_supercore_0` | Per-lane `arb_hit_type0` source UID `0x41485430`, VERSION `0x1A060200` for 26.6.0.0512. The supercore exports one CSR aperture per lane; it does not expose one aggregate identity CSR. | `0x00000000 0x00000000 0x00000000 0x00000000` at `0x088A0`. | No saved identity CSR readback. RN.BASIC.001 cosim proves an arb datapath exists in the cosim harness: selected counts are lane0 `3936`, lanes1-7 `3904` each, drops `0`. | `topology` | The pulserdrop top map has no routable arb CSR at the TEST_BU address, while cosim functional evidence comes from a harness/topology that includes the arb path. |

Derived gates:

- `BU020` is a derived metadata sweep gate and should remain auto-FAIL while
  BU012/BU013/BU014 are unresolved.
- `BU025` is a derived readiness gate and should remain auto-FAIL while the
  arb topology gap can make RN.BASIC empty.

## Phase C RN.BASIC.001 checkpoint count cascade

Saved cosim checkpoint row counts:

| Checkpoint | Saved file | Hit count |
|---|---|---:|
| Emulator emit | `feb_swb_emulator_emit_trace.csv` | 31264 |
| Pre-rbCAM | `feb_swb_pre_rbcam_trace.csv` | 31264 |
| Post-rbCAM | `feb_swb_post_rbcam_trace.csv` | 31264 |
| FEB egress | `feb_swb_feb_egress_trace.csv` | 31264 |
| SWB ingress | `feb_swb_ingress_trace.csv` | 31264 |
| OPQ egress | `feb_swb_opq_trace.csv` | 31264 |
| DMA trace | `feb_swb_dma_trace.csv` | missing from saved RN.BASIC.001 report |
| RDMA rxbuffer summary | `rdma_rxbuffer_summary.json` | 31264 records |

Saved cosim `rate_csr_dump.json` also reports:

- `theoretical_hits = 31250`
- `clipped_hits = 31250`
- `csr_total = 31264`
- checkpoints `source_generation_hits` through `rdma_hits` all `31264`
- `histogram_statistics_v2.total_hits_csr13 = 31264`
- `arb_hit_type0_supercore.selected_count = {lane0: 3936, lane1..7: 3904}`
- `arb_hit_type0_supercore.dropped_hits = 0`

There is no cosim checkpoint where RN.BASIC.001 drops to zero or sharply drops.
The saved cosim data path is conserved through RDMA.

Board RN.BASIC.001 evidence is different:

- Theory: `125000` hits.
- Run-control completed enough to advance `RX_CMD_COUNT` to `0x32`.
- Emulator CSRs at `0x08800..0x08870` are reachable and identify as
  `0x454D5554`, VERSION `0x1A0301FA`.
- Arb read at `0x088A0` returns four zero words.
- Histogram at `0x0A900` reads UID `0x48495354`, VERSION `0x1A000000`, but
  `TOTAL_HITS = 0`, `LAST_INTERVAL_TOTAL_HITS = 0`, `DROPPED_HITS = 0`.
- MTS reads remain the functional CSR words
  `0x20000010, 0x00000000, 0x000007D0, 0x00000000, 0x00000000`.
- RDMA evidence reports zero payload records/bytes in the board evidence note.

The first board-visible failure is upstream of histogram and RDMA, not in the
SWB DMA endpoint. That aligns with the BU014 topology gap: the board image can
reach emulator CSRs and run-control, but the expected arb CSR/selection path is
not routable in the pulserdrop canonical map. The saved cosim harness does not
reproduce this dropout because its functional path contains the arb and
conserves all hits.

## Recommended fixes per issue

| Issue | Bucket | Proposed fix, not applied here | Next dispatch |
|---|---|---|---|
| BU012 | `plan` | Either update TEST_BU to compare the live generated Qsys instance value `0x1A000000`, or remove the stale histogram version overrides from the Qsys Tcl generator so the instantiated IP reports the source default `0x1A0201FF`. | Plan owner plus Qsys owner, depending on which metadata contract is intended. |
| BU013 | `plan` | Update TEST_BU to stop expecting UID/META from `mts_preprocessor` until the RTL has an explicit identity CSR, or add such a CSR in a separate RTL-approved change. | Plan owner for immediate BU unblock; RTL owner only if identity CSR is required. |
| BU014 | `topology` | Add/restore `arb_hit_type0_supercore_0` in the canonical Qsys via Tcl only, route `csr_0..csr_7` through the data-path debug bridge/SC hub, regenerate, and verify the top `AUTO_AVMM_PORT_ADDRESS_MAP` includes lane CSR rows. | System-integration owner. |
| RN.BASIC.001 board zero-hit capture | `topology` | Do not debug SWB DMA first. Restore/routably configure the arb path, then rerun BU014 and the RN.BASIC.001 board capture. If histogram becomes nonzero while rxbuffer stays zero, then hand off to the #111 SWB DMA packer work. | System-integration owner first; #111 only after hist/FEB/SWB pre-DMA counters are nonzero. |
| BU020 / BU025 | derived | Re-evaluate after BU012/BU013 plan fixes and BU014 topology fix. | BU runner after fixes. |

