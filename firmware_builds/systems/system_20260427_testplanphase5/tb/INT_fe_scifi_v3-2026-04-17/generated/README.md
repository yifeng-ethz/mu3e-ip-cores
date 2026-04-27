# Generated Bench Artifacts

This directory holds simulation-only artifacts derived from source benches or
generated wrappers.

Conventions:
- `generated/rc/`: RC-domain derived benches and quiet adapter copies
- `generated/sc/`: SC-domain derived benches and quiet adapter copies
- `generated/dp/`: datapath-domain quiet wrappers and filtered top copies

Nothing here is design source of truth. If a transform is wrong, fix the
generator in `scripts/` rather than editing generated files by hand.
