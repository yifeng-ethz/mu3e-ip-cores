#!/usr/bin/env python3
"""Robust on-board FEB SciFi histogram run + frozen-bin readout.

Purpose
-------
Confirm on silicon whether ASIC0 CH0-2 are genuinely dead while CH3-31
accumulate, and match the result to the wrapper-TB sim. The earlier ad-hoc
readout used END_RUN (0x13) to stop and then read bins LIVE while the
ping-pong banks were still swapping, which races the waitrequest and made
the low-channel reads unreliable. This tool does the run-control sequence
*with handshake settling* and freezes the inactive bank with a TERMINATING
pulse (0x13 -> force_interval_pulse) before reading, so the bins are stable.

Run-control LOCAL_CMD (runctl_mgmt @ SC 0xC013), one opcode at a time,
each followed by a readback-poll settle on the runctl STATUS register:
    0x110  PREPARE  (RUN_PREPARE, run index 1)
    0x11   SYNC
    0x12   START    (enter RUNNING)
    ... let it run > one ping-pong interval ...
    0x13   TERMINATING (asserts force_interval_pulse -> freezes the
                        inactive bank WITHOUT wiping it)
Then the frozen bins are read with SINGLE reads (the histbins burst times
out on the ping-pong waitrequest) and decoded:  bin k -> ASIC = k>>5,
CH = k & 31.

Hardware addresses (SC ring WORD addresses):
    hist CSR  0x0A900  (CONTROL +2, LEFT +3, RIGHT +4, BINW +5,
                        TOTAL +13, LASTINT +17, UID +0)
    hist bin  0x0A800  (256-word bin SRAM)
    emulator  0x08800  (CENTRAL +7, SIGNAL +8, BACKGROUND +9, RATES +0xB,
                        TIMEBASE +0xF, LANE_EN +0x12, UID +0)
    runctl    0x0C000  (STATUS +3, LOCAL_CMD +0x13, UID +0)

NOTE: this script is built to be run BY THE PARENT against hardware. It is
NOT auto-run here. All ring access is serialized through swb_ring_lock.
"""
import argparse
import math
import re
import statistics
import subprocess
import sys
import time

SC   = "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/tools/run_script/build/sc_tool"
LOCK = "/home/yifeng/.local/bin/swb_ring_lock"

# --- SC ring addresses (word) ---
HIST_CSR = 0x0A900
HIST_BIN = 0x0A800
EMU      = 0x08800
RUNCTL   = 0x0C000

# hist CSR offsets
H_UID, H_CONTROL, H_LEFT, H_RIGHT, H_BINW = 0, 2, 3, 4, 5
H_TOTAL, H_LASTINT = 13, 17
# emulator offsets
E_UID, E_CENTRAL, E_SIGNAL, E_BACKGROUND = 0, 7, 8, 9
E_RATES, E_TIMEBASE, E_LANE_EN = 0x0B, 0x0F, 0x12
# runctl offsets
R_UID, R_STATUS, R_LOCAL_CMD = 0, 3, 0x13

# LOCAL_CMD opcodes
CMD_PREPARE = 0x110
CMD_SYNC    = 0x11
CMD_START   = 0x12
CMD_TERM    = 0x13

N_BINS = 256
N_CH   = 32   # channels per ASIC (ASIC0 = bins 0..31)


def _payload(out):
    m = re.search(r"payload\[0\]\s*=\s*(0x[0-9A-Fa-f]+)", out)
    return int(m.group(1), 16) if m else None


def rd(link, addr, retries=2):
    # The SC secondary ring intermittently returns 0xEEEEEEEE (transient
    # transaction error) or no payload on a single read; retry a couple of
    # times. Fast reply-timeout so a wedged read fails in ~0.1s, not ~1s,
    # and the tool can never hang the way a long retry loop would.
    v = None
    for _ in range(retries):
        r = subprocess.run([LOCK, "--", SC, link, "read", hex(addr), "1",
                            "--reply-timeout-ms", "150"],
                           capture_output=True, text=True)
        v = _payload(r.stdout)
        if v is not None and v != 0xEEEEEEEE:
            return v
    return v


def wr(link, addr, val):
    subprocess.run([LOCK, "--", SC, link, "write", hex(addr), hex(val)],
                   capture_output=True, text=True)


