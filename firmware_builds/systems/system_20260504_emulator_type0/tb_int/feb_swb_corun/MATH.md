# FEB to SWB Corun Math Note

This note records the finite-burst timing and conservation contract for the
`feb_swb_corun` direct continuation run.  It is a math sidecar only.  It does
not modify RTL, UVM, scripts, or generated reports.

## Scope

The maintained contract run assumes the OPQ is provisioned as a lossless,
non-bottleneck stage for this finite 1 ms burst.  In this scope:

- OPQ buffering and service are sufficient for the complete finite burst and
  subsequent drain.
- All OPQ controlled drop counters must remain zero.
- OPQ delay is a finite measured queue/drain metric, not a loss explanation.
- DMA must conserve every hit accepted and emitted by OPQ.

An earlier 1024-depth diagnostic profile observed `rho > 1` at the OPQ frame
service level and produced controlled lane-credit loss.  That profile is useful
for overload diagnosis and first-loss calibration, but it is excluded from the
lossless contract derived here.

## Assumptions

- Time unit is one 8 ns cycle.
- FEB stream clock is 125 MHz.  SWB datapath clock is 250 MHz.  The clocks are
  synchronous, and all formulas below are normalized to 8 ns cycles.
- `N_SHD = 128`.
- One subheader bucket spans `H = 16` cycles.
- One FEB/SWB frame spans

```text
F = N_SHD * H = 128 * 16 = 2048 cycles.
```

- The active source window is

```text
T_run = 1 ms = 125000 cycles.
```

- Lane 0 carries ASIC0 channels `0..31` at 100 kHz/channel.
- Lane 1 emits legal empty FEB frames.
- Lanes 2 and 3 are masked and must not contribute accepted hits.
- The direct corun pre-rbCAM and post-rbCAM checkpoints are synthetic lineage
  markers.  They are not the true rbCAM instance from the full FEB integration
  path.

## Notation

Let `m` index a simultaneous 32-channel ASIC0 sample and let `c` index the
channel inside the sample:

```text
m = 0..99
c = 0..31
hit_id(m,c) = 32*m + c
```

The per-channel hit period is

```text
P_hit = 10 us = 1250 cycles.
```

The source generation time of sample `m` is

```text
t_m = P_hit * m = 1250*m.
```

The frame, phase, subheader bucket, and bucket residue are

```text
f_m = floor(t_m / F)
p_m = t_m - F*f_m
b_m = floor(p_m / H)
r_m = p_m - H*b_m.
```

For this profile, `r_m = (2*m) mod 16`, so only even residues occur.

## Master Equation

All lifetime plots use one origin:

```text
GTS_hit(m,c) = t_m
D_i(m,c)    = T_i(m,c) - GTS_hit(m,c).
```

`GTS_hit` is reconstructed from the carried MuTRiG timestamp contract:

```text
DMA_ts_8ns              = GTS_hit
DEBUG.ts_tag            = GTS_hit mod 2^16
DEBUG.ps_tag            = GTS_hit mod 2^8
MuTRiG hit ts_low[3:0]  = GTS_hit mod 16
MuTRiG hit rem[2:0]     = GTS_hit mod 8
DEBUG.hit_id            = 32*m + c.
```

The local time at which the testbench writes a source trace row is not the
definition of lifetime.  It is only an observation.  If a plot changes shape
when the local source marker is moved but the carried hit timestamp is
unchanged, the lifetime definition is wrong.

For a window of length `t`, the full32 periodic arrival curve is bounded by:

```text
alpha_hit(t) = 32 * ceil(t / P_hit)
             = 32 * ceil(t / 1250).
```

A looser affine envelope useful for rate-latency algebra is:

```text
alpha_hit(t) <= sigma + rho*t
sigma = 32 hits
rho   = 32 / 1250 = 0.0256 hits/cycle.
```

For a deterministic stage with latency `L_i`, rate `R_i`, and finite burst
term `B_i`, a latency-rate service curve gives:

```text
beta_i(t) = R_i * [t - L_i]^+
D_i <= L_i + B_i / R_i.
```

For the OPQ frame queue, the measured deterministic recurrence is:

