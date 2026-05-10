# Bug History — `arb_hit_type0`

**Parent:** [DV_PLAN.md](DV_PLAN.md)

Append-only log of every confirmed bug found during DV or integration. Format follows the `dv-workflow` skill contract.

| ID | Date | Severity | Bucket / Case | Title | Status | Fix | Evidence |
|---|---|---|---|---|---|---|---|
| DOC-20260504-RTL-001 | 2026-05-04 | Documentation | RTL implementation | RTL_PLAN/DV disagree on per-beat vs EOP hit-counter semantics, and SYNDROME_DROP_MID_PACKET exposes only 4 bits for a 16-deep FIFO depth. | Open | Implemented the prompt/RTL_PLAN section 2.2 per-beat counter model; FIFO-depth syndrome field saturates at 4'hF until the CSR map is clarified. | doc/RTL_PLAN.md sections 2.2, 2.3, 2.4; tb/DV_BASIC.md B009/B016/B020 |
| DOC-20260504-RTL-001 | 2026-05-04 | Documentation | RTL implementation | Counter and syndrome documentation closure. | Closed | Per-beat counter semantics are documented in RTL/DV text and RTL comments; SYNDROME_DROP_MID_PACKET now records 5-bit FIFO depth at `[9:5]` for `0..16`. | doc/RTL_PLAN.md sections 2.2, 2.3, 2.4; rtl/arb_hit_type0_csr.sv; tb/DV_PLAN.md; tb/DV_BASIC.md |
