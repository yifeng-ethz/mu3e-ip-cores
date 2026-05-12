# RN.BASIC.008 rdma (rxbuffer 8-frame sample)

Notes: board RDMA stream TBD

Timestamp-jitter tolerance: retained evidence supports record-count parity; byte-level expected frames are marked TBD unless board bytes are available.

## offset 0
| frame_idx | measured (hex) | sim (hex) | expected (hex) | match |
|---|---|---|---|:-:|
| 0 | -- | 8000000000000000 | -- | TBD |
| 1 | -- | 8100800000000000 | -- | TBD |
| 2 | -- | 8201000000000000 | -- | TBD |
| 3 | -- | 8301800000000000 | -- | TBD |
| 4 | -- | 8402000000000000 | -- | TBD |
| 5 | -- | c020000000000040 | -- | TBD |
| 6 | -- | 8502800000000000 | -- | TBD |
| 7 | -- | c120800000000040 | -- | TBD |

## offset 31256
| frame_idx | measured (hex) | sim (hex) | expected (hex) | match |
|---|---|---|---|:-:|
| 0 | -- | 8c0600000000f400 | -- | TBD |
| 1 | -- | c82400000000f440 | -- | TBD |
| 2 | -- | 844200000000f480 | -- | TBD |
| 3 | -- | c06000000000f4c0 | -- | TBD |
| 4 | -- | 8d0680000000f400 | -- | TBD |
| 5 | -- | c92480000000f440 | -- | TBD |
| 6 | -- | 854280000000f480 | -- | TBD |
| 7 | -- | c16080000000f4c0 | -- | TBD |

record_count measured: --
record_count sim: 62,512
record_count expected: 62,500
