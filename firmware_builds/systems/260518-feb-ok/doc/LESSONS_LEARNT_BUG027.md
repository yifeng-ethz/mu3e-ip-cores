# LESSONS_LEARNT_BUG027.md - why the standalone sim missed the Type1 ready-port omission

Date: 2026-05-19 (post on-board reprobe; commits `2c3ea82`, `20f41e7e`).

## The bug in one paragraph

`histogram_statistics_v2_hw.tcl` declared `type1_up` and `type1_down` as
Avalon-ST sink interfaces with `readyLatency 0` but the foreach loop that
added the per-interface ports listed `valid / data / sop / eop / channel /
empty / error` and **forgot the `ready` port**. The RTL drove
`asi_type1_up_ready` / `asi_type1_down_ready` as entity outputs, but
qsys-generate emits wrappers from the **hw.tcl interface declaration**, not
from the RTL entity, so those ready outputs were stripped on the wrapper
boundary. The auto-inserted Avalon-ST `timing_adapter` (and `error_adapter`
+ `channel_adapter`) between `hist_type1_up_tap.aso_out1` and the hist's
`type1_up` sink then saw `out_0_ready` unconnected, drove it to 0, never
consumed its internal FIFO, filled, and silently dropped every Type1 hit
between MTSP and the histogram.

## Why the standalone UVM TB never saw it

The hist `tb/uvm/tb_top.sv` instantiates the **RTL directly**:

```sv
histogram_statistics_v2 #(
    ...
) dut (
    .asi_type1_up_ready (type1_up_if.ready),
    ...
);
```

So the TB drove `type1_up_if.ready` from its own monitor and saw the RTL's
ready output verbatim. The qsys-wrapper-stripping path that breaks the
in-system datapath **does not exist in the standalone TB compile**, because
the TB does not go through qsys-generate. The standalone TB validates the
RTL behaviour for a hypothetical instantiator that wires every entity port
the RTL exposes. It cannot see that the hw.tcl interface declaration -
which is what Platform Designer actually uses to write the wrapper - is
incomplete.

## Why tb_int also missed it - the real lesson

The auto-memory `feedback_tb_int_uses_generated_rtl.md` already requires
tb_int to **compile the actual synthesis/ tree (Qsys-generated wrappers,
auto-inserted adapters / timing_adapters / clk_bridges)** precisely so
this class of bug shows up before silicon. We have a working
`firmware_builds/systems/260518-feb-ok/tb_int/hist_v3/` with a `Type1`
source-select case (`SOURCE_TYPE1_UP = 2'd1`, `SOURCE_TYPE1_DOWN = 2'd2`)
in `tb_hist_direct_v3.sv`. So tb_int *did* exercise the Type1 ingress.
**And it still missed the bug.** Why?

Because the tb_int compile script `run_hist_v3.sh` only picks the **leaf
RTL sources** from `generated/simulation/.../submodules/`:

```bash
"${QUESTA_BIN}/vcom" ... \
    "${SIM_RTL_DIR}/histogram_statistics_v2_pkg.vhd" \
    "${SIM_RTL_DIR}/true_dual_port_ram_single_clock.vhd" \
    "${SIM_RTL_DIR}/hit_fifo.vhd" \
    "${SIM_RTL_DIR}/rr_arbiter.vhd" \
    "${SIM_RTL_DIR}/bin_divider.vhd" \
    "${SIM_RTL_DIR}/coalescing_queue.vhd" \
    "${SIM_RTL_DIR}/pingpong_sram.vhd" \
    "${SIM_RTL_DIR}/histogram_statistics_v2.vhd"
```

And `tb_hist_direct_v3.sv` instantiates the **bare IP** with all 7
type1_up + 7 type1_down + 8 type0_lane signals wired directly:

```sv
histogram_statistics_v2 #(
    ...
) dut (
    .asi_type1_up_ready (type1_up_ready),
    .asi_type1_up_valid (type1_up_valid),
    .asi_type1_up_data  (type1_up_data),
    ...
);
```

