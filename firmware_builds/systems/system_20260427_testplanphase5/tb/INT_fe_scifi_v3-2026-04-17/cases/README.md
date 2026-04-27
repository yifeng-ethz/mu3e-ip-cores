# Domain Case Inventory

The current source-level integration harness is split into three domains:

- `rc.md`: run-control fanout and upload-link delivery
- `sc.md`: slow-control reachability, burst behavior, and boundary handling
- `dp.md`: datapath generation, transport, and histogram uptake

These files are the handoff point for the next UVM planning pass. They list the
stimulus already implemented here and the expansion buckets intentionally left
open for future case growth.
