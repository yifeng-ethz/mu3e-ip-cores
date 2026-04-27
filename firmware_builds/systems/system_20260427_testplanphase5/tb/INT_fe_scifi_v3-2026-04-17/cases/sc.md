# SC Domain

Currently implemented:
- single-read smoke sweep across the expected control-path slaves
- single-read smoke sweep across the expected datapath slaves
- full-aperture burst-vs-single compare matrix
- boundary-tail characterization
- deterministic random in-aperture burst windows
- cross-boundary behavior characterization

Useful expansion buckets for future UVM:
- write-path coverage for writable CSRs and memories
- illegal / unmapped address behavior
- waitrequest stress and outstanding-request corner cases
- mixed control-plane and datapath-plane read interleaving
- long burst traffic during active datapath generation
- explicit external-SC coverage for the v3 emulator CSR bank and datapath
  debug aliases (`dbg_mm2runctrl`, reset-controller management bridge)
- optional future coverage for LVDS-error counters only if the currently
  disabled `lvdserr_count_subsystem` is intentionally brought back into use
- scoreboard classification for live CSR divergence versus true protocol failure
