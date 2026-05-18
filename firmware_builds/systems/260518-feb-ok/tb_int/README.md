# tb_int - 260518-feb-ok integration testbench

Integration testbench for the FEB SciFi v3 firmware build under
`firmware_builds/systems/260518-feb-ok/`. Layout follows the dv-workflow
and rtl-file-structure system folder contracts; the authoritative skill
docs are:

- `~/.codex/skills/dv-workflow/SKILL.md`
- `~/.codex/skills/rtl-file-structure-organization/SKILL.md`

## Layout

```
tb_int/
  README.md                     this file
  doc/                          plan + ledger
    DV_PLAN.md                  verification intent + bucket roll-up
    DV_HARNESS.md               UVM env, boundary agents, scoreboard, assertions
    DV_BASIC.md                 standard functional cases (bucket B)
    DV_EDGE.md                  corner + boundary cases (bucket E)
    DV_PROF.md                  soak / throughput / performance (bucket P)
    DV_ERROR.md                 reset / fault / illegal / recovery (bucket X)
    DV_CROSS.md                 cross-bucket continuous-frame intent (bucket C)
    DV_COV.md                   per-bucket coverage + final sign-off totals
    BUG_HISTORY.md              RTL + harness bug ledger (mandatory)
  uvm/                          single UVM env (Mu3e dv-workflow rule 19)
    harness/                    tb_top.sv, *_if.sv, *_uvm_pkg.sv
    sequence/                   per-case sequences + reusable fragments
    builds/                     Questa work dirs (gitignored)
    script/                     per-case run scripts + Makefile fragments
    log_link/                   symlink target into /data3/.../tb_int/log
    Makefile                    top-level UVM build/run driver
  REPORT/                       per-case Markdown + CSV evidence
  script/                       non-UVM helpers (waveform render, post-process)
  trash_bin/
    legacy_scenarios/           pre-restructure scenario dirs preserved for
                                reference: feb_swb_corun/, hist_bridge_switch/,
                                hist_dualport/, qsys_type1_delay/,
                                upload_backpressure/, plus the loose
                                tb_pre_hss_axis*.sv
```

## DUT contract (Mu3e tb_int rule 19)

The DUT is the **authentic generated FEB v3 firmware**, not a behavioral
spec. The UVM harness binds at the Qsys system boundary:

- `firmware_builds/systems/260518-feb-ok/generated/simulation/feb_system_v3/`
  (qsys-generate `--simulation=VERILOG`, DEBUG_LEVEL=2)

Boundary agents (drivers, monitors, sequencers, scoreboards, assertions)
attach to exposed buses / streams / conduits / run-control / reset / CSR
apertures only. No internal generated fabric is replaced. Adapt or extend
boundary agents across buckets; do not split into per-case DUT variants.

## Run

```bash
# from the system root:
make qsys                        # produce generated/simulation/feb_system_v3/
make -C tb_int/uvm run TEST=B001 # run a single directed case
make -C tb_int/uvm run_basic     # whole BASIC bucket in isolated mode
make -C tb_int/uvm bucket_frame BUCKET=B  # all-cases-one-frame mode (rule 8)
make -C tb_int/uvm all_buckets_frame      # everything in one continuous frame
```

(Targets and bucket framing are stubs at the moment; see `doc/DV_PLAN.md`
for the closure roadmap.)
