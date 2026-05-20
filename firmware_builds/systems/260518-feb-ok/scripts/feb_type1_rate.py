#!/usr/bin/env python3
"""On-board Type1 (MTS-processed) per-channel rate readout, both banks.

Type1 hits are the timestamp-processed hits out of the MTS preprocessors:
  mts_preprocessor_0 = UPPER bank = ASIC0-3  -> histogram source TYPE1_UP (01)
  mts_preprocessor_1 = LOWER bank = ASIC4-7  -> histogram source TYPE1_DOWN (10)
Emulator hits reach the MTS via each hit_type0_laneK_tap .primary output ->
mux_mutrig2processor[_0] -> mts_preprocessor -> type1. So with the emulator in
BACKGROUND scan mode (all channels firing) the Type1 histogram bins the per-
channel rate of each bank. Works on the current 8-lane firmware (Type1 uses the
histogram's single port 0, key = data[37:30] = ASIC<<5|CH).

Robust against SC-ring slowdown while a Quartus compile loads the CPU: every
config write is read-back-verified and the run-start sequence retries until the
histogram TOTAL_HITS actually advances.
"""
import argparse
import sys
import time

import feb_hist_read as fh

EMU, RUNCTL, H = fh.EMU, fh.RUNCTL, fh.HIST_CSR
E_CENTRAL, E_SIGNAL, E_BACKGROUND, E_RATES = (
    fh.E_CENTRAL, fh.E_SIGNAL, fh.E_BACKGROUND, fh.E_RATES)
E_TIMEBASE, E_LANE_EN = fh.E_TIMEBASE, fh.E_LANE_EN
H_LEFT, H_RIGHT, H_BINW, H_CONTROL, H_TOTAL, H_LASTINT = (
    fh.H_LEFT, fh.H_RIGHT, fh.H_BINW, fh.H_CONTROL, fh.H_TOTAL, fh.H_LASTINT)

# Type1 rate is read via the EXTENDED-PLANE in_port path, NOT source_select alone:
# the histogram ingress only samples port 0 for source=TYPE0 or in_port=EXT0/EXT1
# (there is no sample branch for source_select=TYPE1_UP/DOWN). The extended sinks
# carry [38:0]=Type1 payload, [86:39]=true ts. in_port=EXT0 -> MTS UPPER bank
# (ASIC0-3), EXT1 -> LOWER bank (ASIC4-7). source_select sets the key bits
# (TYPE1 key = payload[37:30] = ASIC<<5|CH).
#   CONTROL bits: [0]=commit [3:2]=in_port(EXT0=01,EXT1=10) [8]=key_unsigned
#                 [17:16]=source_select(TYPE1_UP=01,TYPE1_DOWN=10)
CTRL_TYPE1_UP   = (1 << 16) | (1 << 2) | (1 << 8) | 1   # 0x10105 EXT0 upper
CTRL_TYPE1_DOWN = (2 << 16) | (2 << 2) | (1 << 8) | 1   # 0x20109 EXT1 lower
INTERVAL_S = 1.0


def wr_verify(link, addr, val, mask=0xFFFFFFFF, tries=6, label=""):
    want = val & mask
    last = None
    for _ in range(tries):
        fh.wr(link, addr, val)
        time.sleep(0.03)
        last = fh.rd(link, addr)
        if last is not None and (last & mask) == want:
            return True
    print(f"#   ! verify FAIL {label} @ {addr:#x}: wrote {val:#x} rb {last!r}")
    return False


def configure_emulator_background(link, noise_rate):
    wr_verify(link, EMU + E_TIMEBASE, 0x00010001, label="TIMEBASE")
    wr_verify(link, EMU + E_SIGNAL, 0, 0x7, label="SIGNAL")
    wr_verify(link, EMU + E_RATES, (noise_rate & 0xFFFF) << 16, 0xFFFF0000,
              label="RATES")
    wr_verify(link, EMU + E_LANE_EN, 0x000000FF, 0xFFF, label="LANE_EN")
    wr_verify(link, EMU + E_BACKGROUND, 1, 0x1, label="BACKGROUND")
    wr_verify(link, EMU + E_CENTRAL, 1, 0x1, label="CENTRAL")


def start_run(link, attempts):
    """Enter RUNNING once; gate on RUNCTL STATUS (Type1 has MTS latency so HIST
    TOTAL is not a reliable 'started' signal). Returns True if STATUS==RUNNING."""
    for _ in range(attempts):
        for op, dt in ((0x13, 0.15), (0x110, 0.2), (0x11, 0.2), (0x12, 0.25)):
            fh.wr(link, RUNCTL + 0x13, op); time.sleep(dt)
        st = fh.rd(link, RUNCTL + 3)
        if st is not None and (st & 0xF) == 0x3:
            return True
    return False


