#!/usr/bin/env python2
# DISLIN: FEB v4 hist delay-mode on silicon is a TRANSPORT-LATENCY histogram,
# flat vs injector header_delay by construction. Panel A: injected-feature
# centroid/p05 vs header_delay (flat measured) with the kbriggl in-frame-phase
# slope=-1 reference (a DIFFERENT observable). Panel B: a representative delay
# distribution. Single-lane long-dwell data = cleanest flat evidence.
import json, dislin
D = json.load(open("/tmp/feb_bug012_plots/p05_singlelane.json"))
LEFT, BW, NB = D["LEFT_C"], D["BW_C"], D["NB"]
offs = [o for o in D["offsets"]]
R = D["results"]
xo, ycen, yp05 = [], [], []
for off in offs:
    r = R[str(off)]
    if r.get("cen") is not None:
        xo.append(float(off)); ycen.append(float(r["cen"])); yp05.append(float(r["p05"]))
n = len(xo); mx = sum(xo)/n; my = sum(ycen)/n
slope = sum((x-mx)*(y-my) for x,y in zip(xo,ycen))/sum((x-mx)**2 for x in xo)
# kbriggl in-frame-phase reference: slope -1 anchored at first point, wrap @910
yk = []
for x in xo:
    v = ycen[0] - (x - xo[0])
    while v < ycen[0] - 910: v += 910
    yk.append(v)
# representative distribution at the largest-count offset
best = max(offs, key=lambda o: R[str(o)].get("tot",0))
diff = R[str(best)]["diff"]; xb = [LEFT + k*BW + BW/2 for k in range(NB)]

dislin.metafl("PNG"); dislin.setfil("/tmp/feb_bug012_plots/delay_latency_flat_dislin.png")
dislin.filmod("DELETE"); dislin.scrmod("REVERS"); dislin.setpag("DA4L")
dislin.winsiz(1800,1200); dislin.disini(); dislin.pagera(); dislin.hwfont()
dislin.height(30); dislin.color("FORE")
dislin.messag("FEB v4 hist delay-mode = TRANSPORT LATENCY (arrival_gts - absolute_emission): flat vs header_delay", 150, 60)

# Panel A
dislin.axspos(330,1010); dislin.axslen(2200,700); dislin.height(28)
dislin.name("injector header_delay [8ns cyc]","X")
dislin.name("injected-hit delay [8ns cyc]","Y")
dislin.labdig(-1,"X"); dislin.labdig(-1,"Y")
dislin.setgrf("NAME","NAME","TICKS","TICKS")
ymin = min(min(ycen),min(yp05),min(yk)) - 150
ymax = max(max(ycen),max(yp05),max(yk)) + 150
dislin.graf(0.0, float(max(offs)), 0.0, 200.0, ymin, ymax, ymin, 250.0)
# measured centroid (thick black + markers)
dislin.color("FORE"); dislin.thkcrv(4); dislin.incmrk(1); dislin.marker(21); dislin.curve(xo,ycen,n)
# measured p05 (green)
dislin.color("GREEN"); dislin.thkcrv(2); dislin.incmrk(1); dislin.marker(4); dislin.curve(xo,yp05,n)
# kbriggl slope=-1 in-frame-phase reference (red dashed)
dislin.color("RED"); dislin.thkcrv(2); dislin.incmrk(0); dislin.dash(); dislin.curve(xo,yk,n); dislin.solid()
dislin.color("FORE"); dislin.height(22)
dislin.messag("BLACK = measured centroid (slope %+.3f, ~flat)   GREEN = measured p05" % slope, 380, 940)
dislin.color("RED"); dislin.messag("- - kbriggl IN-FRAME-PHASE reference slope=-1 (frame_base - emission; a DIFFERENT observable, needs frame-base sideband)", 380, 975)
dislin.color("FORE"); dislin.endgrf()

# Panel B
dislin.axspos(330,1900); dislin.axslen(2200,620); dislin.height(28)
dislin.name("delay = gts_8n - hit_ts  [8ns cyc]","X"); dislin.name("count (bg-subtracted)","Y")
dislin.labdig(-1,"X"); dislin.labdig(-1,"Y"); dislin.setgrf("NAME","NAME","TICKS","TICKS")
ytop = float(max(diff))*1.15 if max(diff)>0 else 100.0
dislin.graf(float(LEFT), float(LEFT+NB*BW), float(LEFT), 1000.0, 0.0, ytop, 0.0, ytop/5.0)
dislin.color("BLUE"); dislin.thkcrv(2); dislin.incmrk(0); dislin.curve(xb, [d if d>0 else 0 for d in diff], NB)
dislin.color("FORE"); dislin.height(22)
dislin.messag("injected-hit transport-latency distribution at header_delay=%d (centroid ~+%d, independent of header_delay)" % (best,int(my)), 380, 1330)
dislin.endgrf(); dislin.disfin()
print("wrote delay_latency_flat_dislin.png  slope=%+.3f mean_latency=+%d best_off=%d" % (slope,int(my),best))
