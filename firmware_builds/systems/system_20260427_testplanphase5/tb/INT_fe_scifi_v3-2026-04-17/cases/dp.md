# DP Domain

Currently implemented:
- embedded emulator programming through the local datapath seam
- run-state enable into the live datapath
- observation of external emulator words
- observation of MuTRiG `hit_type0` traffic
- observation of MTS `hit_type1` traffic
- observation of hit-stack ingress acceptance
- histogram configuration/readback and multi-bin accumulation

Useful expansion buckets for future UVM:
- per-lane arbitration between real LVDS and emulator sources
- RR mux fairness and starvation checks
- shallow FIFO overflow / drop characterization
- run-control start/stop transitions during active traffic
- per-lane disable / sparse-lane stimulus matrices
- histogram rollover, clear, and interval corner cases
- upload-path correlation between datapath production and FEB output framing
