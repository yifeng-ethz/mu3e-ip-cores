# firmware_builds

Firmware system builds live under `systems/`.

Current active build:

- `systems/system_20260427_testplanphase5/` — Phase 5 FEB SciFi / real-MuTRiG bring-up and verification build.

Required Phase-5 references:

- `doc/SETUP.md` — SWB/FEB programming, SMB3/SMB5 mapping, and live-board setup.
- `doc/CONTRACT.md` — AVST payload/framing/error-sideband contract and trim policy.
- `doc/MUTRIG.md` — MuTRiG configuration files, TDC injection, analog mode, and PLL-lock interpretation.
- `doc/MATH.md` — latency/rate model sketch and histogram queue-depth gate.
- `doc/TEST_PLAN_PHASE5.md` — real-MuTRiG Phase-5 case catalog.

Top-level folders:

| Folder | Purpose |
|---|---|
| `doc/` | Canonical test plans and signoff documentation. |
| `systems/` | Firmware compilation systems named `system_YYYYMMDD_<scope>`. |
| `misc/` | Non-build assets. |
| `trash_bin/` | Deprecated caches, abandoned work dirs, and unclassified legacy material. |
