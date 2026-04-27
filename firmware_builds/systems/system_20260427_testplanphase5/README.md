# system_20260427_testplanphase5

Phase 5 firmware build and verification workspace for FEB SciFi real-MuTRiG bring-up.

Read these before live hardware work:

- `../../doc/SETUP.md` — board programming, SMB mapping, and configuration files.
- `../../doc/CONTRACT.md` — AVST payload/framing/error policy across MTS, histogram tap, and ring-buffer CAM.
- `../../doc/MUTRIG.md` — MuTRiG mode/configuration notes.
- `../../doc/MATH.md` — latency/rate model sketch and histogram queue-depth assumptions.
- `../../doc/TEST_PLAN_PHASE5.md` — Phase-5 case catalog.

| Folder | Purpose |
|---|---|
| `model/` | Analytical, TLM, on-board, and phase-specific model evidence. |
| `tb/` | System-level integration simulation harnesses. |
| `syn/` | Qsys files, SOPC metadata, generated Platform Designer output, QIP files, IP catalogs, and synthesis logs. |
| `script/` | Qsys-generation Tcl, System Console/JTAG Tcl, board-test Python, and local C/C++ tool sources. |
| `bin/` | Locally built `sc_tool` and `rc_tool` binaries. |
| `generated/` | Generated inventory and helper outputs for this system. |
| `reports/` | Board-test and closure reports. |
| `captures/` | Captured VCD/STP evidence. |
| `signaltap/` | SignalTap definitions and probe reports. |
| `patterns/` | Traffic or register-pattern inputs. |
