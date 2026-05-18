# DV_COV.md - SWB rdma_pretest-260511 tb_int coverage

**DUT:** `swb_a10/top`  **Date:** `2026-05-11`

PASS pass / closed &middot; PARTIAL partial / below target / known limitation &middot; FAIL failed / missing evidence &middot; PENDING pending &middot; INFO informational

## 1. Scope

This coverage skeleton tracks the selected 40-case structural UVM smoke. UCDB code coverage is intentionally `n/a` until the real mixed-language DUT bind is enabled.

## 2. Isolated Case Order

| order | case | bucket | status | evidence |
|---:|---|---|---|---|
| 1 | B001 | BASIC | PASS | REPORT/B001/REPORT.md |
| 2 | B002 | BASIC | PASS | REPORT/B002/REPORT.md |
| 3 | B003 | BASIC | PASS | REPORT/B003/REPORT.md |
| 4 | B004 | BASIC | PASS | REPORT/B004/REPORT.md |
| 5 | B005 | BASIC | PASS | REPORT/B005/REPORT.md |
| 6 | B006 | BASIC | PASS | REPORT/B006/REPORT.md |
| 7 | B007 | BASIC | PASS | REPORT/B007/REPORT.md |
| 8 | B008 | BASIC | PASS | REPORT/B008/REPORT.md |
| 9 | B033 | BASIC | PASS | REPORT/B033/REPORT.md |
| 10 | B034 | BASIC | PASS | REPORT/B034/REPORT.md |
| 11 | B040 | BASIC | PASS | REPORT/B040/REPORT.md |
| 12 | B043 | BASIC | PASS | REPORT/B043/REPORT.md |
| 13 | B065 | BASIC | PASS | REPORT/B065/REPORT.md |
| 14 | B066 | BASIC | PASS | REPORT/B066/REPORT.md |
| 15 | B067 | BASIC | PASS | REPORT/B067/REPORT.md |
| 16 | B068 | BASIC | PASS | REPORT/B068/REPORT.md |
| 17 | B069 | BASIC | PASS | REPORT/B069/REPORT.md |
| 18 | E001 | EDGE | PASS | REPORT/E001/REPORT.md |
| 19 | E002 | EDGE | PASS | REPORT/E002/REPORT.md |
| 20 | E003 | EDGE | PASS | REPORT/E003/REPORT.md |
| 21 | E033 | EDGE | PASS | REPORT/E033/REPORT.md |
| 22 | E043 | EDGE | PASS | REPORT/E043/REPORT.md |
| 23 | E065 | EDGE | PASS | REPORT/E065/REPORT.md |
| 24 | E066 | EDGE | PASS | REPORT/E066/REPORT.md |
| 25 | E067 | EDGE | PASS | REPORT/E067/REPORT.md |
| 26 | E068 | EDGE | PASS | REPORT/E068/REPORT.md |
| 27 | X001 | ERROR | PASS | REPORT/X001/REPORT.md |
| 28 | X002 | ERROR | PASS | REPORT/X002/REPORT.md |
| 29 | X003 | ERROR | PASS | REPORT/X003/REPORT.md |
| 30 | X004 | ERROR | PASS | REPORT/X004/REPORT.md |
| 31 | X005 | ERROR | PASS | REPORT/X005/REPORT.md |
| 32 | X033 | ERROR | PASS | REPORT/X033/REPORT.md |
| 33 | X065 | ERROR | PASS | REPORT/X065/REPORT.md |
| 34 | X069 | ERROR | PASS | REPORT/X069/REPORT.md |
| 35 | P001 | PROF | PASS | REPORT/P001/REPORT.md |
| 36 | P002 | PROF | PASS | REPORT/P002/REPORT.md |
| 37 | P003 | PROF | PASS | REPORT/P003/REPORT.md |
| 38 | P065 | PROF | PASS | REPORT/P065/REPORT.md |
| 39 | P066 | PROF | PASS | REPORT/P066/REPORT.md |
| 40 | P068 | PROF | PASS | REPORT/P068/REPORT.md |

## 3. Bucket Frame Order

| bucket | first case | last case | status | note |
|---|---|---|---|---|
| BASIC | B001 | B069 | PARTIAL | selected BASIC subset only |
| EDGE | E001 | E065 | PARTIAL | selected EDGE subset only |
| ERROR | X001 | X069 | PARTIAL | selected ERROR subset only |
| PROF | P065 | P068 | PARTIAL | selected PROF subset only |

## 4. Coverage Totals

| metric | isolated selected | bucket_frame | all_buckets_frame |
|---|---|---|---|
| statement | n/a | n/a | n/a |
| branch | n/a | n/a | n/a |
| condition | n/a | n/a | n/a |
| expression | n/a | n/a | n/a |
| FSM state | n/a | n/a | n/a |
| FSM transition | n/a | n/a | n/a |
| toggle | n/a | n/a | n/a |