```text
A_n = a_n - a_(n-1)
S_n = d_n - d_(n-1)
W_n = max(0, W_(n-1) + S_n - A_n)
D_opq_egress(m,c) = D_opq_ingress(m,c) + W_frame(f_m) + O_merge(m,c).
```

Under the scoped lossless assumption, this is a finite-burst drain equation,
not an infinite-run stability proof.  Conservation and zero OPQ drop counters
remain the hard pass/fail checks.

The DISLIN lifetime plot uses the same x-axis range for every checkpoint.  For
the current run, the range is driven by the OPQ finite-burst drain envelope and
rounds to:

```text
0 <= D_i <= 100000 cycles.
```

Green vertical lines mark the checkpoint-specific network-calculus or
programmed-aperture bound on that common axis.

## Traffic Profile

The number of simultaneous source samples per channel is

```text
N_sample = T_run / P_hit = 125000 / 1250 = 100.
```

The total offered hit count on lane 0 is

```text
N_hit = N_sample * 32 = 3200.
```

The number of emitted frame periods is

```text
N_frame = ceil(T_run / F) = ceil(125000 / 2048) = 62.
```

Lane 0 has nonempty hit frames `0..60` and an empty terminal frame `61`.
Across the nonempty lane-0 frames:

```text
39 frames carry 2 source samples = 39 * 64 hits
22 frames carry 1 source sample  = 22 * 32 hits
total                            = 3200 hits.
```

Lane 1 emits 62 legal empty frames.  In the lane-0 OPQ queue model there are
62 paired input/output frame SOPs.  In a two-lane ingress count, the frame
traffic contains 124 FEB frame packets, of which lane 1 is empty by contract.

## Source and Bucket Checks

The source-side scoreboard has hard, profile-specific checks:

```text
source hit count       = 3200
source sample count    = 100
per-channel hit count  = 100
hit_id sequence        = 0..3199
source time            = 1250*floor(hit_id/32)
source channel         = hit_id mod 32
source frame           = floor(source time / 2048)
source bucket          = floor((source time mod 2048) / 16)
```

Lane 1 must contribute zero real hits.  Lanes 2 and 3 must contribute zero
accepted hits under the lane mask.

## rbCAM Reference Bound

For the full FEB path, the rbCAM is a finite resequencing service element.  Let
`L_rb` be the programmed expected latency, with the default value

```text
L_rb = 2000 cycles.
```

The descriptor generator walks bucket starts.  For a hit generated at
`t_m = F*f_m + H*b_m + r_m`, the first bucket-eligible command time is

```text
T_cmd(m) = F*f_m + H*b_m + L_rb.
```

Thus the bucket-quantized command delay is

```text
D_cmd(m) = T_cmd(m) - t_m = L_rb - r_m.
```

For arbitrary phase within a 16-cycle bucket:

```text
1985 <= D_cmd <= 2000.
```

For this 100 kHz profile, only even residues occur, so:

```text
1986 <= D_cmd <= 2000.
```

Real rbCAM hit egress adds a bounded search/count/drain term:

```text
D_rb_hit(m,c) = D_cmd(m) + D_search + D_drain(m,c).
```

The direct FEB/SWB corun does not instantiate the true rbCAM.  Its pre/post
CSV rows are lineage identity markers used to prove hit conservation before the
FEB frame writer.  The lifetime plot therefore imports the full-FEB rbCAM
reference traces for the top two panels:

```text
pre-rbCAM reference:
  D_pre = (abs_ts_pre_rbcam - abs_ts_a) / 8000
  validation aperture = [0, 2000] cycles

post-rbCAM DEBUG reference:
  D_post = (post_monitor_GTS - hit_ts8n_from_DEBUG_matched_ingress) mod 8192
  validation aperture = [2000, 2200) cycles
```

The accepted 100 kHz/channel full32 rbCAM/FEB reference case is:

```text
tb_int/sim/feb_egress_queueing_20260508/
  prof_int_002_feb_egress_periodic_asic0_full32_emu_direct_100k_1ms_gap1ms_20260508
```

The reference is accepted only if the trace health checks pass:

