# CHANGELOG.md - 260518-feb-ok system

Forward-incompatible changes (Qsys IP version bumps, system layout drops,
search-path tightening) that affect what `make qsys` produces and what the
Quartus compile binds against. Newest entry on top.

---

## 2026-05-18 - Drop `_pipe` variant + IP forward auto-upgrade + tighten search path

### Minimal `.qsys` set we MUST keep generated for FEB v3

`feb_system_v3.qsys` instantiates only **three** subsystem `.qsys` files
(verified by direct grep of `kind="..."`); everything else under
`generated/qsys/` is dead weight for this build:

```
feb_system_v3.qsys             -- top, lives at <system>/syn/feb_system_v3.qsys
|-- feb_bringup_system          (1.0)        -- subsystem, no separate .qsys
|-- debug_sc_system_v3          (3.1.0.512)  -- subsystem, no separate .qsys
|-- upload_system_v3            (3.0.0.511)  -- subsystem, no separate .qsys
`-- scifi_datapath_system_v3.qsys   (3.0.6.0517)   -- generated/qsys/
    |-- arb_hit_type0_supercore.qsys (1.0)          -- generated/qsys/
    |   `-- arb_hit_type0 (26.6.5.518)
    |-- avst_snoop_splitter        (26.0.0.502)
    |-- dbg_mm2runctrl             (1.0.0)
    |-- emulator_mutrig            (26.3.3.517)
    |-- histogram_statistics_v2    (26.3.4.517)
    |-- hit_stack_system           (1.0)
    |-- hit_type0_fanout8          (26.0.1.517)     [misc/ refreshed today]
    |-- hit_type0_readyless_mux4   (26.1.0.516)     [auto-upgraded today]
    |-- hit_type0_tap2             (26.0.0.517)
    |-- lvds_rx_controller_pro     (25.1.631)
    |-- mts_preprocessor           (26.3.3.517)
    |-- mutrig_datapath_system_v3  (1.0)
    |-- mutrig_injector_multiheader (26.1.2.0517)   [auto-upgraded today]
    |-- mutrig_reset_controller    (1.1.0)
    `-- pulse_fanout8              (1.2)
