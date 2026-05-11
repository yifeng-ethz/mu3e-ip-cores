# REPORT bucket - BASIC

| case | status | scenario |
|---|---|---|
| [B001](../B001/REPORT.md) | PASS | SWB RC firefly reset-link broadcast IDLE to RUN_PREP |
| [B002](../B002/REPORT.md) | PASS | SWB RC RUN_PREP to SYNC broadcast |
| [B003](../B003/REPORT.md) | PASS | SWB RC SYNC to RUNNING stable-window open |
| [B004](../B004/REPORT.md) | PASS | SWB RC RUNNING to TERMINATING with one in-flight packet |
| [B005](../B005/REPORT.md) | PASS | SWB RC TERMINATING to IDLE after bounded drain |
| [B006](../B006/REPORT.md) | PASS | SWB RC full IDLE to RUNNING to IDLE walk with 1 ms gap |
| [B007](../B007/REPORT.md) | PASS | SWB RC RUN_NUMBER increment before RUN_PREP |
| [B008](../B008/REPORT.md) | PASS | CSR-toggle RC fallback |
| [B033](../B033/REPORT.md) | PASS | SWB SC read OPQ CSR UID via PCIe BAR |
| [B034](../B034/REPORT.md) | PASS | SWB SC read rdma_subsystem CSR UID |
| [B040](../B040/REPORT.md) | PASS | SWB-local JTAG slow-control fallback |
| [B043](../B043/REPORT.md) | PASS | SWB SC single-word RW round-trip on scratch_pad |
| [B065](../B065/REPORT.md) | PASS | SWB DT one RQE ingress through OPQ to PCIe DMA egress |
| [B066](../B066/REPORT.md) | PASS | SWB DT rdma_subsystem CQE round-trip |
| [B067](../B067/REPORT.md) | PASS | SWB DT sidecar lineage at FEB-side rdma RQE ingress |
| [B068](../B068/REPORT.md) | PASS | SWB DT OPQ 4-lane fairness |
| [B069](../B069/REPORT.md) | PASS | SWB DT PCIe x8 DMA capture matches scoreboard |
