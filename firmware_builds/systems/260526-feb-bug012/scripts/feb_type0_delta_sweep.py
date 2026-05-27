#!/usr/bin/env python3
"""Single-channel PERIODIC delta sweep with verified-config + retry.

Goal
----
Confirm each enabled channel produces a DELTA in the histogram at the
expected bin with the expected rate. Per-channel periodic injection:

  SIGNAL(0x08) = 0x02      bit0=hit_mode_sig=0 (internal),
                            bit1=internal_sub_mode=1 (periodic),
                            bit2=cluster_geom_mode=0 (FIXED -> single channel)
  CLUSTER_FIX(0x0C) = (1<<14) | (N<<7) | N
                            left_enable, left_high=N, left_low=N
  RATES(0x0B) hit_rate=42  periodic rate = clk*hit_rate/65536
                            = 156.25e6*42/65536 ~= 100.1 kHz
  BACKGROUND(0x09)=0, CENTRAL(0x07)=1.

RTL chain (confirmed in emulator_mutrig.sv / frontend_trigger_engine.sv):
  left_enable=1 -> cfg_hit_channel_low = {1'b0, geom_fix_left_low} = N
  FIXED -> cluster0=[N,N] (GLOBAL channel index 0..255)
  shred: lane = N>>5, local CH = N - lane*32
  histogram key = data[43:36] = ASIC<<5 | CH = N  -> bin N (LEFT=0,BINW=1).
Only ASIC0 (lane0, N=0..31) is reachable until merger_hit_type0 is wired,
so the meaningful sweep is N in 0..31.

The earlier on-board failure (CH10->bin7, CH20->empty) is a config-LANDING
issue, not RTL: a dropped CLUSTER_FIX write leaves the emulator at its reset
default [0,3]; a stale histogram LEFT_BOUND shifts bin = key-LEFT. This tool
defeats both by reading back EVERY config write and retrying until it lands.

Reuses the robust run/freeze/burst-read machinery from feb_hist_read.py.
"""
import argparse
import sys
import time

import feb_hist_read as fh

EMU, RUNCTL = fh.EMU, fh.RUNCTL
HIST_CSR, HIST_BIN = fh.HIST_CSR, fh.HIST_BIN
E_SIGNAL, E_BACKGROUND, E_RATES, E_CENTRAL = (
    fh.E_SIGNAL, fh.E_BACKGROUND, fh.E_RATES, fh.E_CENTRAL)
E_TIMEBASE, E_LANE_EN = fh.E_TIMEBASE, fh.E_LANE_EN
H_LEFT, H_RIGHT, H_BINW, H_CONTROL, H_TOTAL, H_LASTINT = (
    fh.H_LEFT, fh.H_RIGHT, fh.H_BINW, fh.H_CONTROL, fh.H_TOTAL, fh.H_LASTINT)

E_CLUSTER_FIX = 0x0C
INTERVAL_S = 1.0          # DEF_INTERVAL_CLOCKS = 125e6 @125MHz


def wr_verify(link, addr, val, mask=0xFFFFFFFF, tries=5, label=""):
    """Write then read-back; retry until (readback & mask)==(val & mask).
    Defeats SC-ring CDC command drops. Returns (ok, last_readback)."""
    want = val & mask
    last = None
    for _ in range(tries):
        fh.wr(link, addr, val)
        time.sleep(0.02)
        last = fh.rd(link, addr)
        if last is not None and (last & mask) == want:
            return True, last
    print(f"#   ! verify FAIL {label} @ {addr:#x}: wrote {val:#x} "
          f"readback {last!r} (mask {mask:#x})")
    return False, last


E_MUTRIG_FMT = 0x0A


def configure_periodic_channel(link, n, hit_rate):
    """Fire exactly one (ASIC, CH) periodically via SIGNAL.single_channel_mode.

    Firmware e4a814be (emulator 26.3.6) adds SIGNAL(0x08) bit3=single_channel_mode
    + bits[12:8]=single_channel (local CH). In that mode the trigger engine's last
    frontend stage ignores the cluster position and shreds directly to the lanes
    selected by LANE_ENABLE mask at the given local channel. Addressing:
      asic = n>>5  -> LANE_ENABLE mask = 1<<asic (asic_id_base=0)
      ch   = n&31  -> SIGNAL single_channel
      emitted key = asic<<5 | ch = n  -> histogram bin n (single delta)."""
    asic = (n >> 5) & 0x7
    ch = n & 0x1F
    fh.wr(link, EMU + E_TIMEBASE, 0x00010001)
    fh.wr(link, EMU + E_BACKGROUND, 0x00000000)
    # SIGNAL: bit1=periodic, bit3=single_channel_mode, [12:8]=ch
    sig = 0x0000000A | (ch << 8)
    wr_verify(link, EMU + E_SIGNAL, sig, 0x1F0F, label="SIGNAL")
    wr_verify(link, EMU + E_MUTRIG_FMT, 0x00000020, 0x20, label="MUTRIG_FMT")
    # LANE_ENABLE: asic_id_base=0, lane mask = 1<<asic (only this ASIC fires)
    wr_verify(link, EMU + E_LANE_EN, (1 << asic), 0x00000FFF, label="LANE_EN")
    wr_verify(link, EMU + E_RATES, (hit_rate & 0xFFFF), 0xFFFF, label="RATES")
    wr_verify(link, EMU + E_CENTRAL, 0x00000001, 0x1, label="CENTRAL")


