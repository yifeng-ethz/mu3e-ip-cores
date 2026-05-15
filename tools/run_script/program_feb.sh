#!/bin/bash
# program_feb.sh -- canonical FEB SOF programming wrapper.
#
# Loads a FEB top.sof over USB-BlasterII [7-2] and enforces the mandatory
# 20-second LVDS-PLL + firefly-transceiver settle window before returning.
# SC reads issued inside that window return clean-looking trash that the
# SWB secondary ring parses as floods of "invalid RD/WR" packets with bogus
# addresses (50k+ word secondary delta). This is NOT a real protocol bug;
# it is a timing race between FEB FPGA configuration completing and the
# LVDS PHY word-aligning to its host. 10 seconds is not enough -- the
# scratch_pad_ram slave at SC byte 0x00000 is the last to come up. 20 s
# is the empirically-verified safe minimum (2026-05-11).
#
# Usage:
#   program_feb.sh <top.sof> [--settle <seconds>] [--cable <cable>]
#
# Defaults:
#   --settle 20      (>=20 enforced; warning if user override is shorter)
#   --cable "USB-BlasterII [7-2]"
#
# Exit codes:
#   0  programming succeeded and settle window elapsed
#   1  user error (missing .sof, bad arg)
#   2  quartus_pgm failed
set -euo pipefail

SOF=""
SETTLE=20
CABLE="USB-BlasterII [7-2]"
QPG=/data1/intelFPGA/18.1/quartus/bin/quartus_pgm

while [ $# -gt 0 ]; do
    case "$1" in
        --settle)  SETTLE="$2"; shift 2 ;;
        --cable)   CABLE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 <top.sof> [--settle <seconds>] [--cable <cable>]"
            exit 0 ;;
        *)         SOF="$1"; shift ;;
    esac
done

if [ -z "$SOF" ]; then
    echo "error: missing top.sof path" >&2
    echo "Usage: $0 <top.sof> [--settle <seconds>] [--cable <cable>]" >&2
    exit 1
fi

if [ ! -f "$SOF" ]; then
    echo "error: SOF not found: $SOF" >&2
    exit 1
fi

if [ "$SETTLE" -lt 20 ]; then
    echo "WARNING: settle=$SETTLE s is below the 20 s minimum; SC reads issued in the FEB LVDS-PLL settle window return trash on the SWB secondary ring (50k+ invalid packets). 10 s does not cover scratch_pad_ram at SC 0x00000. Recommend --settle 20 (default)." >&2
fi

echo "program_feb.sh: programming $SOF on cable '$CABLE'"
if ! "$QPG" -c "$CABLE" --mode=JTAG -o "p;${SOF}@1"; then
    echo "error: quartus_pgm failed" >&2
    exit 2
fi

echo "program_feb.sh: FEB programmed. Waiting ${SETTLE} s for LVDS PLL + firefly transceiver settle."
echo "                (See ~/.claude/.../feedback_feb_post_program_settle.md or ~/AGENTS.md.)"
sleep "$SETTLE"
echo "program_feb.sh: settle window elapsed; FEB is SC-ready."