def arm_and_read(link, ctrl, run_s, label):
    """Arm CONTROL within an already-RUNNING run, wait one interval, read bins.
    Does NOT (re)start or terminate the run."""
    wr_verify(link, H + H_LEFT, 0, label=f"{label} LEFT")
    wr_verify(link, H + H_RIGHT, 256, label=f"{label} RIGHT")
    wr_verify(link, H + H_BINW, 1, label=f"{label} BINW")
    # CONTROL is write-once-commit (bit0 self-clears, readback does not reflect the
    # config bits); a verify-retry loop re-commits and disrupts accumulation, so
    # write it plainly like the validated inline path.
    fh.wr(link, H + H_CONTROL, ctrl)
    time.sleep(run_s)
    counts = fh.read_frozen_bins(link, method="burst")
    total = fh.rd(link, H + H_TOTAL) or 0
    lastint = fh.rd(link, H + H_LASTINT) or 0
    nz = sorted(k for k in counts if counts[k] > 0)
    print(f"# {label}: total={total} last_interval={lastint} nz_bins={len(nz)} "
          f"range={nz[0] if nz else '-'}..{nz[-1] if nz else '-'}")
    return counts


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--link", default="2")
    ap.add_argument("--noise-rate", type=lambda x: int(x, 0), default=0x30)
    ap.add_argument("--run-s", type=float, default=1.5)
    ap.add_argument("--attempts", type=int, default=10)
    ap.add_argument("--plot", default=None, help="combined 256-bin PNG path")
    ap.add_argument("--json", default=None)
    args = ap.parse_args()
    link = args.link

    print(f"# feb_type1_rate link={link} noise_rate={args.noise_rate:#x}")
    print(f"# emu UID={fh.rd(link, EMU)!r} hist UID={fh.rd(link, H)!r}")
    configure_emulator_background(link, args.noise_rate)
    print(f"# emu BACKGROUND={fh.rd(link, EMU+E_BACKGROUND)!r} "
          f"RATES={fh.rd(link, EMU+E_RATES)!r} LANE_EN={fh.rd(link, EMU+E_LANE_EN)!r}")

    running = start_run(link, args.attempts)
    print(f"# run started (RUNCTL STATUS RUNNING) = {running}")
    up   = arm_and_read(link, CTRL_TYPE1_UP,   args.run_s, "TYPE1_UP  (ASIC0-3 / EXT0)")
    down = arm_and_read(link, CTRL_TYPE1_DOWN, args.run_s, "TYPE1_DOWN (ASIC4-7 / EXT1)")
    fh.wr(link, RUNCTL + 0x13, 0x13)   # terminate after both reads

    # Decide the bin layout: if the down bank reports bins in 0..127 (relative
    # ASIC) we shift it up by 128 to place ASIC4-7 in the absolute 128..255
    # window; if it already reports 128..255 (absolute ASIC) keep as-is.
    down_nz = [k for k in range(256) if down.get(k, 0) > 0]
    down_abs = bool(down_nz) and min(down_nz) >= 128
    combined = {}
    for k in range(256):
        combined[k] = up.get(k, 0)
    for k in range(256):
        v = down.get(k, 0)
        if v:
            dst = k if down_abs else (k + 128) if k < 128 else k
            combined[dst] = combined.get(dst, 0) + v

    # per-bank summary
    for label, counts in (("UP/ASIC0-3", up), ("DOWN/ASIC4-7", down)):
        nz = [counts[k] for k in range(256) if counts.get(k, 0) > 0]
        if nz:
            import statistics
            print(f"# {label}: occ={len(nz)} min/mean/max="
                  f"{min(nz)}/{int(statistics.mean(nz))}/{max(nz)} "
                  f"~rate={int(statistics.mean(nz)/INTERVAL_S)} Hz/ch")
        else:
            print(f"# {label}: NO hits")

    if args.json:
        import json
        json.dump({"up": [up.get(k, 0) for k in range(256)],
                   "down": [down.get(k, 0) for k in range(256)],
                   "combined": [combined.get(k, 0) for k in range(256)],
                   "down_absolute_asic": down_abs,
                   "interval_s": INTERVAL_S},
                  open(args.json, "w"))
        print(f"# json: {args.json}")

    if args.plot:
        fh.plot_histogram(combined, args.plot, interval=0)
        print(f"# plot: {args.plot}  (bins 0-127 = ASIC0-3 upper, "
              f"128-255 = ASIC4-7 lower)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
