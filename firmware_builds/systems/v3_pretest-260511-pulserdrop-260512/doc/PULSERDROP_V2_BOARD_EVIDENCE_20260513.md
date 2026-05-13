# Pulserdrop v2 board evidence - 2026-05-13

## Scope

Regenerated `feb_system_v3.qsys` in the pulserdrop build directory from the
canonical v3 Qsys, compiled FEB v3, flashed the resulting SOF, re-ran the BU
delta bucket, and collected RN.BASIC.001 evidence.

## Qsys and compile

- Qsys regen: exit 0, status file
  `syn/feb_system_v3_qsys_generate_20260513_064021_pulserdrop_v2_isolated.status`.
- Generated component catalog:
  - `histogram_statistics_v2`: 26.2.0.511.
  - `mts_preprocessor`: 26.3.0.512.
  - `arb_hit_type0_supercore`: absent from the canonical pulserdrop Qsys map.
- Quartus compile: exit 0, status file
  `syn/board_projects/fe_scifi_feb_v3/quartus_compile_20260513_064145_pulserdrop_v2.status`.
- SOF SHA256: `fbf1155a9f73aad1cc58acb13290dc06737311ff922e5a4dd6896293263dcc55`.

## Board results

- Flash: `tools/run_script/program_feb.sh` completed and enforced the 20 s
  settle window.
- PCIe recovery: `sudo -n /usr/local/sbin/mudaq_recover_pcie` completed.
- Sanity probes:
  - scratch pad `0x00000`: `0x00000000`.
  - SC hub UID `0x0FE80`: `0x53434842`.
  - runctl `CSR_RX_CMD_COUNT` `0x0C00F`: `0x00000032`.

## BU v2

BU v2 remains 20/25 PASS. The same five rows from the prior run remain FAIL:
`BU012`, `BU013`, `BU014`, `BU020`, and `BU025`.

The regenerated catalog is current, but live CSR behavior still does not match
the expected source metadata:

- `BU012`: live histogram read stays `0x48495354 0x1A000000`.
- `BU013`: live MTS reads stay `0x20000010 0x00000000` at both apertures.
- `BU014`: live arb aperture remains zero because the canonical pulserdrop Qsys
  has no `arb_hit_type0_supercore` instance at `0x088A0`.

The aggregate v2 file is `board_evidence/BU/_summary_v2.json`.

## RN.BASIC.001

RN.BASIC.001 was run despite the residual BU failures per explicit override.
The requested run-control opcode sequence was `0x10`, `0x11`, `0x12`, sleep
about 1 ms, then `0x13`; opcodes `0x30` and `0x31` were not used.

Result:

- Theory: 125000 hits.
- Histogram `TOTAL_HITS`: 0.
- RDMA bytes: 0.
- Verdict: FAIL.

The RN evidence is under `board_evidence/RN.BASIC.001/`.
