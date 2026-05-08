#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TRACE_DIR=${1:-"$SCRIPT_DIR/../report"}
DISLIN_DIR="${DISLIN_DIR:-/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/packet_scheduler/.vendor/dislin}"
TRACE_CSV="$TRACE_DIR/feb_swb_lifetime_trace.csv"
BUILD_DIR="$TRACE_DIR/dislin_work"
BIN="$BUILD_DIR/feb_swb_lifetime_dislin"
LOG="$TRACE_DIR/feb_swb_lifetime_dislin.log"
PNG="$TRACE_DIR/feb_swb_lifetime_hist.png"
PDF="$TRACE_DIR/feb_swb_lifetime_hist.pdf"

mkdir -p "$BUILD_DIR"

gcc -O2 -Wall -Wextra -std=c11 \
  -I"$DISLIN_DIR" \
  "$SCRIPT_DIR/feb_swb_lifetime_dislin.c" \
  -L"$DISLIN_DIR" \
  -Wl,-rpath,"$DISLIN_DIR" \
  -ldislin -lm \
  -o "$BIN"

: > "$LOG"

render() {
  "$BIN" "$TRACE_CSV" "$1" | tee -a "$LOG"
}

render "$PNG"
render "$PDF"

printf 'LIFETIME_DISLIN_PASS stats=%s png=%s pdf=%s log=%s\n' \
  "$TRACE_DIR/feb_swb_lifetime_hist_stats.csv" \
  "$PNG" \
  "$PDF" \
  "$LOG"
