#!/usr/bin/env python2
"""DISLIN plots for the Type0 single-channel delta sweep.

Run with python2 (the DISLIN python binding is Py2-only on this host):
  DISLIN=/home/yifeng/packages/lib/dislin \
  LD_LIBRARY_PATH=/home/yifeng/packages/lib/dislin:$LD_LIBRARY_PATH \
  PYTHONPATH=/home/yifeng/packages/lib/dislin/python \
  python2 plot_delta_dislin.py <diagonal.json> <outdir>

Produces, in the style of the FEB datapath-liveness readout:
  delta_chNN.png  : 256-bin blue bar chart for the requested channel(s)
  diagonal.png    : color matrix, enabled-channel (y) vs histogram bin (x);
                    a perfect diagonal proves CH=N -> bin=N for all N.
"""
import json
import sys
import dislin

INTERVAL_S = 1.0


def bar_plot(counts256, ch, out_png, interval=0):
    nb = len(counts256)
    x = [float(i) for i in range(nb)]
    y0 = [0.0] * nb
    y1 = [float(v) for v in counts256]
    ymax = max(y1) if max(y1) > 0 else 1.0
    ytop = ymax * 1.15

    dislin.metafl('PNG')
    dislin.setfil(out_png)
    dislin.filmod('DELETE')
    dislin.scrmod('REVERS')          # white background, black foreground
    dislin.setpag('DA4L')            # 2970 x 2100 plot units
    dislin.winsiz(1180, 520)         # PNG pixel size
    dislin.disini()
    dislin.pagera()
    dislin.hwfont()
    dislin.height(40)
    dislin.axspos(380, 1820)         # lower-left of axis system
    dislin.axslen(2450, 1450)
    dislin.name('histogram channel [0,255]', 'X')
    dislin.name('count per frozen bank', 'Y')
    dislin.labdig(-1, 'X')
    dislin.labdig(-1, 'Y')
    dislin.ticks(1, 'X')
    dislin.setgrf('NAME', 'NAME', 'TICKS', 'TICKS')
    ystep = _nice_step(ytop)
    dislin.graf(0.0, float(nb), 0.0, 32.0, 0.0, ytop, 0.0, ystep)
    dislin.titlin('Histogram readout counts, interval %d, %d bins'
                  % (interval, nb), 1)
    dislin.title()
    # gridded, bars in blue
    dislin.color('GRAY')
    dislin.grid(1, 1)
    dislin.color('BLUE')
    dislin.barwth(-0.95)
    dislin.bartyp('VERT')
    dislin.bars(x, y0, y1, nb)
    dislin.disfin()


def diagonal_plot(matrix, channels, nb, out_png):
    # zmat[iy][ix] : iy = enabled channel index, ix = histogram bin
    ny = len(channels)
    # restrict x-window to 0..max(channel)+4 so the diagonal is readable
    xmax = min(nb, max(channels) + 4)
    zmat = []
    for ch in channels:
        row = matrix[str(ch)]
        zmat.append([float(row[i]) for i in range(xmax)])
    # DISLIN crvmat reads the flat array as ZMAT(IXDIM,IYDIM) column-major:
    # element (x=ix, y=iy) at flat[ix*ny + iy] (y varies fastest).
    zflat = []
    for ix in range(xmax):
        for iy in range(ny):
            zflat.append(zmat[iy][ix])
    zmaxv = max(zflat) if max(zflat) > 0 else 1.0

    dislin.metafl('PNG')
    dislin.setfil(out_png)
    dislin.filmod('DELETE')
    dislin.scrmod('REVERS')
    dislin.setpag('DA4L')            # landscape 2970 x 2100 (room for Z bar)
    dislin.winsiz(900, 700)
    dislin.disini()
    dislin.pagera()
    dislin.hwfont()
    dislin.height(40)
    dislin.axspos(420, 1850)
    dislin.ax3len(1650, 1400, 1400)
    dislin.name('histogram bin', 'X')
    dislin.name('enabled channel N', 'Y')
    dislin.name('count per frozen bank', 'Z')
    dislin.labdig(-1, 'X')
    dislin.labdig(-1, 'Y')
    dislin.labdig(-1, 'Z')
    dislin.autres(xmax, ny)
    dislin.titlin('Type0 single-channel sweep: CH=N -> bin=N (diagonal)', 1)
    dislin.graf3(0.0, float(xmax), 0.0, float(_nice_step(xmax)),
                 float(channels[0]), float(channels[-1] + 1), float(channels[0]),
                 float(_nice_step(channels[-1] + 1)),
                 0.0, zmaxv, 0.0, _nice_step(zmaxv))
    dislin.crvmat(zflat, xmax, ny, 1, 1)
    dislin.title()
    dislin.disfin()


def _nice_step(top):
    if top <= 0:
        return 1.0
    import math
    raw = top / 5.0
    mag = 10 ** math.floor(math.log10(raw))
    for m in (1, 2, 5, 10):
        if m * mag >= raw:
            return float(m * mag)
    return float(10 * mag)


def main():
    js = sys.argv[1]
    outdir = sys.argv[2]
    plot_chs = sys.argv[3] if len(sys.argv) > 3 else None
    with open(js) as f:
        data = json.load(f)
    matrix = data['matrix']
    channels = data['channels']
    nb = data['n_bins']

    # per-channel bar plots
    if plot_chs:
        sel = [int(c) for c in plot_chs.split(',')]
    else:
        # a representative spread
        sel = [c for c in (0, 7, 15, 31) if c in channels]
    for ch in sel:
        out = '%s/delta_ch%02d.png' % (outdir, ch)
        bar_plot(matrix[str(ch)], ch, out)
        print('wrote %s' % out)

    # diagonal proof
    out = '%s/diagonal.png' % outdir
    diagonal_plot(matrix, channels, nb, out)
    print('wrote %s' % out)


if __name__ == '__main__':
    main()