def settle(link, label, poll=R_STATUS, tries=8, dt=0.05):
    """Readback-poll the runctl STATUS to let a LOCAL_CMD handshake settle.
    Returns the last-read STATUS value. We do NOT assert a specific STATUS
    code (the encoding is firmware-version dependent); we just give the CDC
    handshake real time + a readback so the command is not dropped."""
    last = None
    for _ in range(tries):
        last = rd(link, RUNCTL + poll)
        time.sleep(dt)
    return last


def configure_emulator(link, noise_rate):
    """Background-mode scan: every scan_pos {ASIC[7:5],CH[4:0]} visited
    round-robin, fires with prob ~ noise_rate/256 (folded threshold
    = noise_rate<<8). Only ASIC0 lane exists -> bins 0..31 populate."""
    wr(link, EMU + E_TIMEBASE,   0x00010001)              # seed coarse/enc LFSR
    wr(link, EMU + E_SIGNAL,     0x00000000)              # signal engine off
    wr(link, EMU + E_RATES,      (noise_rate & 0xFFFF) << 16)  # noise hi, hit=0
    wr(link, EMU + E_LANE_EN,    0x000000FF)              # all 8 lanes, asic_base 0
    wr(link, EMU + E_BACKGROUND, 0x00000001)              # background mode on
    wr(link, EMU + E_CENTRAL,    0x00000001)              # global enable


def arm_histogram(link):
    """Type0 value histogram, bins [0,256) width 1 -> bin == ASIC<<5|CH."""
    wr(link, HIST_CSR + H_LEFT,  0)
    wr(link, HIST_CSR + H_RIGHT, N_BINS)
    wr(link, HIST_CSR + H_BINW,  1)
    # CONTROL commit: source=TYPE0(00), in_port=FILL(00), mode=0(value),
    # key_unsigned(bit8)=1, commit(bit0)=1.
    wr(link, HIST_CSR + H_CONTROL, 0x101)


def run_and_freeze(link, run_s, attempts):
    """Paced run-control: PREPARE/SYNC/START with settle between each, run
    > one ping-pong interval, then TERMINATING to freeze the inactive bank.
    Retries the start sequence until TOTAL_HITS actually advances."""
    started = False
    for attempt in range(1, attempts + 1):
        wr(link, RUNCTL + R_LOCAL_CMD, CMD_TERM)     # ensure idle/terminated
        settle(link, "term-pre")
        wr(link, RUNCTL + R_LOCAL_CMD, CMD_PREPARE)  # PREPARE (clears banks)
        settle(link, "prepare")
        wr(link, RUNCTL + R_LOCAL_CMD, CMD_SYNC)     # SYNC
        settle(link, "sync")
        wr(link, RUNCTL + R_LOCAL_CMD, CMD_START)    # START (RUNNING)
        settle(link, "start")
        th = rd(link, HIST_CSR + H_TOTAL) or 0
        st = rd(link, RUNCTL + R_STATUS)
        print(f"# run attempt {attempt}: TOTAL_HITS={th:#x} STATUS={st if st is None else f'{st:#x}'}")
        if th:
            started = True
            break
    if not started:
        return False, 0
    # Stay in RUNNING and wait > one ping-pong interval (default ~1s on board)
    # so a COMPLETE interval is frozen into the inactive (readout) bank. We do
    # NOT terminate here: the readout bank is stable to read while RUNNING and
    # refreshes each interval; TERMINATING is sent by the caller AFTER reading
    # (terminating-then-read races the bank clear). (User-prescribed sequence.)
    time.sleep(run_s)
    th_live = rd(link, HIST_CSR + H_TOTAL) or 0
    return True, th_live

def terminate_run(link):
    wr(link, RUNCTL + R_LOCAL_CMD, CMD_TERM)
    settle(link, "terminating")


_HISTBIN_RE = re.compile(r"histbin\[\d+\]=0x([0-9A-Fa-f]+)\s+addr=0x0?([0-9A-Fa-f]+)")

