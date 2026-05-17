#!/usr/bin/env bash
set -euo pipefail

CASE="${1:-smoke}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${MU3E_IP_CORES_ROOT:-}" ]]; then
    REPO_DIR="${MU3E_IP_CORES_ROOT}"
    BUILD_DIR="${REPO_DIR}/firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512"
else
    BUILD_DIR="$(realpath -m -- "${SCRIPT_DIR}/../..")"
    REPO_DIR="$(realpath -m -- "${BUILD_DIR}/../../..")"
fi
TB_DIR="${BUILD_DIR}/tb_int/hist_dualport"
REPORT_DIR="${BUILD_DIR}/tb_int/REPORT"
SIM_RTL_DIR="${BUILD_DIR}/quartus_systems/scifi_datapath_system_v3/simulation/submodules"
STAMP="$(date +%Y%m%d_%H%M%S)"
PREFIX="${REPORT_DIR}/hist_direct_v3_${CASE}_${STAMP}"
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
        RUN_CYCLES="${RUN_CYCLES:-1250000}"
        INTERVAL_CYCLES="${INTERVAL_CYCLES:-125000}"
        STABLE_SUMMARY="${REPORT_DIR}/hist_direct_v3_smoke_summary.csv"
        ;;
    matrix)
        RUN_CYCLES="${RUN_CYCLES:-1250000}"
        INTERVAL_CYCLES="${INTERVAL_CYCLES:-125000}"
        STABLE_SUMMARY="${REPORT_DIR}/hist_direct_v3_matrix_summary.csv"
        ;;
    type0_rate_max)
        RUN_CYCLES="${RUN_CYCLES:-1250000}"
        INTERVAL_CYCLES="${INTERVAL_CYCLES:-125000}"
        STABLE_SUMMARY="${REPORT_DIR}/hist_direct_v3_type0_rate_max_summary.csv"
        ;;
    type1_delay_sweep)
        RUN_CYCLES="${RUN_CYCLES:-1250000}"
        INTERVAL_CYCLES="${INTERVAL_CYCLES:-125000}"
        STABLE_SUMMARY="${REPORT_DIR}/hist_direct_v3_type1_delay_sweep_summary.csv"
        STABLE_DELAY_BINS="${REPORT_DIR}/hist_direct_v3_type1_delay_sweep_delay_bins.csv"
        STABLE_TYPE1_META="${REPORT_DIR}/hist_direct_v3_type1_delay_sweep_type1_meta.csv"
        ;;
    type1_delay_sweep_allch)
        RUN_CYCLES="${RUN_CYCLES:-1250000}"
        INTERVAL_CYCLES="${INTERVAL_CYCLES:-125000}"
        STABLE_SUMMARY="${REPORT_DIR}/hist_direct_v3_type1_delay_sweep_allch_summary.csv"
        STABLE_DELAY_BINS="${REPORT_DIR}/hist_direct_v3_type1_delay_sweep_allch_delay_bins.csv"
        STABLE_TYPE1_META="${REPORT_DIR}/hist_direct_v3_type1_delay_sweep_allch_type1_meta.csv"
        ;;
    *)
        echo "unknown case: ${CASE} (expected smoke, matrix, type0_rate_max, type1_delay_sweep, or type1_delay_sweep_allch)" >&2
        exit 2
        ;;
esac

for required in \
    histogram_statistics_v2_pkg.vhd \
    true_dual_port_ram_single_clock.vhd \
    hit_fifo.vhd \
    rr_arbiter.vhd \
    bin_divider.vhd \
    coalescing_queue.vhd \
    pingpong_sram.vhd \
    histogram_statistics_v2.vhd; do
    if [[ ! -f "${SIM_RTL_DIR}/${required}" ]]; then
        echo "missing generated FEB simulation RTL: ${SIM_RTL_DIR}/${required}" >&2
        exit 2
    fi
done

cp "${QSIM_INI}" "${WORK_DIR}/modelsim.ini"
chmod u+w "${WORK_DIR}/modelsim.ini"
"${QUESTA_BIN}/vlib" "${WORK_DIR}/work" > "${PREFIX}_compile.log"
"${QUESTA_BIN}/vlib" "${WORK_DIR}/lpm" >> "${PREFIX}_compile.log"
"${QUESTA_BIN}/vlib" "${WORK_DIR}/altera_mf" >> "${PREFIX}_compile.log"
"${QUESTA_BIN}/vmap" -modelsimini "${WORK_DIR}/modelsim.ini" work "${WORK_DIR}/work" >> "${PREFIX}_compile.log"
"${QUESTA_BIN}/vmap" -modelsimini "${WORK_DIR}/modelsim.ini" lpm "${WORK_DIR}/lpm" >> "${PREFIX}_compile.log"
"${QUESTA_BIN}/vmap" -modelsimini "${WORK_DIR}/modelsim.ini" altera_mf "${WORK_DIR}/altera_mf" >> "${PREFIX}_compile.log"

