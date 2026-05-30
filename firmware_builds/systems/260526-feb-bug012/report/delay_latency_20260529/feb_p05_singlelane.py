#!/usr/bin/env python3
"""Sharpen the injection-delay slope: SINGLE emulator lane (LANE_EN=0x01) so the
multiheader injector contributes ONE phase (not 8 staggered) -> the injected-hit
delay should track header_delay with slope ~-1. Track the background-subtracted
injected feature (p05, centroid, peak) vs offset; fit slope before the frame wrap.
SYNC once, no re-sync, source=TYPE1_UP/FILL, wide window."""
import sys, time, json
sys.path.insert(0,"/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/260526-feb-bug012/scripts")
import feb_hist_read as fh
L="2"; EMU,H,RUNCTL=fh.EMU,fh.HIST_CSR,fh.RUNCTL; INJ=0x06C80
BG=0x00080000; HDR=8; LANE=0x01; STEP=30; MAXO=960; DWELL=2.2
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
def emu_on():
    wrv(EMU+fh.E_CENTRAL,0); wrv(EMU+fh.E_BACKGROUND,0); wrv(EMU+fh.E_SIGNAL,0); wrv(INJ+2,0); time.sleep(0.05)
    wrv(EMU+fh.E_TIMEBASE,0x00010001); wrv(EMU+fh.E_SIGNAL,0x1)
    wrv(EMU+fh.E_RATES,BG); wrv(EMU+fh.E_LANE_EN,LANE)
    wrv(EMU+fh.E_BACKGROUND,1); wrv(EMU+fh.E_CENTRAL,1)
def inj_off(): wrv(INJ+2,0); time.sleep(0.2)
def inj_on(off):
    wrv(INJ+2,0); wrv(INJ+6,0); wrv(INJ+3,off&0xFFFFFFFF); wrv(INJ+4,HDR); wrv(INJ+5,1); wrv(INJ+8,5); wrv(INJ+2,1); time.sleep(0.25)
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

ensure_running(); emu_on(); inj_on(0); measure()
print(f"# single-lane(0x{LANE:02x}) slope: bg={BG:#x} hdr={HDR} step={STEP} dwell={DWELL} win=[{LEFT_C},{RIGHT_C})")
inj_off(); b1=measure(); inj_off(); b2=measure(); base=[(b1[k]+b2[k])/2.0 for k in range(NB)]
offs=list(range(0,MAXO+1,STEP)); res={}
print(f"  {'off':>4} {'d_p05':>7} {'d_cen':>7} {'d_peak':>7} {'inj_tot':>8}")
for off in offs:
    inj_on(off); raw=measure()
    diff=[max(raw[k]-base[k],0) for k in range(NB)]
    t=sum(diff)
    if t<=0:
        res[str(off)]={"diff":diff,"p05":None,"cen":None,"peak":None}; print(f"  {off:>4}  EMPTY"); continue
    p05=pctl(diff,0.05); cen=sum((LEFT_C+k*BW_C)*diff[k] for k in range(NB))/t
    pk=max(range(NB),key=lambda k:diff[k])
    res[str(off)]={"diff":diff,"p05":p05,"cen":cen,"peak":LEFT_C+pk*BW_C,"tot":t}
    print(f"  {off:>4} {('%+d'%p05) if p05 else '--':>7} {cen:>+7.0f} {LEFT_C+pk*BW_C:>+7} {t:>8.0f}")
res["_baseline"]=base
json.dump({"bg":hex(BG),"lane":LANE,"hdr":HDR,"step":STEP,"offsets":offs,"LEFT_C":LEFT_C,"BW_C":BW_C,"NB":NB,"results":res},open("/tmp/feb_bug012_plots/p05_singlelane.json","w"))
def fit(key, omax):
    xs=[];ys=[]
    for off in offs:
        if off>omax: continue
        v=res[str(off)][key]
        if v is not None: xs.append(float(off)); ys.append(float(v))
    if len(xs)<3: return None
    n=len(xs);mx=sum(xs)/n;my=sum(ys)/n
    return sum((x-mx)*(y-my) for x,y in zip(xs,ys))/sum((x-mx)**2 for x in xs)
for omax in (960,700,500):
    print(f"# slope(<= {omax}): p05={fit('p05',omax)}  cen={fit('cen',omax)}  peak={fit('peak',omax)} (expect ~-1)")
fh.wr(L,RUNCTL+0x13,0x13); time.sleep(0.2)
