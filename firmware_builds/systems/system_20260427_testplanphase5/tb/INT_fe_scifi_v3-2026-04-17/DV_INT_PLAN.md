# DV INT Plan

Tag: `INT_fe_scifi_v3-2026-04-17`
Date: `2026-04-17`

Planned checks:

1. Run control and upload split
   - Drive the upload host run-control seam into `feb_system_v3`
   - Confirm the run-control word reaches all datapath consumers
   - Inject one upper and one lower FEB frame at the frame-assembly seams
   - Confirm the two upload paths emerge on distinct SWB-side links

2. Datapath end to end
   - Program the embedded `emulator_mutrig_[0..7]` generators through the
     local datapath bench seam used for the on-chip emulators
   - Drive the run-control state machine into `RUNNING`
   - Confirm the live path shows:
     - external emulator word activity
     - MuTRiG datapath `hit_type0` activity
     - MTS `hit_type1` activity
     - hit-stack ingress acceptance
     - histogram bin accumulation over multiple bins through the exported AVMM
       histogram window

3. Slow control
   - Reuse the FEB SC smoke bench to confirm the SC hub reaches the control
     and datapath slaves expected by the v2 address map
   - Reuse the burst-vs-single directed bench to compare burst reads against
     sequential single-word reads across the same SC path

Harness organization for the next step:

1. `cases/rc.md`, `cases/sc.md`, `cases/dp.md`
   - domain-local stimulus inventory
   - current implemented checks
   - reserved expansion buckets for the future UVM plan

2. `generated/`
   - derived v3 bench copies from authoritative legacy FEB benches
   - quiet wrapper/adaptation sources that are generated for simulation only

3. `docs/HARNESS_LAYOUT.md`
   - current bridge architecture from source-Qsys INT smoke to future UVM
   - stable seams already proven useful for RC/SC/DP stimulus injection

4. `REPORT/{rc,sc,dp}/`
   - runtime evidence kept separate by domain so future extended regressions do
     not collapse into one flat log bucket
