#!/usr/bin/env python3
"""On-board verification of BUG-012-R closure for the histogram_statistics Type1
ingress hole on FEB SciFi.

Reads the per-channel Type1 rate three times in one run, with three CONTROL
settings of cfg_in_port:

  Cell A: cfg_source_select=TYPE1_UP   cfg_in_port=FILL  (silicon scenario; pre-fix this read all zeros)
  Cell B: cfg_source_select=TYPE1_UP   cfg_in_port=EXT0  (legacy workaround; pre-fix this worked)
  Cell C: cfg_source_select=TYPE1_DOWN cfg_in_port=FILL  (silicon scenario, lower bank)
  Cell D: cfg_source_select=TYPE1_DOWN cfg_in_port=EXT1  (legacy workaround, lower bank)

PASS criteria (post-fix):
  - Cell A and Cell C report nonzero hits across the expected channel range
    (8 ASICs x 32 channels = 256 bins, ASIC<<5|CH).
  - Cell A's nonzero-bin set agrees with Cell B's (and Cell C with Cell D)
    within a small per-interval tolerance.
  - Pre-fix would have shown Cell A and Cell C as identically zero while
    Cell B / Cell D were nonzero, so any disagreement above the noise floor
    confirms the BUG-012-R fix landed.

Default values match feb_type1_rate.py so the existing emulator background
flood pattern is reused. Run as:
  python3 feb_type1_bug012_verify.py [--link 2] [--noise-rate 0x30] [--run-s 1.5]
"""
import argparse
import statistics
import sys
import time

# Reuse helpers from the existing 260518-feb-ok script tree.
sys.path.insert(0, "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/260518-feb-ok/scripts")
import feb_hist_read as fh

EMU, RUNCTL, H = fh.EMU, fh.RUNCTL, fh.HIST_CSR
E_CENTRAL, E_SIGNAL, E_BACKGROUND, E_RATES = (
    fh.E_CENTRAL, fh.E_SIGNAL, fh.E_BACKGROUND, fh.E_RATES)
E_TIMEBASE, E_LANE_EN = fh.E_TIMEBASE, fh.E_LANE_EN
H_LEFT, H_RIGHT, H_BINW, H_CONTROL, H_TOTAL, H_LASTINT = (
    fh.H_LEFT, fh.H_RIGHT, fh.H_BINW, fh.H_CONTROL, fh.H_TOTAL, fh.H_LASTINT)

# CONTROL bits: [0]=commit [3:2]=in_port [8]=key_unsigned [17:16]=source_select
#   source_select: TYPE0=00 TYPE1_UP=01 TYPE1_DOWN=10
#   in_port:       FILL=00  EXT0=01      EXT1=10
CTRL_T1_UP_FILL   = (1 << 16) | (0 << 2) | (1 << 8) | 1   # silicon (BUG-012)
CTRL_T1_UP_EXT0   = (1 << 16) | (1 << 2) | (1 << 8) | 1   # legacy workaround
CTRL_T1_DOWN_FILL = (2 << 16) | (0 << 2) | (1 << 8) | 1   # silicon (BUG-012)
CTRL_T1_DOWN_EXT1 = (2 << 16) | (2 << 2) | (1 << 8) | 1   # legacy workaround


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
    for _ in range(attempts):
        for op, dt in ((0x13, 0.15), (0x110, 0.2), (0x11, 0.2), (0x12, 0.25)):
            fh.wr(link, RUNCTL + 0x13, op); time.sleep(dt)
        st = fh.rd(link, RUNCTL + 3)
        if st is not None and (st & 0xF) == 0x3:
            return True
    return False


def arm_and_read(link, ctrl, run_s, label):
    wr_verify(link, H + H_LEFT, 0, label=f"{label} LEFT")
    wr_verify(link, H + H_RIGHT, 256, label=f"{label} RIGHT")
    wr_verify(link, H + H_BINW, 1, label=f"{label} BINW")
    fh.wr(link, H + H_CONTROL, ctrl)
    time.sleep(run_s)
    counts = fh.read_frozen_bins(link, method="burst")
    total = fh.rd(link, H + H_TOTAL) or 0
    lastint = fh.rd(link, H + H_LASTINT) or 0
    nz = sorted(k for k in counts if counts[k] > 0)
    print(f"# {label}: total={total} last_interval={lastint} nz_bins={len(nz)} "
          f"range={nz[0] if nz else '-'}..{nz[-1] if nz else '-'}")
    return counts, total


