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

- Lane 0 carries ASIC0..7 channels `0..31` at 100 kHz/channel.
- Lane 1 emits legal empty FEB frames.
- Lanes 2 and 3 are masked and must not contribute accepted hits.
- Three source modes are maintained:
  - periodic phase-staggered full32 bursts per ASIC
  - independent Poisson streams per ASIC/channel with seed-controlled replay
  - deterministic header-sync full32 bursts per ASIC, phase 100 on the
    910-cycle virtual MuTRiG short-frame grid
- The direct corun pre-rbCAM and post-rbCAM checkpoints are synthetic lineage
  markers.  They are not the true rbCAM instance from the full FEB integration
  path.

## Notation

Let `m` index a source sample, `a` index the ASIC, and `c` index the channel
inside the ASIC:

```text
a = 0..7
c = 0..31
```

The per-channel hit period is

```text
P_hit = 10 us = 1250 cycles.
```

For the periodic phase-staggered source, the nominal ASIC phase is

```text
Delta_asic = P_hit / 8 = 156.25 cycles.
```

The implemented integer source ledger carries the exact hit time and hit id.
For documentation, the nominal generation time and identity are:

```text
t(m,a)       ~= P_hit*m + Delta_asic*a
hit_id(m,a,c) = 256*m + 32*a + c
```

For the Poisson iid source, each `(a,c)` has an independent exponential
interarrival process with mean `P_hit`; the source ledger assigns the actual
generation time and the DEBUG hit id used by the trace checker.

For the header-sync source, one pulse is generated for every virtual MuTRiG
short frame.  The direct two-lane FEB stream staggers ASIC phases by 16 cycles
so no 16-cycle FEB subheader bucket contains every active ASIC assigned to the
same lane at once:

```text
I_short = 910 cycles
phi_header = 100 cycles
S_asic = 16 cycles
t(k,a) = I_short*k + phi_header + S_asic*a
hit_id(k,a,c) = DEBUG/source-ledger identity
```

For any ledger hit `h`, the frame, phase, subheader bucket, and bucket residue
are:

```text
f_h = floor(t_h / F)
p_h = t_h - F*f_h
b_h = floor(p_h / H)
r_h = p_h - H*b_h.
```

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
DEBUG.hit_id            = source-ledger hit id.
```

The local time at which the testbench writes a source trace row is not the
definition of lifetime.  It is only an observation.  If a plot changes shape
when the local source marker is moved but the carried hit timestamp is
unchanged, the lifetime definition is wrong.

For a window of length `t`, the all-ASIC periodic phase-staggered arrival
curve used in the plot subtitle is bounded by:

```text
alpha_periodic(t) = 32 * (floor(t / Delta_asic) + 1)
                  ~= 32 * (floor(t / 156.25) + 1).
```

A looser affine envelope useful for rate-latency algebra is:

```text
alpha_hit(t) <= sigma + rho*t
sigma = 32 hits
rho   = 8*32 / 1250 = 0.2048 hits/cycle.
```

For the Poisson iid source, the expected aggregate arrival count is:

```text
N_chan          = 8*32 = 256
lambda_total    = N_chan / P_hit = 256/1250 = 0.2048 hits/cycle
E[alpha_iid(t)] = lambda_total * t = 256*t/1250 hits.
```

The Poisson equation is an expectation, not a hard deterministic bound. The
hard check for Poisson mode is ledger conservation from generation through DMA.

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

The number of periodic source samples per ASIC/channel is

```text
N_sample = T_run / P_hit = 125000 / 1250 = 100.
```

The total periodic offered hit count on lane 0 is

```text
N_hit = N_sample * 8 ASICs * 32 channels = 25600.
```

For the accepted Poisson replay:

```text
seed              = 20260508
E[N_hit]          = 25600
realized N_hit    = 25629
realized DMA words = sum_frame ceil(frame_hits / 4) = 6431.
```

For the accepted header-sync replay:

```text
I_short                    = 910 cycles
phase                      = 100 cycles
burst_count                = 1
ASIC phase stagger         = 16 cycles
realized source hit count  = 35328
realized DMA words         = 8832
```

The number of emitted frame periods is

```text
N_frame = ceil(T_run / F) = ceil(125000 / 2048) = 62.
```

The periodic lane-0 frames `0..60` are nonempty and frame `61` is an empty
terminal frame. Across the nonempty periodic lane-0 frames:

```text
frame hit counts vary with ASIC phase staggering
total = 25600 hits.
```

Lane 1 emits 62 legal empty frames.  In the lane-0 OPQ queue model there are
62 paired input/output frame SOPs.  In a two-lane ingress count, the frame
traffic contains 124 FEB frame packets, of which lane 1 is empty by contract.

## Source and Bucket Checks

The source-side scoreboard has hard, profile-specific checks:

```text
periodic source hit count       = 25600
periodic per-channel hit count  = 100
periodic hit_id sequence        = 0..25599
source asic                     = floor((hit_id mod 256) / 32)
source channel                  = hit_id mod 32
source frame                    = floor(source time / 2048)
source bucket                   = floor((source time mod 2048) / 16)
Poisson source hit count        = source ledger row count
Poisson hit identity            = DEBUG/source-ledger identity
header-sync phase              = (100 + 16*asic) mod 910
header-sync hit identity       = DEBUG/source-ledger identity
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

