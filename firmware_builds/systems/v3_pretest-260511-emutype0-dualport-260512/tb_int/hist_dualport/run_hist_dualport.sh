#!/usr/bin/env bash
set -euo pipefail

CASE="${1:-smoke}"

BUILD_DIR="/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512"
REPO_DIR="/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores"
TB_DIR="${BUILD_DIR}/tb_int/hist_dualport"
REPORT_DIR="${BUILD_DIR}/tb_int/REPORT"
STAMP="$(date +%Y%m%d_%H%M%S)"
PREFIX="${REPORT_DIR}/${CASE}_${STAMP}"
WORK_DIR="${REPORT_DIR}/questa_work_${CASE}_${STAMP}"
QUESTA_HOME="${QUESTA_HOME:-/data1/questaone_sim/questasim}"
QUESTA_BIN="${QUESTA_HOME}/linux_x86_64"

mkdir -p "${REPORT_DIR}" "${WORK_DIR}"

export LM_LICENSE_FILE="8161@lic-mentor.ethz.ch"
export MGLS_LICENSE_FILE="${LM_LICENSE_FILE}"
export SALT_LICENSE_SERVER="${LM_LICENSE_FILE}"
export QSIM_INI="${QSIM_INI:-${QUESTA_HOME}/modelsim.ini}"
export PATH="${QUESTA_BIN}:${PATH}"

case "${CASE}" in
    smoke)
        TEST_HITS=1000
        TEST_INTERVAL=2000
        TEST_INTERVALS=1
        HIT_PERIOD=2
        LIVE_READBACK=1
        TITLE="Dual-port smoke simulation"
        STABLE_MD="${REPORT_DIR}/dualport_smoke.md"
        ;;
    soak)
        TEST_HITS=100000
        TEST_INTERVAL=1250000
        TEST_INTERVALS=10
        HIT_PERIOD=249
        LIVE_READBACK=0
        TITLE="100k single-channel 10ms ping-pong soak simulation"
        STABLE_MD="${REPORT_DIR}/100k_single_channel_soak.md"
        ;;
    *)
        echo "unknown case: ${CASE}" >&2
        exit 2
        ;;
esac

"${QUESTA_BIN}/vlib" "${WORK_DIR}" > "${PREFIX}_compile.log"

"${QUESTA_BIN}/vcom" -2008 -work "${WORK_DIR}" \
    "${REPO_DIR}/histogram_statistics/rtl/histogram_statistics_v2_pkg.vhd" \
    "${REPO_DIR}/histogram_statistics/rtl/true_dual_port_ram_single_clock.vhd" \
    "${REPO_DIR}/histogram_statistics/rtl/hit_fifo.vhd" \
    "${REPO_DIR}/histogram_statistics/rtl/rr_arbiter.vhd" \
    "${REPO_DIR}/histogram_statistics/rtl/bin_divider.vhd" \
    "${REPO_DIR}/histogram_statistics/rtl/coalescing_queue.vhd" \
    "${REPO_DIR}/histogram_statistics/rtl/pingpong_sram.vhd" \
    "${REPO_DIR}/histogram_statistics/rtl/histogram_ingress_bridge.vhd" \
    "${REPO_DIR}/histogram_statistics/rtl/histogram_statistics_v2.vhd" \
    "${TB_DIR}/tb_hist_dualport.vhd" \
    >> "${PREFIX}_compile.log"

"${QUESTA_BIN}/vsim" -c -lib "${WORK_DIR}" tb_hist_dualport \
    -gTEST_NAME="${CASE}" \
    -gREPORT_PREFIX="${PREFIX}" \
    -gTEST_HITS_TOTAL="${TEST_HITS}" \
    -gTEST_INTERVAL_CYCLES="${TEST_INTERVAL}" \
    -gTEST_INTERVAL_COUNT="${TEST_INTERVALS}" \
    -gHIT_PERIOD_CYCLES="${HIT_PERIOD}" \
    -gLIVE_BIN_READBACK="${LIVE_READBACK}" \
    -do "run -all; quit -f" | tee "${PREFIX}_transcript.log"

python3 "${TB_DIR}/summarize_hist_dualport.py" "${PREFIX}" "${PREFIX}.md" "${TITLE}"

if [[ -e "${STABLE_MD}" ]]; then
    mv "${STABLE_MD}" "${STABLE_MD}.${STAMP}.bak"
fi
cp "${PREFIX}.md" "${STABLE_MD}"

echo "report=${PREFIX}.md"
echo "stable_report=${STABLE_MD}"
