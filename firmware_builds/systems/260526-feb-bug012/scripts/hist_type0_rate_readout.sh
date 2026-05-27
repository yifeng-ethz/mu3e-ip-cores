#!/usr/bin/env bash
# On-board Type0 per-channel rate readout for the FEB SciFi histogram.
# Run AFTER a run is live (or just ended) on FEB link 2. Reads the 256
# histogram bins (each bin = one (ASIC,CH) key = data[43:36]) and decodes
# count + rate per channel.
#
# Usage: hist_type0_rate_readout.sh [run_seconds]
#   run_seconds : optional run duration (s) to convert counts -> Hz.
#
# Pre-req: hist armed for Type0 value histogram (source=TYPE0, mode=0,
#   bin_width=1, bounds 0..256) - done by the arming step. Key decode:
#   bin index k -> ASIC = k>>5, CH = k & 0x1F  (8 ASIC x 32 CH).
set -u
SC=/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/tools/run_script/build/sc_tool
LOCK=~/.local/bin/swb_ring_lock
RUN_S="${1:-0}"

rd() { $LOCK -- "$SC" 2 read "$1" 1 2>&1 | sed -n '/packet payload:/,/^[a-z]*:/p' | grep payload | sed 's/.*= //'; }

echo "=== FEB SciFi Type0 per-channel histogram readout $(date) ==="
echo "CONTROL    @0x0A902 = $(rd 0x0A902)   (expect 0x100: TYPE0/value/FILL)"
echo "TOTAL_HITS @0x0A90D = $(rd 0x0A90D)"
echo "LAST_INTERVAL_HITS  = $(rd 0x0A911)"
echo "UNDERFLOW  @0x0A908 = $(rd 0x0A908)"
echo "OVERFLOW   @0x0A909 = $(rd 0x0A909)"
echo "DROPPED    @0x0A90E = $(rd 0x0A90E)"
echo ""
echo "--- per-channel bins (non-zero only): bin k -> ASIC=k>>5 CH=k&31 ---"
# histbins prints: histbin[i]=0x... addr=0x... ; parse non-zero.
$LOCK -- "$SC" 2 histbins 0x0A800 256 --quiet --reply-timeout-ms 100 2>&1 \
  | awk -v runs="$RUN_S" '
    /histbin\[/ {
        # histbin[K]=0xVAL addr=...
        split($1, a, /[][]/); k = a[2]+0;
        n = $0; sub(/.*=0x/, "", n); sub(/ .*/, "", n);
        val = strtonum("0x" n);
        if (val > 0) {
            asic = int(k/32); ch = k%32;
            if (runs+0 > 0) {
                rate = val/runs;
                printf "  bin %3d  ASIC %d CH %2d : %8d hits   %10.1f Hz\n", k, asic, ch, val, rate;
            } else {
                printf "  bin %3d  ASIC %d CH %2d : %8d hits\n", k, asic, ch, val;
            }
            sum += val; nz++;
        }
    }
    END {
        printf "\n  occupied channels = %d ; bin-sum = %d", nz+0, sum+0;
        if (runs+0 > 0) printf " ; total rate = %.1f Hz", sum/runs;
        printf "\n";
    }'
