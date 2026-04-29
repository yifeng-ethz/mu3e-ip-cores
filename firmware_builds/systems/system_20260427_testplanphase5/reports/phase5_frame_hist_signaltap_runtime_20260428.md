# Phase-5 frame/histogram SignalTap runtime report

**Date:** 2026-04-28 20:36 CEST
**Revision:** `top_stp_pipe_phase5_frame_hist`
**STP source:** `../signaltap/phase5_frame_hist_path.stp`

## Summary

The divider-fix SOF was compiled and programmed successfully, but the first
runtime SignalTap acquisition failed before capture because Quartus could not
find a matching SignalTap instance in the programmed image:

```text
Error (261005): Can't find the instance. Download a design with SRAM Object File containing this instance.
```

This was reproduced with the original `phase5_frame_hist_path.stp`, a
presentation-only `phase5_frame_hist_path_mux0_valid.stp` trigger variant, and
both `phase5_frame_hist_path` / `auto_signaltap_0` instance names. No accepted
VCD exists from that SOF.

## Root Cause

The board project QSF named the STP source and enabled SignalTap, but the STP
had not been imported into the `top_stp_pipe_phase5_frame_hist` revision before
the compile. Before the fix the revision had:

```text
set_global_assignment -name USE_SIGNALTAP_FILE ".../phase5_frame_hist_path.stp"
set_global_assignment -name ENABLE_SIGNALTAP ON
```

It did not have the generated `SLD_FILE db/..._auto_stripped.stp` assignment or
the `POST_FIT_CONNECT_TO_SLD_NODE_ENTITY_PORT crc[*]` assignments that are
present in known-good Phase-3/4 STP revisions.

## Fix Applied To The Project Revision

The STP was imported with the same enable flow used by the known-good run-control
STP preparation scripts:

```text
quartus_stp top -c top_stp_pipe_phase5_frame_hist --enable --stp_file=.../phase5_frame_hist_path.stp
```

Quartus SignalTap completed with 0 errors and 0 warnings. The import created:

```text
db/phase5_frame_hist_path_auto_stripped.stp
```

and updated `top_stp_pipe_phase5_frame_hist.qsf` with the `phase5_frame_hist_path`
SLD node, 891 trigger/data/storage inputs, non-zero CRC post-fit connections,
and:

```text
set_global_assignment -name SLD_FILE db/phase5_frame_hist_path_auto_stripped.stp
```

The source STP has no explicit trigger CRC field; the stripped/imported STP now
has trigger CRC `B5AFE18F`.

The same preparation sequence is now captured in:

```text
../script/prepare_phase5_frame_hist_path_stp.sh
```

## Required Next Step

The currently programmed FPGA image was built before this import, so it remains
runtime-incompatible with the STP. Recompile `top_stp_pipe_phase5_frame_hist`,
program the new SOF, then rerun the frame/histogram acquisition.
