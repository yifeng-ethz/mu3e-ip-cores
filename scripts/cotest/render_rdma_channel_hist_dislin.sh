#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <frame_channel_hist.csv> <output_dir>" >&2
  exit 2
fi

CSV_PATH=$1
OUT_DIR=$2
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DISLIN_DIR=${DISLIN_DIR:-/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/packet_scheduler/.vendor/dislin}
BUILD_DIR="${OUT_DIR}/.dislin_build"
BIN="${BUILD_DIR}/rdma_channel_hist_dislin"
LOG="${OUT_DIR}/rdma_channel_hist_dislin.log"

mkdir -p "${BUILD_DIR}" "${OUT_DIR}"
gcc -std=c99 -Wall -Wextra -I"${DISLIN_DIR}" \
  "${SCRIPT_DIR}/rdma_channel_hist_dislin.c" \
  -L"${DISLIN_DIR}" -Wl,-rpath,"${DISLIN_DIR}" \
  -ldislin -lm -o "${BIN}"

"${BIN}" "${CSV_PATH}" "${OUT_DIR}" > "${LOG}" 2>&1
cat "${LOG}"
