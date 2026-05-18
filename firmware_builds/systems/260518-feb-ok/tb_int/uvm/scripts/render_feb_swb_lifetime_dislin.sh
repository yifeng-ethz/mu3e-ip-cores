#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TRACE_DIR=${1:-"$SCRIPT_DIR/../report"}
DISLIN_DIR="${DISLIN_DIR:-/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/packet_scheduler/.vendor/dislin}"
TRACE_CSV="$TRACE_DIR/feb_swb_lifetime_trace.csv"
QUEUE_CSV="$TRACE_DIR/feb_swb_opq_queue_model.csv"
BUILD_DIR="$TRACE_DIR/dislin_work"
BIN="$BUILD_DIR/feb_swb_lifetime_dislin"
LOG="$TRACE_DIR/feb_swb_lifetime_dislin.log"
PNG="$TRACE_DIR/feb_swb_lifetime_hist.png"
PDF="$TRACE_DIR/feb_swb_lifetime_hist.pdf"
QUEUE_PNG="$TRACE_DIR/feb_swb_opq_queue_model.png"
QUEUE_PDF="$TRACE_DIR/feb_swb_opq_queue_model.pdf"

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
  "$BIN" lifetime "$TRACE_CSV" "$1" | tee -a "$LOG"
}

render_queue() {
  "$BIN" queue "$QUEUE_CSV" "$1" | tee -a "$LOG"
}

render "$PNG"
render "$PDF"
if [ -f "$QUEUE_CSV" ]; then
  render_queue "$QUEUE_PNG"
  render_queue "$QUEUE_PDF"
fi

printf 'LIFETIME_DISLIN_PASS stats=%s png=%s pdf=%s queue_png=%s queue_pdf=%s log=%s\n' \
  "$TRACE_DIR/feb_swb_lifetime_hist_stats.csv" \
  "$PNG" \
  "$PDF" \
  "$QUEUE_PNG" \
  "$QUEUE_PDF" \
  "$LOG"
