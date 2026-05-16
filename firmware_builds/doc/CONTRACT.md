# CONTRACT.md - Phase-5 AVST, Mu3e data-frame, and error-sideband contract

Date: 2026-05-16

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

## Mu3e Data Frame on 36-bit Upload Streams

Streams: FEB `hit_type3`, `upload_data`, `upload_data0_sc_rc`,
`upload_data1`, SWB FEB RX data path, and OPQ ingress after data/SC/RC
demultiplexing.

Each accepted beat carries `data[31:0]` and `datak[3:0]`. A K-symbol in byte 0
uses `datak[0]=1`; normal hit words use `datak=0`.

### Frame Layout

The checked Mu3e data frame is:

| Beat | Name | Required contents | Checker status |
| --- | --- | --- | --- |
| 0 | SOP / preamble | `sop=1`, `datak[0]=1`, `data[7:0]=K28.5=0xbc`; `data[31:26]` carries FEB type and `data[23:8]` carries FEB ID | enforced for SOP and K28.5 |
| 1 | Header timestamp high | `datak=0`, `data[31:0]=frame_ts[47:16]` | captured for timestamp reconstruction |
| 2 | Header timestamp low and packet count | `datak=0`, `data[31:16]=frame_ts[15:0]` with the subheader-window bits masked to zero; `data[15:0]=packet_count` | packet count is enforced across frames |
| 3 | Declared counts | `datak=0`, `data[31]=0`, `data[30:16]=declared_subheaders`, `data[15:0]=declared_hits` | enforced |
| 4 | Debug time / TTL | `datak=0`, generation timestamp / frame lifetime reference | captured as debug context |
| 5..N | Subheaders and hit payloads | exactly `declared_subheaders` subheaders, each followed by its declared number of hit beats | enforced |
| Last | Trailer | `eop=1`, `datak[0]=1`, `data[7:0]=K28.4=0x9c` | enforced |

The v3 FEB data-frame contract uses 128 subheaders per frame. A legal frame
therefore accepts exactly:

```text
5 header words + 128 subheaders + 1 trailer + declared_hit_beats
```

Equivalently, the checker uses:

```text
expected_accepted_words = 5 + declared_subheaders + declared_hits + 1
```

The current FEB v3 upload SOP observed in integration simulation is
`0xA50000BC` (`data[31:26]=6'b101001`). The SWB data/SC/RC demerger must route
this preamble to the detector-data path, not to SC or RC. Legacy SWB data
preambles with `data[31:29]` equal to `111` or `110` remain valid detector-data
preambles.

### Subheader Contract

Each subheader is a K23.7 word:

```text
datak[0] = 1
data[7:0] = K23.7 = 0xf7
data[15:8] = declared hit beats for this subheader
data[23:16] = reserved / TBD
data[31:24] = subheader timestamp, frame-local ts[11:4]
```

The first subheader defines the frame page base. With 128-subheader frames the
legal page bases are `0x00` and `0x80`; the next frame must advance by 128
modulo 256. Inside a frame, subheader timestamps must be monotonic and
consecutive. Duplicate, backward, and gap sequences are broken-packet errors.

Every subheader must transmit exactly the number of accepted hit beats declared
in `data[15:8]` before the next subheader or trailer. A missing hit beat,
extra hit beat, or mismatch between the sum of subheader hit counts and the
frame header `declared_hits` is a broken-packet error.

### Hit Contract

A hit beat has `datak=0` and carries the 32-bit MuTRiG hit payload. The checker
uses `data[31:28]` as the hit timestamp nibble and reconstructs the full packet
timestamp as:

```text
packet_ts = {
  header_timestamp_high_word[31:0],
  header_timestamp_low_word[31:28],
  subheader_timestamp[7:0],
  hit_word[31:28]
}
```

Within one frame, reconstructed hit timestamps must not decrease.

For SciFi/Tile hit words the offline rate-study decoder also interprets the
spec fields used by the 256-channel histogram namespace:

```text
data[27:22] = ASIC / chip id
data[21:16] = local channel id
global_channel = ASIC * 32 + local_channel
```

The FEB rate debug closure uses one randomly selected local channel per ASIC.
For exact periodic offline injection at the 125 MHz timestamp clock, the
required inter-event intervals are:

| Per-channel rate | Expected timestamp interval |
| --- | ---: |
| 10 kHz | 12,500 ticks |
| 100 kHz | 1,250 ticks |
| 500 kHz | 250 ticks |
| 1 MHz | 125 ticks |

The offline checker decodes each hit timestamp from the raw Mu3e frame words
and fails if any active channel has a decoded inter-event interval different
from the injected interval. A longer interval is treated as evidence for a lost
or nonconsecutive frame unless a higher-level drop policy explicitly explains
the gap.

### Enforced Checker Gates

The SystemVerilog `mu3e_frame_checker` and the offline STP decoder enforce the
same packet vocabulary:

- `sop` must coincide with K28.5 and `eop` must coincide with K28.4.
- Data outside a frame is an error unless it is an accepted idle comma.
- The declared subheader count must be 128 for v3 FEB data frames.
- The number of seen subheaders must equal the frame header declaration.
- Subheaders must be consecutive within the frame page.
- Per-subheader accepted hit beats must equal the subheader declaration.
- Total accepted hit beats must equal the frame header declaration.
- The sum of subheader-declared hits must equal the frame header declaration.
- Total accepted frame words must equal `5 + declared_subheaders +
  declared_hits + 1`.
- Consecutive frames on the same stream must increment `packet_count` modulo
  16 bits.
- Consecutive frames on the same stream must advance the first-subheader page
  base by 128 modulo 256.
- Consecutive frames on the same stream must not move the header-derived
  frame-start timestamp backward. The checked value is reconstructed as
  `{header_timestamp_high_word, header_timestamp_low_word[31:28],
  first_subheader_timestamp, 4'b0}`. Exact 2048-tick frame-window cadence is
  enforced by the subheader page-base rule above; exact per-channel injection
  interval is enforced by the offline timestamp-rate study.

The FEB integration monitor can additionally require a minimum number of
completed upload frames and hits with:

```text
+TB_INT_REQUIRE_FEB_UPLOAD_FRAMES
+TB_INT_MIN_FEB_UPLOAD_FRAMES=<n>
+TB_INT_MIN_FEB_UPLOAD_HITS=<n>
```

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

## Run-Control Broadcast and Stage Gaps

The Phase-5 run-control command path is a forward readyless broadcast. A slave
must not rely on Avalon-ST `ready` to backpressure `RUN_PREPARE`, `SYNC`,
`RUNNING`, `TERMINATING`, or `IDLE`; legacy local ready surfaces are diagnostic
observations only until a future packet-based acknowledgement path exists.

The deployed FEB sequence is driven by C++ software and uses software-scale
state spacing. Integration simulation that claims post-rbCAM or FEB-egress
latency closure must therefore observe at least 125000 125 MHz cycles, i.e.
1 ms, for each of these state gaps:

- `RUN_PREPARE` to `SYNC`
- `SYNC` to `RUNNING`
- `TERMINATING` to `IDLE`

Focused pre-rbCAM source checks may use shorter gaps only when they do not
claim downstream rbCAM/FEB closure. Runs with sub-1 ms gaps are invalid
evidence for rbCAM rejection, post-rbCAM latency, or FEB-egress latency because
rbCAM internal flush can still be in progress while the forward command state
has already advanced.

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