The direct FEB/SWB corun does not instantiate the true rbCAM.  Its local
pre/post CSV rows are lineage identity markers used to prove hit conservation
before the FEB frame writer.  The plotted pre-rbCAM lifetime must therefore use
the virtual MuTRiG source model, not the clean full-FEB 17-cycle local transport
marker that begins after MuTRiG frame generation/deassembly has already
occurred.

```text
virtual MuTRiG short-frame period:
  I = 910 cycles

short-frame serializer slot offset:
  s(q) = 9 + 7*floor(q/2) + 3*(q mod 2)

frame marker:
  M_h = first short-frame marker at or after hit timestamp t_h

pre-rbCAM virtual MuTRiG reference:
  D_pre(h) = M_h - t_h + s(q_h) + L_pre + eps_clk
  L_pre = 18 cycles from the phase-100 virtual-MuTRiG calibration
  validation aperture = [0, 2000] cycles, expected no-drop 100 kHz max < 1100
```

For deterministic 100 kHz/channel traffic each MuTRiG ASIC sees 32 hits every
1250 cycles:

```text
rho_link = (32/1250) / (1/3.5) = 0.0896.
```

No persistent queue can build before pre-rbCAM.  The expected shape is a
one-frame comb/box convolved with the 32-hit serializer tail, not a delta at
17 cycles.  For the current all-ASIC phase-staggered ledger the regenerated
periodic panel reports:

```text
pre-rbCAM virtual MuTRiG model:
  count = 25600
  min/p05/p50/p95/max = 27 / 125 / 536 / 946 / 1044 cycles
```

For Poisson iid 100 kHz/channel:

```text
N_frame ~ Poisson(32*910/1250), E[N_frame] = 23.296 hits.
P(N_frame > 256) is negligible for this seed and must still be checked by
the realized source ledger.
```

The accepted Poisson seed `20260508` reports:

```text
pre-rbCAM virtual MuTRiG model:
  count = 25629
  min/p05/p50/p95/max = 67 / 148 / 524 / 892 / 938 cycles
```

The accepted header-sync phase-100, burst-1, stagger-16 replay reports:

```text
pre-rbCAM virtual MuTRiG model:
  count = 35328
  min/p05/p50/p95/max = 725 / 753 / 835 / 917 / 945 cycles
```

The post-rbCAM panel still imports the clean full-FEB rbCAM DEBUG-age reference:

```text

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

The current accepted post-rbCAM reference summary is:

```text
post-rbCAM:
  count = 3136
  min/p50/p95/max = 2001 / 2070 / 2128 / 2139 cycles
  in [2000,2200) = 3136 hits