`scifi_datapath_system_v4.vhd` (the qsys-subsystem wrapper that strips the
`asi_type1_up_ready` port) is **NEVER compiled**. Neither are the
auto-inserted timing/channel/error adapters. The tb_int's "I am using
generated RTL" claim is **structurally incomplete**: it walks into the
`generated/simulation/.../submodules/` tree to grab IP leaves, but stops
short of compiling the wrapper that ties those leaves together. That
wrapper, plus the auto-inserted adapters, is exactly what BUG-027-I
exposes - and exactly what this tb_int compile elides.

The hard-stuck signature - hist `TOTAL_HITS = 0` while MTSP
`total_hit_cnt` climbs - would have shown up in the very first 10 ms of
this tb_int run, IF the wrapper had been part of the compile. Instead the
bare-RTL tb_int sees the hist accept every Type1 beat the TB sends
(because the bare RTL drives `asi_type1_up_ready` and the TB latches it),
so the hist `TOTAL_HITS` increments cleanly and the test passes.

The lesson is concrete: **a tb_int that compiles only the leaf IP source
files is no different from a standalone IP TB plus a few neighbour leaves
- it does not exercise the wrapper-level wiring that the qsys-generate
flow actually produces.** A true integration TB must compile
`scifi_datapath_system_v4.vhd` (and / or `feb_system_v4.vhd`) as the DUT
and drive the public Avalon-ST sinks of the subsystem (e.g.
`asi_type1_up_*` on the wrapper boundary, which would have stayed
silent because the wrapper does not export them) rather than driving
the IP entity directly. The check is mechanical: did the vcom file list
include `scifi_datapath_system_v4.vhd`? If not, the harness is not
exercising the integration surface.

## What did expose it

The board read in the 2026-05-19 18:02 regression:

- `mts_preprocessor_0/1.total_hit_cnt` climbed at ~420 k/s/group (hits
  arrive at MTSP, MTSP forwards Type1).
- `histogram_statistics_0.TOTAL_HITS` stayed at 0 (hist saw zero Type1 hits).
- `histogram_statistics_0.BANK_STATUS` ping-ponged 0<->1 (the hist itself
  was alive and the interval timer fired).
- `sc_hub_v2.ERR_FLAGS` = 0 throughout (the SC bridge was not flagging
  anything).

That divergence between "Type1 leaves MTSP" and "Type1 enters hist" with
no error indication is the in-system signature. A standalone TB has
**neither end of that divergence** in scope.

The static-screen path that pinned the diagnosis was much smaller: a
single `grep asi_type1_up_ready
generated/synthesis/scifi_datapath_system_v4/synthesis/scifi_datapath_system_v4.vhd`
returned **zero matches**, proving the wrapper had silently dropped the
port. From there, looking at the same name in the hw.tcl foreach loop
showed the omission.

## What the standalone TB would need to add to catch this

Two complementary improvements:

1. **TB compiles the qsys-generated wrapper, not the RTL directly.**
   The hist already has a tb_int harness at
   `firmware_builds/systems/260518-feb-ok/tb_int/hist_v3/` whose intent
   is exactly this - drive Type1 / Type0 stimulus through the regenerated
   `scifi_datapath_system_v4` subsystem and observe hist behaviour. If
   that tb_int had been exercised with Type1 source-select before the
   bitstream went on board, the missing ready would have shown up as
   "hist TOTAL_HITS stays 0 while MTSP TOTAL_HITS climbs" in simulation
   instead of on silicon. The user's auto-memory entry
   `feedback_tb_int_uses_generated_rtl.md` already calls this out as a
   rule:

   > "tb_int integration TB must compile the actual synthesis/ tree
   > (Qsys-generated wrappers, auto-inserted adapters / timing_adapters /
   > clk_bridges). Behavioral spec models hide the exact bugs the
   > integration TB exists to catch."

   The bug is exactly the failure mode that memory was written to
   prevent. The lesson is **we still under-used tb_int for Type1 source
   coverage** even though the auto-memory said we should.

