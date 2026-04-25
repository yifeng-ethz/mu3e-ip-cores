# analytical

This tier records the high-level truth used by the Phase 4 BASIC catalog.

Current anchor:

- [`../../board_test/phase4/TEST_PLAN_BASIC.md`](../../board_test/phase4/TEST_PLAN_BASIC.md)
- [`../../board_test/phase4/MATH_REPORT.md`](../../board_test/phase4/MATH_REPORT.md)

Required contents for new analytical entries:

- upstream truth artifact, such as a Mu3e slide, spec, or source-RTL constant;
- swept variables, units, and valid range;
- closed-form limit or recurrence relation;
- expected plot shape before RTL or board data is inspected.

For Phase 4, the key analytical limits are 25 Mhit/s per MuTRiG,
100 Mhit/s per 4-MuTRiG datapath, and 200 Mhit/s into the 8-MuTRiG histogram.