```

The post-rbCAM DEBUG age is measured after the DEBUG-matched rbCAM ingress
point against the carried hit timestamp modulo the 8192-cycle rbCAM epoch, so it
must concentrate inside the programmed `[2000,2200)` acceptance aperture.

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
source hit is born at `t_h`, but the FEB stream for frame `f_h` begins after
two 2048-cycle frame periods:

```text
T_feb_sop(h) = F*f_h + 2*F.
```

With five frame header words, all 128 subheaders emitted, and all hits in the
same frame serialized in bucket order, the logical hit word offset from the
frame SOP is

```text
O(h) = 5 + b_h + 1 + earlier_hits_in_frame_before_h.
```

The testbench drives one FEB word every two 125 MHz clock edges, so the
observed hit-word offset is approximately `2*O(h)` plus the simulator
sampling phase.  The store-forward hit lifetime is therefore modeled as

```text
D_feb(h) ~= 2*F - p_h + 2*O(h) + epsilon_clk.
```

The latest periodic all-ASIC, DEBUG_LEVEL=2 corun measured:

```text
3099.5 <= T_feb_egress(h) - t_h <= 4172.5 cycles.
```

The accepted Poisson all-ASIC replay measured:

```text
3081.5 <= T_feb_egress(h) - t_h <= 4118.5 cycles.
```

The accepted header-sync all-ASIC replay measured:

```text
3140.5 <= T_feb_egress(h) - t_h <= 4460.5 cycles.
```

The maintained hard validation range keeps frame-start and word-offset margin:

```text
2049 <= T_feb_egress(h) - t_h <= 6143 cycles.
```

This is profile-specific to `N_SHD=128`, two-frame dispatch, all-subheader
emission, and the all-ASIC source ledger used by the corun.

## OPQ Ingress Adapter

The parallel 125 MHz FEB to 250 MHz SWB ingress adapter is finite and
source-synchronous in this corun.  It follows the FEB egress hit by a small
clock-domain adapter delay.  The latest runs measured:

```text
periodic:
  3100.75 <= T_opq_ingress(h) - t_h <= 4173.75 cycles
Poisson:
  3082.75 <= T_opq_ingress(h) - t_h <= 4119.75 cycles
header-sync:
  3141.75 <= T_opq_ingress(h) - t_h <= 4461.75 cycles
T_opq_ingress(h) - T_feb_egress(h) = 1.25 cycles.
```

The maintained source-lifetime range is:

```text
2049 <= T_opq_ingress(h) - t_h <= 6159 cycles.
```

The scoreboard must require:

```text
OPQ ingress hit count  = source ledger hit count
OPQ ingress identity   = source identity exactly
OPQ ingress frame      = f_h
OPQ ingress bucket     = b_h
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
OPQ ingress hit count             = source ledger hit count
OPQ egress hit count              = source ledger hit count
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
D_opq_hit(h) = T_opq_egress(h) - t_h
D_opq_min <= D_opq_hit(h) <= D_opq_max.
```

The measured values `D_opq_min` and `D_opq_max` must come from a run with zero
OPQ drop counters and full hit conservation.  In the latest scoped periodic
run:

```text
OPQ ingress hits        = 25600
OPQ egress hits         = 25600
OPQ drop counter total  = 0
OPQ recurrence residual = 0 cycles
5019.75 <= D_opq_hit <= 96286.75 cycles.
```

In the latest scoped Poisson run:

```text
OPQ ingress hits        = 25629
OPQ egress hits         = 25629
OPQ drop counter total  = 0
OPQ recurrence residual = 0 cycles
5108.25 <= D_opq_hit <= 102014.25 cycles.
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

The latest scoped periodic lossless run measured:

```text
E[A_n] = 2048.000 cycles
E[S_n] = 3540.050 cycles
rho    = 3540.050 / 2048.000 = 1.729
W_min  = 2733.5 cycles
W_max  = 92256.5 cycles
```

The latest scoped Poisson lossless run measured:

```text
E[A_n] = 2048.000 cycles
E[S_n] = 3607.639 cycles
rho    = 3607.639 / 2048.000 = 1.762
W_min  = 2789.5 cycles
W_max  = 97927.5 cycles
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

## Poisson Rate-Scan Lossless-Drain Model

The all-ASIC iid Poisson rate scan now drives both FEB/SWB hit lanes:

```text
lane 0: ASIC4..7, channels 0..31
lane 1: ASIC0..3, channels 0..31
lanes 2/3: masked
```

`N_HIT` is a subheader/subframe format limit, not a global frame admission
limit.  With two active hit lanes, the semantic subheader knee is:

```text
N_ch   = 8 * 32 = 256 channels
L      = 2 active hit lanes
H      = 16 cycles/subheader
T_c    = 8 ns/cycle
N_HIT  = 2047 hits/subheader/lane

R_sub,knee = L * N_HIT / (N_ch * H * T_c)
           = 2 * 2047 / (256 * 16 * 8 ns)
           = 124.94 MHz/channel.