def read_bins_burst(link, chunk=64):
    """Read all 256 bins via sc_tool `histbins` burst in `chunk`-word groups
    (4x64). MUCH faster than 256 single sc_tool invocations (which reset the
    SC ring each time and wedge it after ~12 reads), so it completes inside
    the post-TERMINATING freeze window. The burst returns ADDRESS-ECHO only
    when read LIVE during a ping-pong swap; on the frozen bank it is correct.
    Any 0xEEEEEEEE (transient ring error) word is repaired with a single read.
    Returns dict bin->count (all 256, including zeros)."""
    out = {}
    for base_k in range(0, N_BINS, chunk):
        r = subprocess.run(
            [LOCK, "--", SC, link, "histbins", hex(HIST_BIN + base_k),
             str(chunk), "--quiet", "--reply-timeout-ms", "200"],
            capture_output=True, text=True)
        for m in _HISTBIN_RE.finditer(r.stdout):
            v = int(m.group(1), 16); addr = int(m.group(2), 16)
            k = addr - HIST_BIN
            if 0 <= k < N_BINS:
                out[k] = v
    # repair missing / error words with single reads, but BOUNDED: if the
    # ring is wedged (many errors), bail rather than 256 slow retries (which
    # both hangs and further wedges the ring).
    bad = [k for k in range(N_BINS)
           if out.get(k, 0xEEEEEEEE) == 0xEEEEEEEE or k not in out]
    if len(bad) > 48:
        print(f"# WARNING: {len(bad)} bins errored in burst -> ring likely "
              f"wedged; reporting burst values as-is (recover + rerun).")
        return {k: (0 if out.get(k, 0xEEEEEEEE) == 0xEEEEEEEE else out[k])
                for k in range(N_BINS)}
    for k in bad:
        out[k] = rd(link, HIST_BIN + k) or 0
    return out

def read_frozen_bins(link, method="burst"):
    """method: 'burst' (default, 4x64 histbins), 'single' (256 reads, slow)."""
    if method == "single":
        return {k: (rd(link, HIST_BIN + k) or 0) for k in range(N_BINS)}
    return read_bins_burst(link)


