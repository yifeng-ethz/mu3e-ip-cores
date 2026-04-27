# tlm

This tier hosts or indexes executable transaction-level models that produce
CSV observables for the same variable space defined by `analytical/`.

Current Phase 4 TLM anchors:

- [`../../board_test/phase4/tlm/phase4_latency_tlm.sv`](../../board_test/phase4/tlm/phase4_latency_tlm.sv)
- [`../../board_test/phase4/scripts/phase4_queue_tlm.py`](../../board_test/phase4/scripts/phase4_queue_tlm.py)
- [`../../board_test/phase4/artifacts/`](../../board_test/phase4/artifacts/)

The TLM output is the executable reference for RTL simulation comparisons. Do
not retune the TLM to match discrepant RTL or board data unless the upstream
truth artifact or analytical model is first corrected.