2. **The qsys-syn log already shouts about it - we ignored it.**
   The qsys-syn log for the pre-fix build (2026-05-19 18:00) contained
   the line:
   ```
   avalon_st_adapter_025: Inserting timing_adapter: timing_adapter_0
   ```
   on the `hist_type1_up_tap.out1` → `histogram_statistics_0.type1_up`
   edge. An auto-inserted timing_adapter on a path that the IP author
   intended to be a flat readyless wire is a structural smell that
   matches BUG-021-I and BUG-027-I almost exactly. The
   `firmware_builds/systems/260518-feb-ok/syn/board_projects/fe_scifi_feb_v3/Makefile`
   does not grep the qsys-syn log for "Inserting timing_adapter" today.
   A simple post-step that fails the build if any timing_adapter shows
   up on a hot-path stream (the explicit list of hit_type0 /
   hit_type1_up / hit_type1_down edges) would have flagged this before
   the bitstream was even built.

## Tooling additions queued for next session

| Gate | What it would have caught | Implementation sketch |
|---|---|---|
| **tb_int must compile the qsys subsystem wrapper** | The exact wrapper-strip mode that BUG-027-I hit | `run_hist_v3.sh` (and every tb_int script) must add `scifi_datapath_system_v4.vhd` to the vcom list and the harness must instantiate the **wrapper** as DUT, not the bare hist IP. A pre-flight mechanical check: if the vcom list does not contain `scifi_datapath_system_v4.vhd` or `feb_system_v4.vhd`, the harness is not an integration TB and must be re-classified as a unit TB. |
| `qsys-validate --readyless-audit` | hw.tcl declarations that claim `readyLatency 0` but omit either `ready` or all of {valid, data} | Walk every `add_interface_port` block in the hw.tcl tree; flag avalon_streaming interfaces missing `ready` when the entity has an `asi_*_ready` / `aso_*_ready` port matching the interface name. |
| `make flow` qsys-syn log post-step | Auto-inserted `timing_adapter` / `channel_adapter` / `error_adapter` on the hit_type0 / hit_type1 plane | `grep "Inserting timing_adapter" qsys-syn.log` after the qsys-syn target; fail if any match falls on a hot-path edge whitelist. |
| hw.tcl entity-vs-interface diff | Any entity port that does not appear in any interface declaration | Static script that parses the entity ports list (from the RTL) and the `add_interface_port` set (from the hw.tcl); flags ports present in one and missing in the other. |

The top row is the dominant gap. The other three are belt-and-braces: if
the wrapper-instantiating tb_int had been in place, the bug would have
manifested as `TOTAL_HITS = 0` within milliseconds of the first Type1
beat, in simulation, with no need for any static audit.

## Companion lesson - BUG-028-H (the on-board sub-agent setup)

Item 4 above is the most general: a port that exists in the RTL but is
missing from the hw.tcl interface declaration is a class of bug Qsys does
not warn about. It is also how the **same family of bug** played out on
the Type0 path before today: the `hit_type0_fanout8` was correctly
readyless on both ends, but the conceptual mismatch (1 emulator source
broadcast to 8 lanes where 8 independent lanes were intended) is
architectural rather than packaging - and that one would not be caught by
the proposed checks. The merger_hit_type0 IP packaged today is the
architectural fix for Type0; the readyless-audit + log-grep checks are
the packaging fixes that close the Type1 surface.

## Memory entries queued

Two complementary memory entries will be added once the integration test
confirms the fix:

```
feedback_tb_int_must_compile_qsys_wrapper.md:
tb_int harnesses that claim to be "integration" tests must add the
qsys subsystem wrapper (e.g. scifi_datapath_system_v4.vhd) to the
vcom file list AND instantiate that wrapper as DUT - not the bare
leaf IP. A tb_int that picks only the IP RTL sources from
generated/simulation/.../submodules/ is structurally a unit TB
masquerading as an integration TB; it misses the entire surface
where qsys-generate strips entity ports omitted from the hw.tcl
interface declaration, and that is where BUG-027-I hid for weeks.
The check is mechanical: grep the run script for the wrapper file
name.

feedback_qsys_readyless_audit.md:
For any Avalon-ST interface with readyLatency=0 declared in an IP
hw.tcl, REQUIRE the ready port to appear in add_interface_port,
matching the entity output the RTL drives. Run a make qsys-validate
audit before every qsys-syn. Auto-inserted timing_adapter /
channel_adapter / error_adapter on the hit_type0/hit_type1 plane
edges must fail the build. Closes the silent-drop class of bug
shown by BUG-027-I.
```
