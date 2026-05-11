# Histogram Snoop Selector

`histogram_snoop_selector` is a nonblocking observation mux in front of
`histogram_statistics`.

It accepts:

| Input | Format | Purpose |
|---|---|---|
| `hp_in` | 39-bit `hit_type1` | Hit-processor/MTS output before rbCAM. |
| `rb_in` | 36-bit raw rbCAM Type-2 words | rbCAM egress with channel/error/empty sidebands accepted and ignored. |

Both input `ready` signals are tied high. The selector never backpressures the
observed datapaths; if the histogram sink is not ready, the selected sample is
dropped and counted.

`CONTROL[0]` selects `0=hp_in` or `1=rb_in` at run time. `CONTROL[1]` enables
rbCAM hit-word filtering and repacking, using K23.7 subheaders to recover
`ts[11:4]` and map rbCAM hit words into the normal 39-bit histogram layout.
