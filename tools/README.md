# Repo-Owned Tools

Tools in this directory are the preferred validation path for board bring-up,
packet inspection, and Phase-6 FEB-to-SWB-to-host closure.

Mu3e online software is reference-only. `online_dpv2`, MIDAS, `libmudaq`,
`rw`, `swb_dmatest`, and similar utilities can be used to inspect legacy
register maps, cfg packing, or historical behavior, but they must not be the
only evidence for signoff. They carry stale detector assumptions, implicit
cleanup, and ambiguous masks that can hide the first bad boundary.

New validation work should add or extend tools here first. A closure-quality
tool must:

- own its register addresses or state the exact reference source it mirrors;
- write only explicit values requested by the command line or manifest;
- capture raw RW/RO state before cleanup;
- write durable host artifacts, preferably binary plus JSON/Markdown metadata;
- make stale-buffer reuse and cleanup behavior visible.

Current Phase-6 DMA evidence starts with:

```bash
python3 tools/phase6_swb_dma_probe/phase6_swb_dma_probe.py --help
```