```text
drops.csv                         = header only
counter_agreement.csv             = available=1 and agree=1 for all counters
transcript UVM_ERROR              = 0
transcript missing/ghost residual = 0 at every reported tunnel
```

The current accepted summaries are:

```text
pre-rbCAM:
  count = 3136
  min/p50/p95/max = 17 / 17 / 17 / 17 cycles

post-rbCAM:
  count = 3136
  min/p50/p95/max = 2001 / 2070 / 2128 / 2139 cycles
  in [2000,2200) = 3136 hits
```

The pre-rbCAM reference point is before the programmed rbCAM retention delay,
so the clean full-FEB reference shows the fixed 17-cycle transport marker.  The
post-rbCAM DEBUG age is measured after the DEBUG-matched rbCAM ingress point
against the carried hit timestamp modulo the 8192-cycle rbCAM epoch, so it must
concentrate inside the programmed `[2000,2200)` acceptance aperture.

The earlier reference
`prof_int_002_pre_rbcam_periodic_asic0_full32_100k` is rejected for this plot.
Its pre-rbCAM distribution had `p50=84930` cycles and only 1088 hits inside
`[0,2000]`, but its transcript also reported residual loss:

```text
A=15872 PRE=13728 POST=13041 FEB=10921
A->PRE missing      = 2144
PRE->POST missing   = 687
POST->FEB missing   = 2134
drops.csv rows      = 4965
```

That far pre-rbCAM peak is therefore not accepted no-drop evidence for this
contract.  Any future rbCAM reference with nonempty `drops.csv`, failed counter
agreement, nonzero UVM errors, or nonzero missing/ghost residuals is an analyzer
failure before plotting.

## FEB Frame Assembly and Store-Forward Bound

The maintained direct corun now models FEB frame store-forward explicitly.  A
source hit is born at `t_m`, but the FEB stream for frame `f_m` begins after
two 2048-cycle frame periods:

```text
T_feb_sop(m) = F*f_m + 2*F.
```

Let `q_m` be the number of earlier source samples in the same frame whose
buckets are lower than `b_m`.  In this profile `q_m` is either 0 or 1.  With
five frame header words, all 128 subheaders emitted, and 32 hit words per
source sample, the logical hit word offset from the frame SOP is

```text
O(m,c) = 5 + b_m + 1 + 32*q_m + c.
```

The testbench drives one FEB word every two 125 MHz clock edges, so the
observed hit-word offset is approximately `2*O(m,c)` plus the simulator
sampling phase.  The store-forward hit lifetime is therefore modeled as

```text
D_feb(m,c) ~= 2*F - p_m + 2*O(m,c) + epsilon_clk
            = 4096 - p_m + 2*(6 + b_m + 32*q_m + c) + epsilon_clk.
```

The latest 8192-depth OPQ, DEBUG_LEVEL=2 corun measured:

```text
2386.5 <= T_feb_egress(m,c) - t_m <= 4172.5 cycles.
```

The maintained hard validation range keeps frame-start and word-offset margin:

```text
2049 <= T_feb_egress(m,c) - t_m <= 6143 cycles.
```

This is profile-specific to `N_SHD=128`, two-frame dispatch, all-subheader
emission, and 32 simultaneous channels/sample.

## OPQ Ingress Adapter

The parallel 125 MHz FEB to 250 MHz SWB ingress adapter is finite and
source-synchronous in this corun.  It follows the FEB egress hit by a small
clock-domain adapter delay.  The latest run measured:

```text
2387.75 <= T_opq_ingress(m,c) - t_m <= 4173.75 cycles
T_opq_ingress(m,c) - T_feb_egress(m,c) = 1.25 cycles.
```

The maintained source-lifetime range is:

```text
2049 <= T_opq_ingress(m,c) - t_m <= 6159 cycles.
```

The scoreboard must require:

```text
OPQ ingress hit count  = 3200
OPQ ingress identity   = source identity exactly
OPQ ingress frame      = f_m
OPQ ingress bucket     = b_m
masked-lane hits       = 0
```

This is a profile-specific finite adapter bound.  It is not an OPQ queueing
bound.

## OPQ Lossless Queue Contract

