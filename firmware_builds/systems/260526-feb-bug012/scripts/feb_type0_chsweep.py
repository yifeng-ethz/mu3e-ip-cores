#!/usr/bin/env python3
"""Single-channel PERIODIC injection sweep to isolate the CH0-2 drop.

Emulator in internal PERIODIC mode (NOT background scan):
  SIGNAL(0x08) bit0=hit_mode_sig=0 (internal), bit1=internal_sub_mode=1 (periodic)
  CLUSTER_FIX(0x0C): geom_fix_left_low/high = N (writedata[6:0]/[13:7]), enable bit14
    -> cfg_hit_channel_low/high = N  -> trigger engine fires ONLY channel N.
  RATES(0x0B) hit_rate -> periodic rate = clk*hit_rate/65536 (~100kHz @ hit_rate=42).
  BACKGROUND(0x09)=0 (bkg scan OFF), CENTRAL(0x07)=1 (global enable).
Histogram: source=TYPE0, bin_width=1 -> bin = ASIC<<5|CH. For ASIC0, bin==N.

For each channel N in 0..31: configure, run (retry until hits flow), read bin N.
Report which channels register -> isolates whether CH0-2 are dead in the
histogram/tap (fail even when individually targeted) or only in the bkg scan.
"""
import subprocess, sys, time, re
SC="/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/tools/run_script/build/sc_tool"
LOCK="/home/yifeng/.local/bin/swb_ring_lock"; LINK="2"
HIST=0x0A900; HBIN=0x0A800; EMU=0x08800; RUNCTL=0x0C000
def _p(o):
    m=re.search(r"payload\[0\]\s*=\s*(0x[0-9A-Fa-f]+)",o); return int(m.group(1),16) if m else None
def rd(a):
    return _p(subprocess.run([LOCK,"--",SC,LINK,"read",hex(a),"1"],capture_output=True,text=True).stdout)
def wr(a,v):
    subprocess.run([LOCK,"--",SC,LINK,"write",hex(a),hex(v)],capture_output=True,text=True)

def cfg_channel(n, hit_rate):
    wr(EMU+0x0F, 0x00010001)               # TIMEBASE seed
    wr(EMU+0x09, 0)                         # BACKGROUND off
    wr(EMU+0x08, 0x00000002)               # SIGNAL: internal + periodic
    wr(EMU+0x0C, (1<<14)|((n&0x7f)<<7)|(n&0x7f))  # CLUSTER_FIX left: low=high=n, enable
    wr(EMU+0x0B, (0<<16)|(hit_rate&0xffff))# RATES: hit_rate, noise=0
    wr(EMU+0x12, 0x000000FF)                # LANE_ENABLE all
    wr(EMU+0x07, 0x00000001)                # CENTRAL global enable

def run_until_hits():
    for _ in range(6):
        wr(RUNCTL+0x13,0x13); time.sleep(0.1)
        wr(RUNCTL+0x13,0x110); time.sleep(0.22)
        wr(RUNCTL+0x13,0x11);  time.sleep(0.22)
        wr(RUNCTL+0x13,0x12);  time.sleep(0.22)
        if (rd(HIST+13) or 0): return True
    return False

def main():
    hit_rate = int(sys.argv[1]) if len(sys.argv)>1 else 42   # ~100kHz @156MHz
    print(f"# emu UID={rd(EMU):#x} runctl UID={rd(RUNCTL):#x} hist UID={rd(HIST):#x}")
    print(f"# single-channel PERIODIC sweep, hit_rate={hit_rate}")
    # arm hist Type0 per-channel once
    wr(HIST+3,0); wr(HIST+4,0x100); wr(HIST+5,1); wr(HIST+2,0x101)
    res={}
    for n in range(32):
        cfg_channel(n, hit_rate)
        ok = run_until_hits()
        time.sleep(0.25)
        binN = rd(HBIN+n) or 0
        total= rd(HIST+13) or 0
        # also scan a few neighbours to see if the hit landed elsewhere
        neigh = {k: (rd(HBIN+k) or 0) for k in (n-1,n,n+1) if 0<=k<256}
        wr(RUNCTL+0x13,0x13)
        landed = [k for k,v in neigh.items() if v>0]
        res[n]=(binN,total,landed)
        print(f"CH {n:2d}: started={ok} TOTAL={total:#x} bin{n}={binN}  nonzero_neighbours={landed}")
    meas=[n for n in res if res[n][0]>0]
    miss=[n for n in res if res[n][0]==0 and res[n][1]>0]   # hits flowed but not in bin n
    dead=[n for n in res if res[n][1]==0]                   # no hits at all
    print(f"\n# measured (bin n>0): {meas}")
    print(f"# hits-flowed-but-not-in-bin-n (mis-binned): {miss}")
    print(f"# no-hits-at-all: {dead}")

if __name__=="__main__":
    main()
