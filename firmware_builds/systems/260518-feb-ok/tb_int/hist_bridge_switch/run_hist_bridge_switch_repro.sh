#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TB_INT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="$(cd "${TB_INT_DIR}/.." && pwd)"
REPO_DIR="$(cd "${BUILD_DIR}/../../.." && pwd)"

STAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_ROOT="${REPORT_ROOT:-${TB_INT_DIR}/REPORT}"
REPORT_DIR="${REPORT_DIR:-${REPORT_ROOT}/hist_bridge_switch_${STAMP}}"
PREFIX="${REPORT_DIR}/hist_bridge_switch"
WORK_DIR="${WORK_DIR:-${REPORT_DIR}/questa_work}"
QUESTA_HOME="${QUESTA_HOME:-/data1/questaone_sim-2026.1_1/questasim}"

if [[ ! -x "${QUESTA_HOME}/linux_x86_64/vcom" && -x /data1/questaone_sim/questasim/linux_x86_64/vcom ]]; then
    QUESTA_HOME=/data1/questaone_sim/questasim
fi

QUESTA_BIN="${QUESTA_HOME}/linux_x86_64"
VLIB="${VLIB:-${QUESTA_BIN}/vlib}"
VCOM="${VCOM:-${QUESTA_BIN}/vcom}"
VSIM="${VSIM:-${QUESTA_BIN}/vsim}"

if [[ -n "${BRIDGE_RTL:-}" ]]; then
    BRIDGE_SOURCE="${BRIDGE_RTL}"
else
    BRIDGE_SOURCE=""
    for candidate in \
        "${BUILD_DIR}/syn/feb_system_v3/synthesis/submodules/rtl/histogram_ingress_bridge.vhd" \
        "${BUILD_DIR}/quartus_systems/scifi_datapath_system_v3/synthesis/submodules/rtl/histogram_ingress_bridge.vhd" \
        "${BUILD_DIR}/quartus_systems/scifi_datapath_system_v3_pipe/synthesis/submodules/rtl/histogram_ingress_bridge.vhd" \
        "${REPO_DIR}/histogram_statistics/rtl/histogram_ingress_bridge.vhd"
    do
        if [[ -f "${candidate}" ]]; then
            BRIDGE_SOURCE="${candidate}"
            break
        fi
    done
fi

if [[ -z "${BRIDGE_SOURCE}" || ! -f "${BRIDGE_SOURCE}" ]]; then
    echo "histogram_ingress_bridge.vhd not found; set BRIDGE_RTL=/path/to/histogram_ingress_bridge.vhd" >&2
    exit 2
fi

mkdir -p "${REPORT_DIR}" "${WORK_DIR}"

ETH_LIC_SERVER="${ETH_LIC_SERVER:-8161@lic-mentor.ethz.ch}"
export LM_LICENSE_FILE="${ETH_LIC_SERVER}"
export MGLS_LICENSE_FILE="${LM_LICENSE_FILE}"
export SALT_LICENSE_SERVER="${LM_LICENSE_FILE}"
export QSIM_INI="${QSIM_INI:-${QUESTA_HOME}/modelsim.ini}"
export PATH="${QUESTA_BIN}:${PATH}"

"${VLIB}" "${WORK_DIR}" > "${PREFIX}_compile.log"

"${VCOM}" -2008 -work "${WORK_DIR}" \
    "${BRIDGE_SOURCE}" \
    "${SCRIPT_DIR}/tb_hist_bridge_switch_repro.vhd" \
    >> "${PREFIX}_compile.log"

set +e
"${VSIM}" -c -lib "${WORK_DIR}" tb_hist_bridge_switch_repro \
    -gREPORT_PREFIX="${PREFIX}" \
    -do "run -all; quit -f" | tee "${PREFIX}_transcript.log"
VSIM_STATUS=${PIPESTATUS[0]}
set -e

{
    echo
    echo "## Runner"
    echo
    echo "- bridge_rtl: \`${BRIDGE_SOURCE}\`"
    echo "- testbench: \`${SCRIPT_DIR}/tb_hist_bridge_switch_repro.vhd\`"
    echo "- transcript: \`${PREFIX}_transcript.log\`"
    echo "- events_csv: \`${PREFIX}_events.csv\`"
    echo "- compile_log: \`${PREFIX}_compile.log\`"
} >> "${PREFIX}_summary.md"

if [[ ${VSIM_STATUS} -ne 0 ]]; then
    echo "vsim failed: ${PREFIX}_transcript.log" >&2
    exit "${VSIM_STATUS}"
fi

if ! grep -q "tb_hist_bridge_switch_repro PASS" "${PREFIX}_transcript.log"; then
    echo "PASS marker missing: ${PREFIX}_transcript.log" >&2
    exit 1
fi

echo "report=${PREFIX}_summary.md"
echo "events=${PREFIX}_events.csv"
echo "transcript=${PREFIX}_transcript.log"
