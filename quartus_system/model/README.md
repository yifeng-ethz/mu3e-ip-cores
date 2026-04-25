# quartus_system/model

This directory is the system-model evidence index for the SciFi Phase 4
emulator/histogram work. The live execution contract remains
[`../board_test/phase4/TEST_PLAN_BASIC.md`](../board_test/phase4/TEST_PLAN_BASIC.md).

The model tree is intentionally split by abstraction:

| Tier | Directory | Role |
|---|---|---|
| analytical | [`analytical/`](analytical/) | formulas, physical limits, and expected variable-space shapes from slides/specs |
| tlm | [`tlm/`](tlm/) | executable transaction-level models and generated CSV observables |
| on_board | [`on_board/`](on_board/) | board measurement extraction notes and links to hardware reports |

The rule is high-to-low: upstream slides/spec/source RTL define the expected
shape, analytical models encode it, TLM makes it executable, RTL simulation
must converge to the TLM, and on-board evidence must converge to RTL
simulation. Any disagreement is routed through the protocol in
`TEST_PLAN_BASIC.md`.

Every closed model view must include a DISLIN comparison with three explicit
evidence entries:

```text
Model/TLM
RTL SIM
BOARD
```

For 1D sweeps, such as loss probability versus input rate, plot the three
traces on one axis and mark the physical clip point. For 2D sweeps, such as
loss probability versus rate and burstiness, use the same sampled grid and show
the three tiers either as overlaid contours or as aligned panels with identical
axes and color scale. Record the worst disagreement location in the caption or
adjacent CSV summary.
