# on_board

This tier indexes board evidence for the same cases and variable-space plots
defined in `analytical/` and `tlm/`.

Current Phase 4 board anchors:

- [`../../board_test/phase4/TEST_PLAN_BASIC.md`](../../board_test/phase4/TEST_PLAN_BASIC.md)
- [`../../board_test/phase4/TEST_REPORT.md`](../../board_test/phase4/TEST_REPORT.md)
- [`../../board_test/phase4/inputs/board/`](../../board_test/phase4/inputs/board/)
- [`../../board_test/script/run_phase4_emulator.py`](../../board_test/script/run_phase4_emulator.py)
- [`../../board_test/script/probe_phase4_stage_counters.py`](../../board_test/script/probe_phase4_stage_counters.py)

Board data is accepted only when it is plotted against the matching TLM and RTL
simulation observables. If board data disagrees after RTL simulation agrees with
TLM, debug the image, register path, run state, bridge routing, and extraction
script before changing the high-level model.