Let `a_n` be the OPQ ingress frame SOP time for lane-0 frame `n`, and let
`d_n` be the corresponding OPQ egress frame SOP time after ordered merge and
presentation.  Define:

```text
A_n = a_n - a_(n-1)          for n > 0
S_n = d_n - d_(n-1)          for n > 0
W_n = d_n - a_n
```

For a continuously busy deterministic server, the measured wait must satisfy

```text
W_n = W_(n-1) + S_n - A_n.
```

If the queue can empty between frames, the recurrence becomes the Lindley form:

```text
W_n = max(0, W_(n-1) + S_n - A_n).
```

For the scoped lossless contract, the recurrence is a timing-consistency check
only.  It does not explain loss.  The OPQ must instead satisfy conservation:

```text
OPQ controlled pre-drop count     = 0
OPQ controlled post-drop count    = 0
OPQ frame-table drop count        = 0
OPQ ingress hit count             = 3200
OPQ egress hit count              = 3200
unexplained OPQ hit delta         = 0
```

For a finite trace, OPQ may still have a finite queue-drain delay even if a
short interval has service slower than arrival.  Let `B(t)` be the live OPQ
backlog in frames, packets, or words under the chosen accounting unit:

```text
B(t) = arrivals_accepted(0,t] - departures(0,t].
```

A sufficient finite-burst provisioning condition is:

```text
C_opq >= max_t B(t)
```

with drain allowed after the 1 ms source window.  The delay envelope is then a
measured finite property of the provisioned run:

```text
D_opq_hit(m,c) = T_opq_egress(m,c) - t_m
D_opq_min <= D_opq_hit(m,c) <= D_opq_max.
```

The measured values `D_opq_min` and `D_opq_max` must come from a run with zero
OPQ drop counters and full hit conservation.  In the latest scoped run:

```text
OPQ ingress hits        = 3200
OPQ egress hits         = 3200
OPQ drop counter total  = 0
OPQ recurrence residual = 0 cycles
5596.75 <= D_opq_hit <= 95154.75 cycles.
```

These OPQ lifetime bounds are measured-envelope thresholds, not infinite
steady-state mathematical limits.

## Utilization and rho

Use rates for utilization:

```text
lambda = 1 / E[A_n]
mu     = 1 / E[S_n]
rho    = lambda / mu
       = E[S_n] / E[A_n].
```

Thus, when using interarrival and service intervals, `rho` is the service
interval divided by the arrival interval.  This avoids the common ambiguity:

```text
rho = arrival_rate / service_rate
    = service_interval / arrival_interval.
```

For an infinite steady-state lossless queue, `rho < 1` is the usual stability
condition.  For this finite 1 ms contract, `rho >= 1` over a short diagnostic
segment is not automatically a loss claim if OPQ buffering covers the finite
backlog and the run drains.  Under the scoped contract, the decisive conditions
are zero OPQ drops, full conservation, and a finite measured drain envelope.

The latest scoped lossless run measured:

```text
E[A_n] = 2048.000 cycles
E[S_n] = 3534.317 cycles
rho    = 3534.317 / 2048.000 = 1.726
W_min  = 2727.5 cycles
W_max  = 91906.5 cycles
```

This is a finite-burst queue-drain result.  It is not a claim that the same
traffic is stable for an infinite run.

## Excluded 1024-Depth Diagnostic Profile

The earlier diagnostic run measured:

```text
E[A_n] = 2047.885 cycles
p50(A_n) = 2048 cycles
min(A_n) = 1988 cycles
max(A_n) = 2108 cycles

E[S_n] = 3547.705 cycles
p50(S_n) = 4352.5 cycles
min(S_n) = 2701.5 cycles
max(S_n) = 4366.5 cycles
```

Therefore:

```text
rho = E[S_n] / E[A_n]
    = 3547.705 / 2047.885
    = 1.732.
```

The measured wait recurrence had zero residual:

```text
W_n = W_(n-1) + S_n - A_n
max abs residual = 0 cycles.
```

The observed wait range was:

```text
2727.5 <= W_n <= 94216.5 cycles.
```

A finite envelope from measured extrema over `N` intervals is:

```text
W_0 + N*(S_min - A_max) <= W_N <= W_0 + N*(S_max - A_min).
```

Using `W_0 = 2727.5` and `N = 61`:

```text
38931.0 <= W_61 <= 147816.0 cycles.
```

This diagnostic profile is overloaded at the OPQ frame-service level and is
not the scoped no-bottleneck contract.  Its value is to prove the queue model
and expose the drop boundary.

## First-Loss Interpretation

Under the maintained no-bottleneck contract there must be no first lost frame,
sample, or hit.  The first-loss boundary is therefore a failure signature, not
an allowed result.

In the excluded diagnostic profile, first loss occurred at:

```text
frame_seq = 43
frame_id  = 43
W_43      = 67478 cycles.
```

The pre-loss clean maximum was:

```text
max clean W before first loss = 65160 cycles.
```

Those numbers should be retained only as diagnostic calibration of the
under-provisioned profile.  They must not be used to waive drops in the scoped
lossless run.

## Grouped 384-Hit Loss

The excluded diagnostic profile lost:

```text
384 hits = 12 complete samples * 32 channels/sample.
```

The missing sample indices were:

```text
72, 73, 78, 80, 83, 84, 88, 89, 90, 95, 96, 98
```

Each missing sample is a complete ASIC0 channel vector, not a partial-channel
loss.  This grouping is consistent with frame/subheader-level controlled
credit loss in the diagnostic profile.

Under the scoped no-bottleneck contract:

```text
missing OPQ samples = 0
missing OPQ hits    = 0
missing DMA hits    = 0
```

Any nonzero OPQ controlled drop counter is a contract failure even if the
missing-hit count is explained by that counter.  A controlled counter can
explain the failure mode; it cannot make the run pass under this scope.

## DMA Conservation and Limits

DMA has no independent hard latency bound derivable from the source schedule,
frame format, and OPQ frame recurrence alone.  Its bounded-latency threshold is
a measured property of the provisioned OPQ plus DMA packing path.

The conservation checks are hard:

```text
DMA ghost hits                  = 0
DMA duplicate hits              = 0
DMA hits                        = OPQ egress accepted hits
DMA hit identity                = OPQ hit identity
```

For the scoped no-bottleneck run:

```text
OPQ ingress hits = 3200
OPQ egress hits  = 3200
DMA hits         = 3200
```

If OPQ is accepted as the upstream reference, then every DMA miss with matching
OPQ egress evidence is a DMA conservation failure.  If OPQ itself reports any
drop, the run fails first at the OPQ contract boundary.

## Scoreboard Threshold Summary

Recommended maintained thresholds for this corun:

```text
source_generation_hits       = 3200
pre_rbcam_hits               = 3200
post_rbcam_hits              = 3200
feb_egress_hits              = 3200
opq_ingress_hits             = 3200
opq_egress_hits              = 3200
dma_hits                     = 3200

pre_rbcam_lifetime_cycles    = 0 exactly
post_rbcam_lifetime_cycles   = 0 exactly
feb_egress_lifetime_cycles   in [2049, 6143]
opq_ingress_lifetime_cycles  in [2049, 6159]
opq_queue_residual_cycles    = 0 when using the busy recurrence
opq_drop_counters            = 0 exactly
dma_ghost_hits               = 0
dma_duplicate_hits           = 0
dma_missing_hits             = 0
```

Classification:

```text
Hard:
  source count, hit identity, lane mask, synthetic pre/post-rbCAM zero delay,
  OPQ drop counters equal zero, DMA conservation.

Profile-specific:
  source timestamp sequence, frame/bucket mapping, two-frame FEB egress
  [2049,6143], direct OPQ ingress [2049,6159].

Measured-envelope:
  OPQ egress hit lifetime and DMA lifetime after OPQ is provisioned lossless:
  latest OPQ egress [5596.75,95154.75] and DMA [5601.75,95158.25].
  These bounds must be regenerated from a zero-drop, fully conserved run.

Excluded diagnostic:
  1024-depth OPQ overload with rho=1.732, first loss at frame 43, and grouped
  384-hit controlled loss.
```
