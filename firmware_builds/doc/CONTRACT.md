# CONTRACT.md - Phase-5 AVST and error-sideband contract

Date: 2026-04-27

This document records the live FEB SciFi Phase-5 stream contract. The key rule
is: upstream IP asserts error sidebands when it detects bad data; downstream IP
or an explicit trim point decides whether to drop the marked beat.

## Global AVST Rules

- `valid` owns `data`, `channel`, `startofpacket`, `endofpacket`, `empty`, and
  `error`.
- While `valid=1` and `ready=0`, all payload and sideband signals must remain
  stable.
- A beat is accepted only on `valid=1 && ready=1`.
- Error sidebands are diagnostic and policy-bearing. They must not be silently
  cleared to make rate counters look good.
- A stream tap may count or histogram error-marked data, but any loss of the
  error sideband at that tap must be documented.

## `mutrig_frame_deassembly_N` to `mts_preprocessor_{0,1}`

Stream: `hit_type0_in`, 45-bit payload.

Error meaning:

- `hiterr`: bad MuTRiG hit payload from frame assembly/deassembly.
- `crcerr` and `frame_corrupt` are frame/link integrity observations at the
  deassembly boundary.

MTS policy:

- `CONTROL_STATUS[4] discard_hiterr=1` rejects `hit_type0` beats carrying the
  configured input hit-error bit.
- This is an ingress-quality filter for malformed raw hits, not the
  timestamp-delay policy.

## `mts_preprocessor_{0,1}` to Hit Stack

Stream: `hit_type1_out`, 39-bit payload.

Payload fields:

```text
ASIC[38:35], channel[34:30], TCC_8n[29:17], TCC_1n6[16:14],
TFine[13:9], ET_1n6[8:0]
```

Error meaning:

- `error[0] = tserr`: corrected hit timestamp has a delay outside the accepted
  MTS expected-latency window. This usually means PLL unlock, CML receive noise,
  or a timestamp interpretation/configuration issue.

MTS policy:

- Default: assert `tserr` and forward the hit.
- `CONTROL_STATUS[5] drop_delay_error=1`: locally trim `hit_type1` payload
  beats whose `tserr` is asserted. Leave this clear for normal debug and for
  histogram-before-ring rate monitoring.

## `histogram_ingress_bridge_0`

In the active Phase-5 Qsys:

- `mts_preprocessor_0.hit_type1_out -> histogram_ingress_bridge_0.pre_in`
- `histogram_ingress_bridge_0.pre_out -> hit_stack_subsystem_0.hit_type_1`
- `histogram_ingress_bridge_0.hist_out -> histogram_statistics_0`
- `mts_preprocessor_1.hit_type1_out -> hit_stack_subsystem_1.hit_type_1`

Pre path:

- `pre_in -> pre_out` forwards the 39-bit payload and the `tserr` error
  sideband.
- `hist_out` is a histogram tap and has no error sideband. It can therefore
  count rate for error-marked pre-hit-stack data as long as MTS forwards those
  beats.

Post path:

- `post_in` is a 36-bit post-hit-stack stream.
- With `FILTER_POST_HIT_WORDS=1`, only real post-hit-stack hit words after a
  K23.7 subheader assert `hist_out.valid`; frame protocol words are drained
  locally.

## `ring_buffer_cam`

Stream in: `hit_type1`, with `error[0] = tserr`.

Policy:

- `CTRL[4] filter_inerr` filters ingress hits whose `tserr` is asserted.
- The default is on.
- `INERR_COUNT` counts filtered timestamp-error ingress hits.
- This is the normal downstream trim point for bad MTS timestamps.

Stream out: `hit_type2`, with `error[0] = tsglitcherr`.

Error meaning:

- `tsglitcherr`: the side-RAM timestamp phase does not match the current header
  timestamp phase. This commonly follows unfiltered bad `tserr` traffic.

## Phase-5 Operating Policies

Rate/channel alive-dead:

- Keep MTS `drop_delay_error=0`.
- Let the histogram tap count offered pre-ring rate.
- Choose ring `filter_inerr` based on whether downstream hit-stack corruption
  or raw throughput observation is more important for that run.

PLL-lock and latency:

- Keep MTS `drop_delay_error=0`.
- Keep ring `filter_inerr=1` for normal protection.
- Treat nonzero MTS `tserr`, broad delay PDFs, and rising ring `INERR_COUNT` as
  evidence to debug MuTRiG lock/configuration, not as data to hide.