def arm_histogram_verified(link):
    """Type0 value histogram, bin = key (LEFT=0, BINW=1). Verify LEFT/BINW
    actually landed (a stale LEFT_BOUND is the prime bin-shift suspect)."""
    wr_verify(link, HIST_CSR + H_LEFT, 0, label="HIST_LEFT")
    wr_verify(link, HIST_CSR + H_RIGHT, fh.N_BINS, label="HIST_RIGHT")
    wr_verify(link, HIST_CSR + H_BINW, 1, label="HIST_BINW")
    fh.wr(link, HIST_CSR + H_CONTROL, 0x101)   # commit (self-clearing bit0)


def sweep_channel(link, n, hit_rate, run_s, attempts):
    configure_periodic_channel(link, n, hit_rate)
    arm_histogram_verified(link)
    started, th_live = fh.run_and_freeze(link, run_s, attempts)
    counts = fh.read_frozen_bins(link, method="burst")
    fh.terminate_run(link)
    lastint = fh.rd(link, HIST_CSR + H_LASTINT) or 0
    # argmax over ALL 256 bins (works for any ASIC); a0sum here = full bin-sum.
    allb = {k: counts.get(k, 0) for k in range(fh.N_BINS)}
    argmax = max(allb, key=lambda k: allb[k]) if any(allb.values()) else None
    total = sum(counts.values())
    a0sum = total
    return {
        "n": n, "started": started, "th_live": th_live, "lastint": lastint,
        "argmax": argmax, "argmax_cnt": (allb[argmax] if argmax is not None else 0),
        "bin_n": counts.get(n, 0), "a0sum": a0sum, "total": total,
        "counts": counts,
    }


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--link", default="2")
    ap.add_argument("--hit-rate", type=lambda x: int(x, 0), default=42,
                    help="periodic hit_rate; 42 ~= 100.1 kHz @156.25MHz")
    ap.add_argument("--run-s", type=float, default=1.5,
                    help="RUNNING dwell (> one ~1s ping-pong interval)")
    ap.add_argument("--attempts", type=int, default=6)
    ap.add_argument("--channels", default="0-31",
                    help="comma list or A-B range of global channels")
    ap.add_argument("--plot-dir", default=None,
                    help="if set, save per-channel 256-bin delta PNGs here")
    ap.add_argument("--json", default=None,
                    help="if set, dump the full diagonal matrix to this JSON")
    args = ap.parse_args()
    link = args.link

    chans = []
    for tok in args.channels.split(","):
        if "-" in tok:
            a, b = tok.split("-"); chans += list(range(int(a), int(b) + 1))
        else:
            chans.append(int(tok))

    exp_rate = 156.25e6 * args.hit_rate / 65536.0
    print(f"# feb_type0_delta_sweep  link={link} hit_rate={args.hit_rate} "
          f"(expect ~{exp_rate/1e3:.1f} kHz/ch) channels={chans[0]}..{chans[-1]}")
    print(f"# emu UID={fh.rd(link, EMU)!r} runctl UID={fh.rd(link, RUNCTL)!r} "
          f"hist UID={fh.rd(link, HIST_CSR)!r}")

    if args.plot_dir:
        import os
        os.makedirs(args.plot_dir, exist_ok=True)

    rows = []
    for n in chans:
        r = sweep_channel(link, n, args.hit_rate, args.run_s, args.attempts)
        rows.append(r)
        # purity: fraction of ASIC0 counts that landed in the argmax bin
        purity = (r["argmax_cnt"] / r["a0sum"]) if r["a0sum"] else 0.0
        rate = r["bin_n"] / INTERVAL_S
        ok = "OK " if (r["argmax"] == n and purity > 0.9) else "BAD"
        print(f"CH {n:2d}: expect bin {n:2d} | argmax bin "
              f"{('--' if r['argmax'] is None else r['argmax']):>2} "
              f"cnt={r['argmax_cnt']:>7} | bin{n}={r['bin_n']:>7} "
              f"(~{rate/1e3:5.1f} kHz) | purity={purity:4.2f} | "
              f"a0sum={r['a0sum']} total={r['total']} | {ok}")
        if args.plot_dir:
            p = f"{args.plot_dir}/delta_ch{n:02d}.png"
            fh.plot_histogram(r["counts"], p, interval=0)

    # summary
    good = [r["n"] for r in rows
            if r["argmax"] == r["n"]
            and (r["argmax_cnt"] / r["a0sum"] if r["a0sum"] else 0) > 0.9]
    shifted = [(r["n"], r["argmax"]) for r in rows
               if r["argmax"] is not None and r["argmax"] != r["n"]]
    empty = [r["n"] for r in rows if r["a0sum"] == 0]
    print(f"\n# clean delta at expected bin: {good}")
    print(f"# shifted (n -> argmax): {shifted}")
    print(f"# empty (no ASIC0 hits): {empty}")
    if shifted:
        # consistent offset => stale LEFT_BOUND or geom-default mismatch
        offs = {n - am for n, am in shifted}
        print(f"# bin offsets (n-argmax): {sorted(offs)} "
              f"(single constant value => LEFT_BOUND shift)")
    if args.json:
        import json
        out = {"hit_rate": args.hit_rate, "run_s": args.run_s,
               "interval_s": INTERVAL_S, "n_bins": fh.N_BINS,
               "channels": chans,
               # diagonal matrix: rows[enabled_ch] = full 256-bin counts
               "matrix": {str(r["n"]): [r["counts"].get(k, 0)
                                        for k in range(fh.N_BINS)]
                          for r in rows},
               "summary": {"good": good, "shifted": shifted, "empty": empty}}
        with open(args.json, "w") as f:
            json.dump(out, f)
        print(f"# json saved: {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
