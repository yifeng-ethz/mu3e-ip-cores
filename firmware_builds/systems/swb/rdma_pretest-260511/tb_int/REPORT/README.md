# SWB tb_int REPORT

Selected-case structural UVM evidence for `swb/rdma_pretest-260511`.

| case | bucket | status | scenario |
|---|---|---|---|
| [B001](B001/REPORT.md) | BASIC | PASS | SWB RC firefly reset-link broadcast IDLE to RUN_PREP |
| [B002](B002/REPORT.md) | BASIC | PASS | SWB RC RUN_PREP to SYNC broadcast |
| [B003](B003/REPORT.md) | BASIC | PASS | SWB RC SYNC to RUNNING stable-window open |
| [B004](B004/REPORT.md) | BASIC | PASS | SWB RC RUNNING to TERMINATING with one in-flight packet |
| [B005](B005/REPORT.md) | BASIC | PASS | SWB RC TERMINATING to IDLE after bounded drain |
| [B006](B006/REPORT.md) | BASIC | PASS | SWB RC full IDLE to RUNNING to IDLE walk with 1 ms gap |
| [B007](B007/REPORT.md) | BASIC | PASS | SWB RC RUN_NUMBER increment before RUN_PREP |
| [B008](B008/REPORT.md) | BASIC | PASS | CSR-toggle RC fallback (alias B-RC-CSR-001) |
| [B033](B033/REPORT.md) | BASIC | PASS | SWB SC read OPQ CSR UID via PCIe BAR |
| [B034](B034/REPORT.md) | BASIC | PASS | SWB SC read rdma_subsystem CSR UID |
| [B040](B040/REPORT.md) | BASIC | PASS | SWB-local JTAG slow-control fallback (alias B-SC-JTG-001) |
| [B043](B043/REPORT.md) | BASIC | PASS | SWB SC single-word RW round-trip on scratch_pad |
| [B065](B065/REPORT.md) | BASIC | PASS | SWB DT one RQE ingress through OPQ to PCIe DMA egress |
| [B066](B066/REPORT.md) | BASIC | PASS | SWB DT rdma_subsystem CQE round-trip |
| [B067](B067/REPORT.md) | BASIC | PASS | SWB DT sidecar lineage at FEB-side rdma RQE ingress |
| [B068](B068/REPORT.md) | BASIC | PASS | SWB DT OPQ 4-lane fairness |
| [B069](B069/REPORT.md) | BASIC | PASS | SWB DT PCIe x8 DMA capture matches scoreboard |
| [E001](E001/REPORT.md) | EDGE | PASS | back-to-back zero-gap RC |
| [E002](E002/REPORT.md) | EDGE | PASS | state CSR co-write during RUN_PREP edge |
| [E003](E003/REPORT.md) | EDGE | PASS | frame boundary RUNNING open with one packet per lane |
| [E033](E033/REPORT.md) | EDGE | PASS | OPQ ticket FIFO full boundary |
| [E043](E043/REPORT.md) | EDGE | PASS | concurrent PCIe sc_tool plus local JTAG arbitration (alias E-SC-CONC-001) |
| [E065](E065/REPORT.md) | EDGE | PASS | PCIe DMA burst-boundary |
| [E066](E066/REPORT.md) | EDGE | PASS | maximum legal RQE packet at host segment boundary |
| [E067](E067/REPORT.md) | EDGE | PASS | lane-3 frame-boundary cluster |
| [E068](E068/REPORT.md) | EDGE | PASS | all-lane cluster burst at CQ turnaround boundary |
| [X001](X001/REPORT.md) | ERROR | PASS | mid-flight RESET while OPQ has RQEs in flight |
| [X002](X002/REPORT.md) | ERROR | PASS | mid-flight RESET during RUN_PREP state shadow update |
| [X003](X003/REPORT.md) | ERROR | PASS | mid-flight RESET during host DMA issue |
| [X004](X004/REPORT.md) | ERROR | PASS | truncated run-control state word is rejected |
| [X005](X005/REPORT.md) | ERROR | PASS | truncated state word followed by legal recovery |
| [X033](X033/REPORT.md) | ERROR | PASS | illegal PCIe BAR write to RO field |
| [X065](X065/REPORT.md) | ERROR | PASS | rdma CQE timeout |
| [X069](X069/REPORT.md) | ERROR | PASS | RUN_PREP issued while OPQ is mid-drain |
| [P001](P001/REPORT.md) | PROF | PASS | long RUNNING window structural load |
| [P002](P002/REPORT.md) | PROF | PASS | RUN_NUMBER bumps between short host batches |
| [P003](P003/REPORT.md) | PROF | PASS | watchdog overlap while OPQ drains under load |
| [P065](P065/REPORT.md) | PROF | PASS | scaled 100 kHz/channel x 4 lanes PROF smoke |
| [P066](P066/REPORT.md) | PROF | PASS | host CQE turnaround under balanced four-lane load |
| [P068](P068/REPORT.md) | PROF | PASS | sustained RQE ingress at line-rate structural scale |
