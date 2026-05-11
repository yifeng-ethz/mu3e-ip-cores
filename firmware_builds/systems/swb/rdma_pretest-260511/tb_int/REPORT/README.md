# SWB tb_int REPORT

Selected-case structural UVM evidence for `swb/rdma_pretest-260511`.

| case | bucket | status | scenario |
|---|---|---|---|
| [B001](B001/REPORT.md) | BASIC | PASS | SWB RC firefly reset-link broadcast IDLE to RUN_PREP |
| [B006](B006/REPORT.md) | BASIC | PASS | SWB RC full IDLE to RUNNING to IDLE walk with 1 ms gap |
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
| [E033](E033/REPORT.md) | EDGE | PASS | OPQ ticket FIFO full boundary |
| [E043](E043/REPORT.md) | EDGE | PASS | concurrent PCIe sc_tool plus local JTAG arbitration (alias E-SC-CONC-001) |
| [E065](E065/REPORT.md) | EDGE | PASS | PCIe DMA burst-boundary |
| [X001](X001/REPORT.md) | ERROR | PASS | mid-flight RESET while OPQ has RQEs in flight |
| [X033](X033/REPORT.md) | ERROR | PASS | illegal PCIe BAR write to RO field |
| [X065](X065/REPORT.md) | ERROR | PASS | rdma CQE timeout |
| [X069](X069/REPORT.md) | ERROR | PASS | RUN_PREP issued while OPQ is mid-drain |
| [P065](P065/REPORT.md) | PROF | PASS | scaled 100 kHz/channel x 4 lanes PROF smoke |
| [P068](P068/REPORT.md) | PROF | PASS | sustained RQE ingress at line-rate structural scale |