def summarize(counts, label):
    nz = [counts[k] for k in range(256) if counts.get(k, 0) > 0]
    if nz:
        print(f"# {label}: occ={len(nz)} min/mean/max="
              f"{min(nz)}/{int(statistics.mean(nz))}/{max(nz)}")
    else:
        print(f"# {label}: NO hits")


def verdict(label, fill_counts, ext_counts, fill_total, ext_total):
    fill_nz = sum(1 for k in range(256) if fill_counts.get(k, 0) > 0)
    ext_nz  = sum(1 for k in range(256) if ext_counts.get(k, 0) > 0)
    if fill_nz == 0 and ext_nz == 0:
        return f"INCONCLUSIVE {label}: both paths read zero - emulator/run not producing hits"
    if fill_nz == 0 and ext_nz > 0:
        return f"FAIL {label}: FILL path is zero while EXT path has {ext_nz} bins - BUG-012 NOT closed"
    if ext_nz == 0 and fill_nz > 0:
        return f"WARN {label}: EXT path zero while FILL path has {fill_nz} bins - unexpected, check EXT wiring"
    # both nonzero - check overlap of nonzero bin sets
    overlap = sum(1 for k in range(256)
                  if fill_counts.get(k, 0) > 0 and ext_counts.get(k, 0) > 0)
    overlap_pct = 100 * overlap / max(fill_nz, ext_nz, 1)
    if overlap_pct >= 70:
        return f"PASS {label}: FILL={fill_nz} EXT={ext_nz} overlap={overlap}/{max(fill_nz, ext_nz)} ({overlap_pct:.0f}%) - BUG-012 closed"
    return f"WARN {label}: FILL={fill_nz} EXT={ext_nz} overlap={overlap_pct:.0f}% - paths disagree, investigate"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--link", default="2")
    ap.add_argument("--noise-rate", type=lambda x: int(x, 0), default=0x30)
    ap.add_argument("--run-s", type=float, default=1.5)
    ap.add_argument("--attempts", type=int, default=10)
    args = ap.parse_args()
    link = args.link

    print(f"# feb_type1_bug012_verify link={link} noise_rate={args.noise_rate:#x}")
    print(f"# emu UID={fh.rd(link, EMU)!r} hist UID={fh.rd(link, H)!r}")
    configure_emulator_background(link, args.noise_rate)

    if not start_run(link, args.attempts):
        print("# FAIL: could not enter RUNNING - aborting BUG-012 verify")
        return 2

    print("\n# === Cell A: TYPE1_UP + cfg_in_port=FILL (silicon scenario) ===")
    up_fill, up_fill_tot = arm_and_read(
        link, CTRL_T1_UP_FILL, args.run_s,
        "TYPE1_UP/FILL (BUG-012 verify)")
    print("\n# === Cell B: TYPE1_UP + cfg_in_port=EXT0 (legacy workaround) ===")
    up_ext, up_ext_tot = arm_and_read(
        link, CTRL_T1_UP_EXT0, args.run_s,
        "TYPE1_UP/EXT0 (legacy)")
    print("\n# === Cell C: TYPE1_DOWN + cfg_in_port=FILL (silicon scenario) ===")
    dn_fill, dn_fill_tot = arm_and_read(
        link, CTRL_T1_DOWN_FILL, args.run_s,
        "TYPE1_DOWN/FILL (BUG-012 verify)")
    print("\n# === Cell D: TYPE1_DOWN + cfg_in_port=EXT1 (legacy workaround) ===")
    dn_ext, dn_ext_tot = arm_and_read(
        link, CTRL_T1_DOWN_EXT1, args.run_s,
        "TYPE1_DOWN/EXT1 (legacy)")

    fh.wr(link, RUNCTL + 0x13, 0x13)   # terminate run

    print("\n# === Per-cell summary ===")
    summarize(up_fill, "TYPE1_UP/FILL")
    summarize(up_ext,  "TYPE1_UP/EXT0")
    summarize(dn_fill, "TYPE1_DOWN/FILL")
    summarize(dn_ext,  "TYPE1_DOWN/EXT1")

    print("\n# === BUG-012 verdict ===")
    v_up   = verdict("TYPE1_UP",   up_fill, up_ext, up_fill_tot, up_ext_tot)
    v_down = verdict("TYPE1_DOWN", dn_fill, dn_ext, dn_fill_tot, dn_ext_tot)
    print(v_up)
    print(v_down)

    overall_pass = v_up.startswith("PASS") and v_down.startswith("PASS")
    return 0 if overall_pass else 1


if __name__ == "__main__":
    sys.exit(main())