```

That limit is far outside the 50 kHz/channel to 1 MHz/channel scan.  Under the
current finite-burst contract, OPQ buffering plus post-window drain should
therefore conserve all generated hits unless a separate queue, frame-table, or
DMA readout bug appears.

The expected lossless delivery equation is:

```text
T_run = 125000 cycles = 1 ms
R     = per-channel hit rate
A     = generated hits in the 1 ms source window

E[A]        = N_ch * R * T_run * T_c
E[delivered]= E[A]
E[missing]  = 0
```

The useful service marker is the zero-backlog knee for the two-lane frame
cadence, not a hard delivered-rate cap when the run is allowed to drain:

```text
F             = 2048 cycles/frame
C_lane        = 2047 hits/frame/lane
R_backlog     = L * C_lane / (N_ch * F * T_c)
              = 2 * 2047 / (256 * 2048 * 8 ns)
              = 976.09 kHz/channel.
```

Above `R_backlog`, backlog can grow during the 1 ms injection interval, but
it should still drain without loss if the OPQ/SWB queues are deep enough and
the frame-retirement sequence remains live.

Latest corrected RTL scan, seed `20260508`, 1 ms source window:

```text
rate kHz/ch  expected  DMA hits  missing  delivered Mhit/s  missing %
50.000       12795     12795     0        12.795            0.0000
100.000      25629     25629     0        25.629            0.0000
200.000      51250     51250     0        51.250            0.0000
400.641      102528    102528    0        102.528           0.0000
500.000      128120    128120    0        128.120           0.0000
651.042      166780    165609    1171     165.609           0.7021
801.282      205379    199194    6185     199.194           3.0115
899.281      230049    227951    2098     227.951           0.9120
946.970      242332    241035    1297     241.035           0.5352
976.562      249896    236879    13017    236.879           5.2090
1000.000     255856    255338    518      255.338           0.2025
```

The 1 MHz/channel point is now near full rate and contradicts the old
one-lane frame-cap model.  Both active lanes accept and read all hits, and
controlled OPQ drop counters remain zero:

```text
1 MHz/channel observed:
  lane0_wr_hit        = 127567
  lane0_rd_hit        = 127567
  lane1_wr_hit        = 128289
  lane1_rd_hit        = 128289
  lane0_handle_drop   = 0
  lane1_handle_drop   = 0
  ft_drop_hit         = 0
  DMA hits            = 255338 / 255856
```

The remaining high-rate shortfall is not explained by OPQ controlled drops.
At 976.562 kHz/channel, a focused rerun with `DRAIN_SWB_CYCLES=2000000`
reproduced the same `13017` missing hits.  The OPQ lane counters consumed all
lane hits, but the frame-table read side reported `ft_wr_shd=7813` and
`ft_rd_shd=7428`, a gap of `385` subheaders, approximately three 128-subheader
frames.  This is tracked as an open frame-retirement/readout issue rather than
as a mathematical OPQ admission limit.

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

For the scoped no-bottleneck runs:

```text
periodic:
  OPQ ingress hits = 25600
  OPQ egress hits  = 25600
  DMA hits         = 25600

Poisson seed 20260508:
  OPQ ingress hits = 25629
  OPQ egress hits  = 25629
  DMA hits         = 25629
```

If OPQ is accepted as the upstream reference, then every DMA miss with matching
OPQ egress evidence is a DMA conservation failure.  If OPQ itself reports any
drop, the run fails first at the OPQ contract boundary.

## Scoreboard Threshold Summary

Recommended maintained thresholds for this corun:

```text
periodic source_generation_hits = 25600
Poisson source_generation_hits  = source ledger row count
pre_rbcam_hits                  = source_generation_hits
post_rbcam_hits                 = source_generation_hits
feb_egress_hits                 = source_generation_hits
opq_ingress_hits                = source_generation_hits
opq_egress_hits                 = source_generation_hits
dma_hits                        = source_generation_hits

synthetic pre/post CSV delay = 0 exactly in the direct corun
plotted pre_rbcam_lifetime_cycles = virtual MuTRiG model, max < 1100 for the maintained 100 kHz runs
post_rbcam_lifetime_cycles   in [2000, 2200)
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
  periodic OPQ egress [5019.75,96286.75] and DMA [5024.75,96290.25].
  Poisson OPQ egress [5108.25,102014.25] and DMA [5112.75,102019.75].
  These bounds must be regenerated from a zero-drop, fully conserved run.

Excluded diagnostic:
  1024-depth OPQ overload with rho=1.732, first loss at frame 43, and grouped
  384-hit controlled loss.
```
