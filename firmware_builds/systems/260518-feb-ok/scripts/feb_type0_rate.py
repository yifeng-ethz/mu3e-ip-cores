#!/usr/bin/env python3
"""Inject ~100 kHz/channel background hits on the FEB SciFi and read the
per-channel Type0 rate from the histogram, on link 2, via sc_tool.

Per-channel source = emulator BACKGROUND mode (frontend_bkg_generator):
scans scan_pos = {ASIC[7:5], CH[4:0]} round-robin, fires per visit with
prob = noise_rate/256; channel-visit rate = clk/256, so
  per_channel_rate ~= clk * noise_rate / 65536.
The histogram (source_select=TYPE0) keys data[43:36] = ASIC<<5 | CH, so
bin k == channel k. Expected: ALL enabled channels populated ~equally.
Only bin0 populated => channel-routing bug.

Run-control is injected LOCALLY via runctl_mgmt_host LOCAL_CMD (SC 0xC013),
with STATUS polling so the multi-step RUN_PREPARE handshake completes.
"""
import subprocess, sys, time, re

SC   = "/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/tools/run_script/build/sc_tool"
LOCK = "/home/yifeng/.local/bin/swb_ring_lock"
LINK = "2"

# --- SC ring addresses (word) ---
HIST_CSR   = 0x0A900           # +2 CONTROL, +3 LEFT, +4 RIGHT, +5 BINW, +13 TOTAL, +17 LASTINT
HIST_BIN   = 0x0A800           # 256-word bin SRAM
EMU        = 0x08800           # +7 CENTRAL +8 SIGNAL +9 BACKGROUND +0xB RATES +0xF TIMEBASE +0x12 LANE_EN
RUNCTL     = 0x0C000           # +3 STATUS, +0x13 LOCAL_CMD

def _payload(out):
    m = re.search(r"payload\[0\]\s*=\s*(0x[0-9A-Fa-f]+)", out)
    return int(m.group(1), 16) if m else None

def rd(addr):
    r = subprocess.run([LOCK, "--", SC, LINK, "read", hex(addr), "1"],
                       capture_output=True, text=True)
    return _payload(r.stdout)

def wr(addr, val):
    subprocess.run([LOCK, "--", SC, LINK, "write", hex(addr), hex(val)],
                   capture_output=True, text=True)

def main():
    noise_rate = int(sys.argv[1]) if len(sys.argv) > 1 else 50   # ~100kHz/ch
    run_s      = float(sys.argv[2]) if len(sys.argv) > 2 else 0.5

    print(f"# emulator UID  = {rd(EMU):#010x} (EMUT=0x454d5554)")
    print(f"# runctl UID    = {rd(RUNCTL):#010x} (RCMH=0x52434d48)")
    print(f"# hist UID      = {rd(HIST_CSR):#010x} (HIST=0x48495354)")

    # --- configure emulator: BACKGROUND mode, all lanes, noise_rate ---
    wr(EMU+0x0F, 0x00010001)                 # TIMEBASE seed
    wr(EMU+0x08, 0x00000000)                 # SIGNAL: not used in bkg
    wr(EMU+0x0B, (noise_rate << 16) | 0x0)   # RATES: noise=noise_rate, hit=0
    wr(EMU+0x12, 0x000000FF)                  # LANE_ENABLE: 8 lanes, asic_base=0
    wr(EMU+0x09, 0x00000001)                  # BACKGROUND: hit_mode_bkg=1
    wr(EMU+0x07, 0x00000001)                  # CENTRAL: global_enable=1
    print(f"# emu BACKGROUND={rd(EMU+0x09):#x} RATES={rd(EMU+0x0B):#010x} "
          f"LANE_EN={rd(EMU+0x12):#x} CENTRAL={rd(EMU+0x07):#x}")

    # --- arm hist for Type0 per-channel value histogram ---
    wr(HIST_CSR+3, 0)            # LEFT_BOUND
    wr(HIST_CSR+4, 0x100)       # RIGHT_BOUND = 256
    wr(HIST_CSR+5, 1)           # BIN_WIDTH = 1
    wr(HIST_CSR+2, 0x101)       # CONTROL commit: TYPE0/value/FILL, key_unsigned
    print(f"# hist CONTROL  = {rd(HIST_CSR+2):#x} (expect 0x100)")

    # --- run-control via LOCAL_CMD; retry until TOTAL_HITS actually moves
    # (the LOCAL_CMD CDC handshake intermittently drops a command if not paced) ---
    def runcmd(op, wait=0.25):
        wr(RUNCTL+0x13, op); time.sleep(wait)
    started = False
    for attempt in range(1, 6):
        runcmd(0x00000013, 0.1)      # END (ensure idle)
        runcmd(0x00000110)           # RUN_PREPARE, run 1
        runcmd(0x00000011)           # SYNC
        runcmd(0x00000012)           # START_RUN
        th = rd(HIST_CSR+13) or 0
        print(f"# run attempt {attempt}: TOTAL_HITS={th:#x}")
        if th:
            started = True; break
    if not started:
        print("*** run never entered RUNNING (LOCAL_CMD handshake) ***"); return
    t0 = time.time()
    time.sleep(run_s)
    th = rd(HIST_CSR+13)
    print(f"# after {run_s:.2f}s run: TOTAL_HITS={th:#x}")

    # --- read per-channel bins LIVE via single reads (burst times out) ---
    print("# per-channel Type0 counts (single reads, live):")
    counts = {}
    for k in range(256):
        v = rd(HIST_BIN + k)
        if v:
            counts[k] = v
    dur = time.time() - t0
    wr(RUNCTL+0x13, 0x00000013)  # END_RUN (stop)

    occ = sorted(counts)
    nz  = len(occ)
    tot = sum(counts.values())
    import math, statistics
    print(f"\n# occupied channels = {nz}/256   bin-sum = {tot}")
    # low-channel coverage (ASIC0 CH0-7) — is CH0-2 missing?
    asic0 = {k: counts.get(k, 0) for k in range(32)}
    zero0 = [k for k in range(32) if asic0[k] == 0]
    print(f"# ASIC0 zero channels: {zero0}")
    if nz:
        vals = list(counts.values())
        m  = statistics.mean(vals); sd = statistics.pstdev(vals)
        print(f"# count min/mean/max = {min(vals)}/{int(m)}/{max(vals)}")
        # Poisson check: ideal std == sqrt(mean); ratio ~1.0 => Poisson
        print(f"# Poisson: sqrt(mean)={math.sqrt(m):.1f}  obs_std={sd:.1f}  "
              f"ratio={sd/math.sqrt(m):.2f} (1.0=ideal Poisson, <<1=too uniform)")
        all_same = len(set(vals)) == 1
        print(f"# all-identical={all_same} (Poisson => should be False / values vary)")
        print(f"# implied per-channel rate ~= {tot/nz/dur:,.0f} Hz (over {dur:.2f}s)")
        for k in occ[:8]:
            print(f"   bin {k:3d} ASIC {k>>5} CH {k&31:2d} : {counts[k]}")
        if occ[8:]:
            print(f"   ... ({nz-8} more)")
    # verdict
    if nz <= 1:
        print("\n*** SERIOUS BUG: only bin0 (or none) populated -> per-channel "
              "routing broken; emulator/hist not distributing across channels ***")
    elif nz < 200:
        print(f"\n*** PARTIAL: only {nz}/256 channels populated -> check lane "
              "enable / channel scan ***")
    else:
        print(f"\nOK: {nz}/256 channels populated ~uniformly.")

if __name__ == "__main__":
    main()