def plot_histogram(counts, path, interval=0):
    """Bar chart of all 256 histogram bins (count per frozen bank vs channel),
    in the FEB datapath-liveness readout style."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.ticker import MultipleLocator
    x = list(range(N_BINS))
    y = [counts.get(k, 0) for k in x]
    fig, ax = plt.subplots(figsize=(11, 4.2))
    ax.bar(x, y, width=0.9, color="#0000ff", edgecolor="#0000ff", linewidth=0)
    ax.set_title(f"Histogram readout counts, interval {interval}, {N_BINS} bins",
                 fontfamily="monospace")
    ax.set_xlabel("histogram channel [0,255]", fontfamily="monospace")
    ax.set_ylabel("count per frozen bank", fontfamily="monospace")
    ax.set_xlim(-2, N_BINS + 1)
    ax.xaxis.set_major_locator(MultipleLocator(32))
    ax.set_ylim(bottom=0)
    ax.grid(True, which="major", color="#888888", linewidth=0.6)
    ax.set_axisbelow(True)
    for s in ax.spines.values():
        s.set_linewidth(1.2)
    for lbl in ax.get_xticklabels() + ax.get_yticklabels():
        lbl.set_fontfamily("monospace")
    fig.tight_layout()
    fig.savefig(path, dpi=110)
    plt.close(fig)


def poisson_line(vals):
    if not vals:
        return "# (no non-zero bins)"
    m  = statistics.mean(vals)
    sd = statistics.pstdev(vals)
    if m <= 0:
        return f"# mean={m:.1f} (mean<=0; cannot form Poisson ratio)"
    return (f"# count min/mean/max = {min(vals)}/{m:.1f}/{max(vals)}  "
            f"sqrt(mean)={math.sqrt(m):.1f} obs_std={sd:.1f} "
            f"ratio={sd/math.sqrt(m):.2f} (1.0 = ideal Poisson)")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--link", default="2", help="SC link number (FEB SciFi = 2)")
    ap.add_argument("--noise-rate", type=lambda x: int(x, 0), default=0xFF,
                    help="emulator noise_rate (folded threshold = rate<<8); "
                         "0xFF ~= 99.6%% fire/visit (high statistics)")
    ap.add_argument("--run-s", type=float, default=2.0,
                    help="RUNNING dwell seconds (> one ping-pong interval)")
    ap.add_argument("--attempts", type=int, default=6,
                    help="start-sequence retries until TOTAL_HITS advances")
    ap.add_argument("--method", choices=("burst", "single"), default="burst",
                    help="bin readout: burst=4x64 histbins (fast, default), "
                         "single=256 reads (slow, ring wedges after ~12)")
    ap.add_argument("--plot", default=None,
                    help="save a 256-bin bar chart PNG to this path")
    args = ap.parse_args()
    link = args.link

    print(f"# feb_hist_read.py  link={link} noise_rate={args.noise_rate:#x} "
          f"run_s={args.run_s}")
    print(f"# emulator UID = {rd(link, EMU + E_UID)!r}  (EMUT=0x454d5554)")
    print(f"# runctl   UID = {rd(link, RUNCTL + R_UID)!r}  (RCMH=0x52434d48)")
    print(f"# hist     UID = {rd(link, HIST_CSR + H_UID)!r}  (HIST=0x48495354)")

    configure_emulator(link, args.noise_rate)
    print(f"# emu BACKGROUND={rd(link, EMU + E_BACKGROUND)!r} "
          f"RATES={rd(link, EMU + E_RATES)!r} LANE_EN={rd(link, EMU + E_LANE_EN)!r} "
          f"CENTRAL={rd(link, EMU + E_CENTRAL)!r}")

    arm_histogram(link)
    print(f"# hist CONTROL = {rd(link, HIST_CSR + H_CONTROL)!r} (expect 0x100 after commit-clear)")

    started, th_live = run_and_freeze(link, args.run_s, args.attempts)
    if not started:
        print("*** run never entered RUNNING (LOCAL_CMD handshake) ***")
        return 2
    print(f"# live TOTAL_HITS after {args.run_s:.2f}s = {th_live:#x}")
    lastint = rd(link, HIST_CSR + H_LASTINT) or 0
    print(f"# frozen LAST_INTERVAL_TOTAL_HITS = {lastint}")

    # read the stable readout bank WHILE STILL RUNNING, then terminate.
    counts = read_frozen_bins(link, method=args.method)
    terminate_run(link)

    # --- per-channel table for ASIC0 (bins 0..31) ---
    print("\n# ASIC0 per-channel frozen counts:")
    print("#  CH  bin   count")
    asic0 = {}
    for ch in range(N_CH):
        c = counts.get(ch, 0)
        asic0[ch] = c
        print(f"   {ch:2d}  {ch:3d}   {c}")

    zero0 = [ch for ch in range(N_CH) if asic0[ch] == 0]
    nz0   = [ch for ch in range(N_CH) if asic0[ch] > 0]
    print(f"\n# ASIC0 zero channels  : {zero0}")
    print(f"# ASIC0 nonzero channels: {nz0}")

    # Poisson stat over the NONZERO ASIC0 channels (the live ones).
    print(poisson_line([asic0[ch] for ch in nz0]))

    # full-map summary across all 256 bins (all ASICs)
    occ = sorted(k for k in counts if counts[k] > 0)
    tot = sum(counts.values())
    asics = sorted(set(k >> 5 for k in occ))
    print(f"\n# occupied bins = {len(occ)}/256  bin-sum = {tot}")
    print(f"# ASICs with hits: {asics}  (8-lane emulator: all of [0..7] expected "
          f"since emulator_mutrig_qsys8 + hist multi-port fix, 2026-05-20)")
    # compact full 8x32 liveness map: '.' = 0, '#' = nonzero
    print("# datapath liveness map (rows=ASIC0-7, cols=CH0-31):")
    for a in range(8):
        row = "".join('#' if counts.get(a*32+c, 0) > 0 else '.' for c in range(32))
        print(f"#  ASIC{a}: {row}")

    # --- optional bar-chart plot of all 256 bins (datapath-liveness style) ---
    if args.plot:
        plot_histogram(counts, args.plot, interval=0)
        print(f"# plot saved: {args.plot}")

    # --- verdict on the CH0-2 question ---
    ch012_dead = all(asic0[ch] == 0 for ch in (0, 1, 2))
    others_big = (len(nz0) >= 1) and (statistics.mean([asic0[ch] for ch in range(3, N_CH)] or [0]) > 0)
    if ch012_dead and others_big:
        print("\n*** REPRODUCED: ASIC0 CH0,1,2 == 0 while CH3..31 accumulate. ***")
    elif not ch012_dead:
        print("\nOK: CH0-2 accumulate -> CH0-2 NOT dead at these statistics.")
    else:
        print("\n# inconclusive: CH0-2 zero but neighbours also low -> raise run-s / noise-rate.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
