#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TRACE_DIR=${1:-"$SCRIPT_DIR/../report_rate_scan"}
DISLIN_DIR=${DISLIN_DIR:-/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/packet_scheduler/.vendor/dislin}
MODEL_CSV="$TRACE_DIR/feb_swb_rate_prescan.csv"
MEASURED_CSV="$TRACE_DIR/feb_swb_rate_scan.csv"
BUILD_DIR="$TRACE_DIR/dislin_work"
BIN="$BUILD_DIR/feb_swb_rate_scan_dislin"
LOG="$TRACE_DIR/feb_swb_rate_scan_dislin.log"
PNG="$TRACE_DIR/feb_swb_rate_scan.png"
PDF="$TRACE_DIR/feb_swb_rate_scan.pdf"

mkdir -p "$BUILD_DIR"
if [ ! -f "$MEASURED_CSV" ]; then
  printf 'rate_hz_per_channel,actual_rate_hz_per_channel,hit_period_8ns,run_window_8ns,active_channels,frames,measured_valid,expected_hits,actual_hits,missing_hits,ghost_hits,dma_payload_words,opq_beats,ft_wr_hit,ft_rd_hit,lane0_wr_hit,lane0_drop_hit,lane0_handle_drop_hit,measured_delivered_mhits_s,measured_drop_mhits_s,measured_delivery_fraction,measured_drop_fraction,model_expected_hits,model_delivered_hits,model_dropped_hits,model_delivered_mhits_s,model_drop_mhits_s,model_delivery_fraction,model_drop_fraction,format_model_expected_hits,format_model_delivered_hits,format_model_dropped_hits,format_model_delivered_mhits_s,format_model_drop_mhits_s,format_model_delivery_fraction,format_model_drop_fraction,model_active_hit_lanes,model_dma_hit_capacity_per_frame,lane1_wr_hit,lane1_drop_hit,lane1_handle_drop_hit\n' > "$MEASURED_CSV"
fi

gcc -std=c99 -Wall -Wextra -I"$DISLIN_DIR" "$SCRIPT_DIR/feb_swb_rate_scan_dislin.c" \
  -L"$DISLIN_DIR" -Wl,-rpath,"$DISLIN_DIR" -ldislin -lm -o "$BIN"

: > "$LOG"
"$BIN" "$MODEL_CSV" "$MEASURED_CSV" "$PNG" | tee -a "$LOG"
"$BIN" "$MODEL_CSV" "$MEASURED_CSV" "$PDF" | tee -a "$LOG"

echo "RATE_SCAN_DISLIN_RENDER_PASS png=$PNG pdf=$PDF log=$LOG"
