# Agent Notes

Use this file as navigation for `mu3e-ip-cores`. Detailed setup, math, test
catalogs, and signoff contracts live in the linked Markdown; do not duplicate
those workflows here.

## Active Scope

| Area | Path | Reference |
|---|---|---|
| Active FEB SciFi system | [`firmware_builds/systems/system_20260427_testplanphase5/`](firmware_builds/systems/system_20260427_testplanphase5/) | [`firmware_builds/README.md`](firmware_builds/README.md), [`firmware_builds/doc/SETUP.md`](firmware_builds/doc/SETUP.md) |
| Active board-test scripts, reports, SignalTap | [`firmware_builds/systems/system_20260427_testplanphase5/script/`](firmware_builds/systems/system_20260427_testplanphase5/script/), [`reports/`](firmware_builds/systems/system_20260427_testplanphase5/reports/), [`signaltap/`](firmware_builds/systems/system_20260427_testplanphase5/signaltap/) | [`firmware_builds/doc/TEST_PLAN_PHASE5.md`](firmware_builds/doc/TEST_PLAN_PHASE5.md) |
| Durable model tree | [`firmware_builds/systems/system_20260427_testplanphase5/model/`](firmware_builds/systems/system_20260427_testplanphase5/model/) | Phase-specific model docs under that tree plus [`firmware_builds/doc/phase4/TEST_PLAN_BASIC.md`](firmware_builds/doc/phase4/TEST_PLAN_BASIC.md) |
| Shared System Console toolkits | [`toolkits/`](toolkits/) | [`toolkits/fe_scifi/README.md`](toolkits/fe_scifi/README.md), [`toolkits/infra/README.md`](toolkits/infra/README.md) |
| Active Quartus FEB project | [`firmware_builds/systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/`](firmware_builds/systems/system_20260427_testplanphase5/syn/board_projects/fe_scifi_feb_v3/) | [`firmware_builds/doc/SETUP.md`](firmware_builds/doc/SETUP.md) |
| Integration simulation | [`firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/`](firmware_builds/systems/system_20260427_testplanphase5/tb/INT_fe_scifi_v3-2026-04-17/) | [`firmware_builds/doc/TEST_PLAN.md`](firmware_builds/doc/TEST_PLAN.md), [`firmware_builds/doc/TEST_PLAN_PHASE5.md`](firmware_builds/doc/TEST_PLAN_PHASE5.md) |
| Project operational memory | [`MEMORY.md`](MEMORY.md) | Sticky hardware/debug lessons: Phase-5 compile settings, SignalTap scope limits, SWB recovery expectations, and timing-closure heuristics. |

## External Project Map

| Project | Role | Path | Notes |
|---|---|---|---|
| `online_dpv2` | FEB production/runtime consumer, `libmudaq`, MuTRiG cfg packing reference | `/home/yifeng/packages/online_dpv2/online` | Its `online/mu3e-ip-cores` is a deprecated snapshot symlink; its `online/mu3e-ip-cores/toolkits` link must resolve back to this repo. |
| `online_sc` | SWB firmware and `/dev/mudaq0`/SC/reset-link behavior | `/home/yifeng/packages/online_sc` | SWB SOF for this bring-up is `online/switching_pc/a10_board/output_files/top.sof`; SWB-side `.stp` work belongs in the SWB tree. |
| `musip_2604` | MuSiP / SWB integration consumer workspace | `/home/yifeng/packages/musip_2604` | `external/mu3e-ip-cores` is pull-only; source fixes belong here first, then get synced into musip. |

## Important Rules

- Never modify generated RTL under any `functional/` output directory in place.
  If a change is needed, create a copy and ask for approval before wiring it in.
- Semantics-preserving edits for tool or simulator compatibility are OK.
  Functional or behavior changes require explicit approval.
- Shared System Console toolkit sources live under [`toolkits/`](toolkits/).
  The FE SciFi toolkit source of truth is [`toolkits/fe_scifi/`](toolkits/fe_scifi/).
  Do not add source changes through the `online_dpv2` deprecated snapshot path.
- For live FEB/SWB setup, programming, `/dev/mudaq0` recovery, and bridge
  preflight, follow [`firmware_builds/doc/SETUP.md`](firmware_builds/doc/SETUP.md)
  and [`firmware_builds/doc/TEST_PLAN.md`](firmware_builds/doc/TEST_PLAN.md).
- Before Phase-5 hardware/debug iteration, check [`MEMORY.md`](MEMORY.md) for
  non-contract lessons that save compile and board time. If it conflicts with a
  formal plan, the formal plan wins and `MEMORY.md` should be updated.
- For Phase 5 real-MuTRiG closure, use
  [`firmware_builds/doc/TEST_PLAN_PHASE5.md`](firmware_builds/doc/TEST_PLAN_PHASE5.md)
  plus the bucket files it links: [`TEST_BASIC.md`](firmware_builds/doc/TEST_BASIC.md),
  [`TEST_PROF.md`](firmware_builds/doc/TEST_PROF.md), [`TEST_EDGE.md`](firmware_builds/doc/TEST_EDGE.md),
  and [`TEST_ERROR.md`](firmware_builds/doc/TEST_ERROR.md).
- For Phase 4 emulator + histogram closure, use
  [`firmware_builds/doc/phase4/TEST_PLAN_BASIC.md`](firmware_builds/doc/phase4/TEST_PLAN_BASIC.md).
  The TLM is the reference for Phase 4; if SIM or board disagrees, debug the
  lower layer first.
- Treat Mu3e slides and reviewed upstream source artifacts as truth for RTL
  modeling. Use the `modeling-rtl` workflow: slides/spec/source RTL to
  analytical truth, then TLM, RTL simulation, and board evidence.
- A rate or latency claim is invalid until the relevant wiring/preflight gate in
  the linked test plan has passed. Do not invent observations from a half-wired
  chain.
- Generated reports and generated Platform Designer/Qsys outputs are evidence,
  not source contracts. Patch the source script, Qsys/Tcl, or plaintext plan
  that owns the behavior.
- Use direct technical critique when reviewing designs or proposed RTL. State
  weak assumptions, likely failure modes, and cleaner wording plainly; accuracy
  matters more than making the feedback sound soft.
- Be harsh and hit the point. Do not soften wording to make feedback sound
  nicer; clarity beats politeness. If a proposal has a weak premise, name the
  premise and the failure mode in one sentence and stop. Long hedging text
  ("we might consider whether possibly...") is rejected — write the call.

## Stale Claims To Reject

- `system_console_toolkit/` and `system_console_toolkits/` are historical
  consumer-snapshot names. Current shared toolkit source is [`toolkits/`](toolkits/).
- The SWB SOF used by the FEB SciFi bring-up is
  `/home/yifeng/packages/online_sc/online/switching_pc/a10_board/output_files/top.sof`;
  the older top-level `a10_board/top.sof` path is not present.
- The current PCIe recovery path for this FEB/SWB playbook is documented in
  [`firmware_builds/doc/SETUP.md`](firmware_builds/doc/SETUP.md) and
  [`firmware_builds/doc/TEST_PLAN.md`](firmware_builds/doc/TEST_PLAN.md).
  Do not use UIO binding when the next step expects `/dev/mudaq0`.