```

**Authoritative `.qsys` files for the build:**

| Path | Top-level instances | Purpose |
|---|---|---|
| `<system>/syn/feb_system_v3.qsys` | feb_bringup, debug_sc, scifi_datapath, upload | board top |
| `<system>/generated/qsys/scifi_datapath_system_v3.qsys` | 15 IPs above | datapath subsystem |
| `<system>/generated/qsys/arb_hit_type0_supercore.qsys` | 8x arb_hit_type0 + splitter + mm_bridge | per-lane arbiter wrapper |

That is the **minimal set**. The system carries no other top-level Qsys.

### Dropped: `scifi_datapath_system_v3_pipe.qsys`

The `_pipe` variant differed from the non-pipe by exactly **one** GUI
`_sortIndex` value (`74` vs `76`). It was never instantiated by
`feb_system_v3.qsys` (only mentioned in description text). Removed to
`<system>/trash_bin/`:

- `generated/qsys/scifi_datapath_system_v3_pipe.qsys` -> `trash_bin/`
- `generated/qsys/scifi_datapath_system_v3_pipe.sopcinfo` -> `trash_bin/`
- `generated/synthesis/scifi_datapath_system_v3_pipe/` -> `trash_bin/`

Stripped all `_pipe` references from `qsys_tcl/script/` (7 files,
11 references total): `apply_v3_emulator_type0_qsys.sh`,
`apply_reset_sync_v3.sh`, `apply_v3_histogram_stats_contract.sh`,
`apply_dualport_histogram_topology.sh`,
`update_emulator_type0_descriptions.tcl`,
`regenerate_local_qsys_clean.sh`,
`update_feb_system_v3_dualport_version.tcl`.

### WARNING - IP versions auto-upgraded in `scifi_datapath_system_v3.qsys`

The IP-version audit on 2026-05-18 showed two IPs whose canonical `_hw.tcl`
had been bumped past what the `.qsys` requested. Both were forward
auto-upgraded **in place** in `generated/qsys/scifi_datapath_system_v3.qsys`
so future `qsys-script` / `qsys-generate` runs bind the exact canonical
version (no Qsys version-relaxation magic). These are non-breaking patch
bumps; binding the older requested version would either fail to resolve or
silently relax up at runtime.

| IP | requested before bump | bumped to (= canonical) | occurrences | canonical source |
|---|---|---|---|---|
| `hit_type0_readyless_mux4` | `26.0.0.512` | **`26.1.0.516`** | 2 | `misc/hit_type0_readyless_mux4/hit_type0_readyless_mux4_hw.tcl` |
| `mutrig_injector_multiheader` | `26.1.1.517` | **`26.1.2.0517`** | 1 | `charge_injection/script/mutrig_injector_multiheader_hw.tcl` |

If a future RTL change rewinds either of these IPs to its earlier minor /
build number, restore the original `.qsys` text from
`<system>/trash_bin/top.qip.original` and the prior `scifi_datapath_system_v3.qsys`
copy under `<system>/trash_bin/cosim/...` (not deleted by today's pass).

### Refreshed `misc/hit_type0_fanout8/`

The `misc/` copy I promoted on 2026-05-18 from the 260518-feb-ok per-system
`ip/` dir turned out to be the **older** `26.0.0.0512` build, while the
generated `.qsys` requested `26.0.1.0517`. The newer `26.0.1.0517` copy
lived only at
`firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/ip/hit_type0_fanout8/`.
The old `misc/hit_type0_fanout8/` is preserved at
`<system>/trash_bin/hit_type0_fanout8_misc_old/` and the newer version is
now the canonical `misc/hit_type0_fanout8/`.

### Tightened `qsys_search_path.sh`

Per `feedback_qsys_apr27_pollution` memory, the helper now excludes
**every** `firmware_builds/systems/` subtree from the IP `_hw.tcl` search
path (with one exception: the active system's own `qsys_tcl/` is kept for
patcher / composite Tcl files, which are not IP definitions). All
`*/trash_bin/*` paths are also excluded.

Effect: `qsys-script` and `qsys-generate` now find each IP only under
`misc/<ip>/` or the submodule root (`mu3e-ip-cores/<ip>/...`), so per-system
`ip/<ip>/` duplicates can no longer shadow the canonical version. This is
the fix for the 26 `kind="missing_module"` entries the
`scifi_datapath_system_v3.sopcinfo` carried in the previous build.

### Makefile: sopcinfo write-bit re-enable before qsys-generate

`make qsys-syn` and `make qsys-gen` now `chmod u+w generated/qsys/*.sopcinfo`
before running `qsys-generate`. The previous run failed with
`Error writing sopcinfo report ... Permission denied` because the
`qsys-from-tcl` step had `chmod a-w`-locked the .sopcinfo files and
`qsys-generate` rewrites them in place during synthesis.

### KNOWN-RESIDUAL: `mts_preprocessor.hit_type1_ts` interface needs IP merge

After every fix above, `make qsys-syn` now resolves all 26 IPs cleanly
(both `arb_hit_type0_supercore.sopcinfo` and
`scifi_datapath_system_v3.sopcinfo` carry **0** `kind="missing_module"`
entries), and produces the full HDL trees: `arb_hit_type0_supercore/`
63 files, `scifi_datapath_system_v3/` 226 files. The remaining hard
qsys-generate error is:

```
Error: scifi_datapath_system_v3.mts_preprocessor_0.hit_type1_ts /
  histogram_statistics_0.type1_up_ts: Missing connection start
Error: scifi_datapath_system_v3.mts_preprocessor_1.hit_type1_ts /
  histogram_statistics_0.type1_down_ts: Missing connection start
Error: mts_preprocessor_1.hit_type1_ts has no associated clock / reset
```

Root cause traced (2026-05-18 12:22): the `mts_preprocessor` IP
(`mutrig_timestamp_processor/mts_processor_hw.tcl`) on `master`
**does not declare `hit_type1_ts`**. That interface lives only on commit
`eb67302 [PATCH] MTS: split Type1 timestamp sideband`, which sits on
branch `backup/codex/stream-debug-plane-feb-v3-20260515` and was never
merged to `master`. Master instead has the parallel `hit_type1_extended_0`
/ `hit_type1_extended_1` AvalonST sources from `1e4e619` plus the later
`hit_type1_sidecar` debug conduit. The `.qsys` (generated against
eb67302-era IP) wires the now-missing `hit_type1_ts` interface.

Action items (NOT resolved in this commit; require careful manual merge):
1. Manually merge `eb67302`'s `add_interface hit_type1_ts conduit ...`
   block into master's `mts_processor_hw.tcl` so the IP exposes BOTH
   approaches (the AvalonST extended ports from master AND the conduit
   timestamp from eb67302). The two paths are not mutually exclusive in
   the RTL.
2. Add the matching `coe_hit_type1_ts` Output 48 port to
   `mutrig_timestamp_processor/mts_processor.vhd` (the cherry-pick of
   eb67302 had real conflicts there — manual merge needed).
3. Bump the canonical IP version (26.3.4.0515 -> 26.3.5.05XX) and
   re-bump the `.qsys` to the new version once the IP merge lands.

Until this is fixed, `make qsys-syn` will exit non-zero with `Error: null`,
`generated/synthesis/feb_system_v3/` will not exist, and `make flow` will
not be runnable. The two complete HDL trees that DO get emitted
(`arb_hit_type0_supercore/`, `scifi_datapath_system_v3/`) are partial -
they bind a stub for `mts_preprocessor.hit_type1_ts` and are not safe to
commit to Quartus.

---
