#!/usr/bin/env python3
"""DECISIVE idle-engine test. Background OFF (E_BACKGROUND=0, E_RATES=0, E_CENTRAL=0)
so the injector engine is IDLE -> the injected hit dispatches immediately at
(header + header_delay), so its emitted ts tracks header_delay and delay slope -> -1.
If still flat, the dispatch-time LFSR stamping is fundamental (needs the Change-2
inject-time-ts RTL fix). Only the injected feature exists (no background bulk),
so track the raw centroid/peak/p05 directly. SYNC once, no re-sync."""
import sys, time, json
sys.path.insert(0,"/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/260526-feb-bug012/scripts")
import feb_hist_read as fh
L="2"; EMU,H,RUNCTL=fh.EMU,fh.HIST_CSR,fh.RUNCTL; INJ=0x06C80
HDR=8; LANE=0x01; STEP=30; MAXO=960; DWELL=2.0
LEFT_C,BW_C,NB=-4096,32,256; RIGHT_C=LEFT_C+NB*BW_C
def wrv(a,v):
    for _ in range(6):
        fh.wr(L,a,v); time.sleep(0.02)
        if fh.rd(L,a) is not None: return True
def ensure_running():
    for _ in range(8):
        for op,dt in ((0x13,0.15),(0x110,0.2),(0x11,0.2),(0x12,0.25)):
            fh.wr(L,RUNCTL+0x13,op); time.sleep(dt)
        st=fh.rd(L,RUNCTL+3)
        if st is not None and (st&0xF)==0x3: return True
def emu_idle():
    # frames + headers running, but NO background/central hits -> engine idle
    wrv(EMU+fh.E_CENTRAL,0); wrv(EMU+fh.E_BACKGROUND,0); wrv(EMU+fh.E_SIGNAL,0); wrv(INJ+2,0); time.sleep(0.05)
    wrv(EMU+fh.E_TIMEBASE,0x00010001); wrv(EMU+fh.E_RATES,0x0); wrv(EMU+fh.E_LANE_EN,LANE)
    wrv(EMU+fh.E_SIGNAL,0x1)            # frame engine on (headers), no hit sources enabled
    wrv(EMU+fh.E_BACKGROUND,0); wrv(EMU+fh.E_CENTRAL,0)
def inj_on(off):
    wrv(INJ+2,0); wrv(INJ+6,0); wrv(INJ+3,off&0xFFFFFFFF); wrv(INJ+4,HDR); wrv(INJ+5,1); wrv(INJ+8,5); wrv(INJ+2,1); time.sleep(0.3)
def measure():
    wrv(H+3,LEFT_C&0xFFFFFFFF); wrv(H+4,RIGHT_C&0xFFFFFFFF); wrv(H+5,BW_C); wrv(H+7,0)
    fh.wr(L,H+2,(1<<16)|(1<<8)|(1<<4)|1); time.sleep(DWELL)
    c=fh.read_frozen_bins(L,method="burst"); return [c.get(k,0) for k in range(NB)]
def pctl(hist,f):
    t=sum(hist)
    if t<=0: return None
    cum=0
    for k in range(NB):
        cum+=hist[k]
        if cum>=f*t: return LEFT_C+k*BW_C
    return None

ensure_running(); emu_idle(); inj_on(0); measure()  # warm-up
print(f"# IDLE-engine slope (bg OFF): hdr={HDR} lane=0x{LANE:02x} step={STEP} dwell={DWELL} win=[{LEFT_C},{RIGHT_C})")
offs=list(range(0,MAXO+1,STEP)); res={}
print(f"  {'off':>4} {'p05':>7} {'cen':>7} {'peak':>7} {'tot':>7}")
for off in offs:
    inj_on(off); raw=measure(); t=sum(raw)
    if t<=0:
        res[str(off)]={"raw":raw,"p05":None,"cen":None,"peak":None,"tot":0}; print(f"  {off:>4}  EMPTY"); continue
    p05=pctl(raw,0.05); cen=sum((LEFT_C+k*BW_C)*raw[k] for k in range(NB))/t
    pk=max(range(NB),key=lambda k:raw[k])
    res[str(off)]={"raw":raw,"p05":p05,"cen":cen,"peak":LEFT_C+pk*BW_C,"tot":t}
    print(f"  {off:>4} {('%+d'%p05) if p05 else '--':>7} {cen:>+7.0f} {LEFT_C+pk*BW_C:>+7} {t:>7}")
json.dump({"bg":"OFF","lane":LANE,"hdr":HDR,"step":STEP,"offsets":offs,"LEFT_C":LEFT_C,"BW_C":BW_C,"NB":NB,"results":res},open("/tmp/feb_bug012_plots/idle_slope.json","w"))
def fit(key,omax):
    xs=[];ys=[]
    for off in offs:
        if off>omax: continue
        v=res[str(off)][key]
        if v is not None: xs.append(float(off)); ys.append(float(v))
    if len(xs)<3: return None
    n=len(xs);mx=sum(xs)/n;my=sum(ys)/n
    return sum((x-mx)*(y-my) for x,y in zip(xs,ys))/sum((x-mx)**2 for x in xs)
for omax in (960,700,500,300):
    print(f"# slope(<= {omax}): p05={fit('p05',omax)}  cen={fit('cen',omax)}  peak={fit('peak',omax)} (expect ~-1)")
fh.wr(L,RUNCTL+0x13,0x13); time.sleep(0.2)
