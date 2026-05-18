# FEB to SWB Corun UVM Skeleton

This subtree is a self-contained UVM layer for the FEB-to-SWB corun special
case. It is intentionally separate from the existing `feb_swb_corun/Makefile`
and `sv/` adapter sources so the full DUT hookup can be promoted later without
changing the first adapter smoke path.

## Scope

- lanes 0 and 1 active, lanes 2 and 3 masked with active mask `4'h3`
- single virtual MuTRiG source: ASIC 0, channel 0, 100 kHz
- FEB side observed at the parallel hit_type3 egress / adapter ingress
- SWB side observed at OPQ ingress-style beats and DMA hit-word output
- debug lineage key: `ps_tag`, `ts_tag`, and `hit_id`

The base test models the required configure/run-control ordering: FEB emulator
debug enables and SWB CSR lane-mask/DMA/OPQ configuration must be accepted
before both systems are released from a synchronized run-control epoch.

## Files

- `feb_swb_corun_if.sv`: generic monitor interfaces for FEB beats, OPQ beats,
  and 256-bit DMA words.
- `feb_swb_corun_uvm_pkg.sv`: transactions, monitors, config object,
  scoreboard, environment, and base test.
- `tb_top.sv`: skeleton top with clocks/resets and optional synthetic smoke
  traffic.
- `Makefile`: local compile/smoke target for the skeleton only.

## Local Check

```sh
make compile
make smoke
```

`make smoke` uses `+FEB_SWB_SELF_SMOKE` to inject two debug-keyed lane0/1
observations through the FEB, OPQ, and DMA monitor interfaces. Full DUT
integration should replace that injection with bindings to the FEB adapter
egress and the SWB OPQ/DMA trace taps.