"${QUESTA_BIN}/vcom" -modelsimini "${WORK_DIR}/modelsim.ini" -2008 -work lpm \
    "/data1/intelFPGA/18.1/quartus/eda/sim_lib/220pack.vhd" \
    "/data1/intelFPGA/18.1/quartus/eda/sim_lib/220model.vhd" \
    >> "${PREFIX}_compile.log"

"${QUESTA_BIN}/vcom" -modelsimini "${WORK_DIR}/modelsim.ini" -2008 -work altera_mf \
    "/data1/intelFPGA/18.1/quartus/eda/sim_lib/altera_mf_components.vhd" \
    "/data1/intelFPGA/18.1/quartus/eda/sim_lib/altera_mf.vhd" \
    >> "${PREFIX}_compile.log"

"${QUESTA_BIN}/vcom" -modelsimini "${WORK_DIR}/modelsim.ini" -2008 -work work \
    "${SIM_RTL_DIR}/histogram_statistics_v2_pkg.vhd" \
    "${SIM_RTL_DIR}/true_dual_port_ram_single_clock.vhd" \
    "${SIM_RTL_DIR}/hit_fifo.vhd" \
    "${SIM_RTL_DIR}/rr_arbiter.vhd" \
    "${SIM_RTL_DIR}/bin_divider.vhd" \
    "${SIM_RTL_DIR}/coalescing_queue.vhd" \
    "${SIM_RTL_DIR}/pingpong_sram.vhd" \
    "${SIM_RTL_DIR}/histogram_statistics_v2.vhd" \
    >> "${PREFIX}_compile.log"

"${QUESTA_BIN}/vlog" -modelsimini "${WORK_DIR}/modelsim.ini" -sv -work work \
    "${TB_DIR}/tb_hist_direct_v3.sv" \
    >> "${PREFIX}_compile.log"

"${QUESTA_BIN}/vsim" -modelsimini "${WORK_DIR}/modelsim.ini" -c -work work -t ps \
    -voptargs=+acc -suppress 19 -suppress 3009 -suppress 3473 \
    tb_hist_direct_v3 \
    +CASE="${CASE}" \
    +RUN_CYCLES="${RUN_CYCLES}" \
    +INTERVAL_CYCLES="${INTERVAL_CYCLES}" \
    +SEED="${SEED:-20260517}" \
    +REPORT_PREFIX="${PREFIX}" \
    -do "quietly set NumericStdNoWarnings 1; quietly set StdArithNoWarnings 1; run -all; quit -f" \
    | tee "${PREFIX}_transcript.log"

if grep -Eq "CASE_FAIL|\\*\\* Fatal|Errors: [1-9][0-9]*" "${PREFIX}_transcript.log"; then
    echo "tb_hist_direct_v3 failed; see ${PREFIX}_transcript.log" >&2
    exit 1
fi

if [[ -e "${STABLE_SUMMARY}" ]]; then
    mv "${STABLE_SUMMARY}" "${STABLE_SUMMARY}.${STAMP}.bak"
fi
cp "${PREFIX}_summary.csv" "${STABLE_SUMMARY}"
if [[ -n "${STABLE_DELAY_BINS:-}" ]]; then
    if [[ -e "${STABLE_DELAY_BINS}" ]]; then
        mv "${STABLE_DELAY_BINS}" "${STABLE_DELAY_BINS}.${STAMP}.bak"
    fi
    cp "${PREFIX}_delay_bins.csv" "${STABLE_DELAY_BINS}"
fi
if [[ -n "${STABLE_TYPE1_META:-}" ]]; then
    if [[ -e "${STABLE_TYPE1_META}" ]]; then
        mv "${STABLE_TYPE1_META}" "${STABLE_TYPE1_META}.${STAMP}.bak"
    fi
    cp "${PREFIX}_type1_meta.csv" "${STABLE_TYPE1_META}"
fi

echo "summary=${PREFIX}_summary.csv"
echo "intervals=${PREFIX}_intervals.csv"
echo "delay_bins=${PREFIX}_delay_bins.csv"
echo "type1_meta=${PREFIX}_type1_meta.csv"
echo "transcript=${PREFIX}_transcript.log"
echo "stable_summary=${STABLE_SUMMARY}"
if [[ -n "${STABLE_DELAY_BINS:-}" ]]; then
    echo "stable_delay_bins=${STABLE_DELAY_BINS}"
fi
if [[ -n "${STABLE_TYPE1_META:-}" ]]; then
    echo "stable_type1_meta=${STABLE_TYPE1_META}"
fi
