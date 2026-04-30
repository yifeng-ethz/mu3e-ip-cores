# Phase 6 SWB DMA Probe

Standalone SWB DMA/debug probe for Phase-6 bring-up and signoff evidence.

This tool intentionally does not call `swb_dmatest`, `rw`, MIDAS, libmudaq, or
any other Mu3e online executable. Those tools are deprecated for Phase-6 closure
and are useful only as register-map references. They carry stale detector
assumptions and cleanup behavior that can hide the first bad boundary.
Phase-6 evidence must come from repo-owned tools under `tools/` with the same
explicit raw-register contract.

## What It Does

- opens `/dev/mudaq0` and `/dev/mudaq0_dmabuf` directly;
- mmaps the RW and RO register windows using the kernel ABI;
- writes only explicit register values requested on the command line;
- captures all RW/RO registers plus raw SWB counter sweeps before cleanup;
- dumps the host DMA buffer to disk as binary and optional text;
- writes JSON/Markdown summaries that can be reduced offline.

## Typical Datagen Probe

```bash
python3 tools/phase6_swb_dma_probe/phase6_swb_dma_probe.py \
  --out-dir firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_dma_probe_custom/generic_time_datagen \
  --mode time-datagen \
  --profile generic \
  --generic-mask 0x1 \
  --hold-s 10 \
  --dump-text
```

## Typical FEB-Link Probe

```bash
python3 tools/phase6_swb_dma_probe/phase6_swb_dma_probe.py \
  --out-dir firmware_builds/systems/system_20260427_testplanphase5/reports/phase6_dma_probe_custom/scifi_time_links \
  --mode time-links \
  --profile scifi \
  --generic-mask 0x4 \
  --scifi-mask 0x4 \
  --hold-s 10 \
  --dump-text
```

Use `--no-cleanup` only for interactive live debug. Normal evidence runs should
clean up so the next run starts from known register values.
