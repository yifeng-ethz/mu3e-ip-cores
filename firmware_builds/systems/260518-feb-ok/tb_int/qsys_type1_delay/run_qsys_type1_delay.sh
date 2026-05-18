#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(realpath -m -- "${SCRIPT_DIR}/../..")"
REPO_ROOT="$(realpath -m -- "${SYSTEM_DIR}/../../..")"
LEGACY_TB_INT="${REPO_ROOT}/firmware_builds/systems/v3_pretest-260511/tb_int"
QSYS_QIP="${SYSTEM_DIR}/quartus_systems/scifi_datapath_system_v3/simulation/scifi_datapath_system_v3.qip"
REPORT_DIR="${SYSTEM_DIR}/tb_int/REPORT/qsys_type1_delay"
STAMP="${STAMP:-$(date +%Y%m%d_%H%M%S)}"
RUN_SET="${RUN_SET:-all}"
SOURCES="${SOURCES:-type1_up type1_down}"
EXTRA_VSIM_ARGS="${EXTRA_VSIM_ARGS:-}"

find_questa_home() {
    local candidates=()
    if [[ -n "${QUESTA_HOME:-}" ]]; then
        candidates+=("${QUESTA_HOME}")
    fi
    candidates+=(
        /data1/questaone_sim-2026.1_1/questasim
        /data1/questaone_sim/questasim
        /data1/questasim
    )
    for candidate in "${candidates[@]}"; do
        if [[ -x "${candidate}/linux_x86_64/vsim" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done
    echo "Questa vsim not found; set QUESTA_HOME" >&2
    return 1
}

append_csv() {
    local src="$1"
    local dst="$2"
    if [[ ! -s "${src}" ]]; then
        echo "missing CSV ${src}" >&2
        return 1
    fi
    if [[ ! -s "${dst}" ]]; then
        cp "${src}" "${dst}"
    else
        tail -n +2 "${src}" >> "${dst}"
    fi
}

stage_qip_source_files() {
    local qip="$1"
    local dst="$2"

    python3 - "${qip}" "${dst}" <<'PY'
import re
import shutil
import sys
from pathlib import Path

qip = Path(sys.argv[1]).resolve()
dst = Path(sys.argv[2]).resolve()
qip_dir = qip.parent
assign_re = re.compile(
    r'-name\s+SOURCE_FILE\s+\[file join \$::quartus\(qip_path\) "([^"]+)"\]'
)
for line in qip.read_text(encoding="utf-8", errors="replace").splitlines():
    match = assign_re.search(line)
    if not match:
        continue
    src = qip_dir / match.group(1)
    if not src.is_file():
        raise SystemExit(f"missing QIP SOURCE_FILE asset: {src}")
    target = dst / src.name
    if target.exists():
        raise SystemExit(f"refusing to overwrite staged QIP asset: {target}")
    shutil.copy2(src, target)
    target.chmod(0o600)
    print(f"QSYS_TYPE1_DELAY_SOURCE_FILE {src} -> {target}")
PY
}

case_list() {
    local source="$1"
    case "${RUN_SET}" in
        smoke)
            printf '%s periodic 100000\n' "${source}"
            ;;
        periodic)
            printf '%s periodic 10000\n' "${source}"
            printf '%s periodic 100000\n' "${source}"
            printf '%s periodic 500000\n' "${source}"
            printf '%s periodic 1000000\n' "${source}"
            ;;
        header_sync)
            printf '%s header_sync 0\n' "${source}"
            ;;
        all)
            printf '%s periodic 10000\n' "${source}"
            printf '%s periodic 100000\n' "${source}"
            printf '%s periodic 500000\n' "${source}"
            printf '%s periodic 1000000\n' "${source}"
            printf '%s header_sync 0\n' "${source}"
            ;;
        *)
            echo "unknown RUN_SET=${RUN_SET}; use smoke, periodic, header_sync, or all" >&2
            return 2
            ;;
    esac
}

QUESTA_HOME="$(find_questa_home)"
export QUESTA_HOME
ETH_LIC_SERVER="${ETH_LIC_SERVER:-8161@lic-mentor.ethz.ch}"
export LM_LICENSE_FILE="${QSYS_TYPE1_LM_LICENSE_FILE:-${ETH_LIC_SERVER}}"
export MGLS_LICENSE_FILE="${QSYS_TYPE1_MGLS_LICENSE_FILE:-${ETH_LIC_SERVER}}"
export SALT_LICENSE_SERVER="${QSYS_TYPE1_SALT_LICENSE_SERVER:-${ETH_LIC_SERVER}}"

WORK="work_qsys_type1_delay_${STAMP}"
SIM_ROOT="${REPORT_DIR}/work_${STAMP}"
AGG_SUMMARY="${REPORT_DIR}/qsys_type1_delay_${STAMP}_summary.csv"
AGG_DELAY="${REPORT_DIR}/qsys_type1_delay_${STAMP}_delay_bins.csv"
AGG_META="${REPORT_DIR}/qsys_type1_delay_${STAMP}_type1_meta.csv"
TB_SV="${SCRIPT_DIR}/tb_qsys_type1_delay_v3.sv"
VLOG="${QUESTA_HOME}/linux_x86_64/vlog"
VSIM="${QUESTA_HOME}/linux_x86_64/vsim"

mkdir -p "${REPORT_DIR}" "${SIM_ROOT}"
for aggregate in "${AGG_SUMMARY}" "${AGG_DELAY}" "${AGG_META}"; do
    if [[ -e "${aggregate}" ]]; then
        echo "refusing to overwrite existing aggregate: ${aggregate}" >&2
        exit 2
    fi
done

if [[ ! -f "${QSYS_QIP}" ]]; then
    echo "missing generated simulation QIP: ${QSYS_QIP}" >&2
    exit 1
fi

make -C "${LEGACY_TB_INT}" \
    QUESTA_HOME="${QUESTA_HOME}" \
    SYSTEM_ROOT="${SYSTEM_DIR}" \
    QSYS_QIP="${QSYS_QIP}" \
    SIM_ROOT="${SIM_ROOT}" \
    WORK="${WORK}" \
    comp_dut

(
    cd "${LEGACY_TB_INT}"
    "${VLOG}" -modelsimini modelsim.ini \
        -sv -work "${WORK}" -timescale 1ns/1ps +define+TB_INT_SIM \
        "${TB_SV}"
)

stage_qip_source_files "${QSYS_QIP}" "${LEGACY_TB_INT}"

while read -r source mode rate; do
    [[ -n "${source}" ]] || continue
    prefix="${REPORT_DIR}/${STAMP}_${source}_${mode}"
    if [[ "${mode}" == "periodic" ]]; then
        label="${rate}"
        prefix="${prefix}_${label}"
    else
        prefix="${prefix}_910cyc"
    fi
    log="${prefix}.log"
    echo "QSYS_TYPE1_DELAY_RUN source=${source} mode=${mode} rate=${rate} prefix=${prefix}"
    (
        cd "${LEGACY_TB_INT}"
        "${VSIM}" -modelsimini modelsim.ini \
            -c -suppress 19 -suppress 3009 -nodpiexports \
            -L lpm -work "${WORK}" -voptargs=+acc tb_qsys_type1_delay_v3 \
            +REPORT_PREFIX="${prefix}" \
            +SOURCE="${source}" \
            +CASE_MODE="${mode}" \
            +RATE_HZ="${rate}" \
            ${EXTRA_VSIM_ARGS} \
            -l "${log}" \
            -do "run -all; quit -f"
    )
    rg "\\*\\*\\* TEST PASSED \\*\\*\\*" "${log}" >/dev/null
    append_csv "${prefix}_summary.csv" "${AGG_SUMMARY}"
    append_csv "${prefix}_delay_bins.csv" "${AGG_DELAY}"
    append_csv "${prefix}_type1_meta.csv" "${AGG_META}"
done < <(
    for source in ${SOURCES}; do
        case_list "${source}"
    done
)

echo "QSYS_TYPE1_DELAY_PASS summary=${AGG_SUMMARY} delay_bins=${AGG_DELAY} meta=${AGG_META}"

if [[ "${RUN_SET}" == "periodic" || "${RUN_SET}" == "all" ]]; then
    for source in ${SOURCES}; do
        TYPE1_META_CSV="${AGG_META}" \
            "${SYSTEM_DIR}/tb_int/hist_dualport/render_type1_delay_dislin.sh" \
            "${AGG_DELAY}" \
            "${AGG_SUMMARY}" \
            "${source}" \
            "qsys_periodic" \
            "${REPORT_DIR}/qsys_type1_delay_${STAMP}_${source}_qsys_periodic"
    done
fi

if [[ "${RUN_SET}" == "header_sync" || "${RUN_SET}" == "all" ]]; then
    for source in ${SOURCES}; do
        TYPE1_META_CSV="${AGG_META}" \
            "${SYSTEM_DIR}/tb_int/hist_dualport/render_type1_header_sync_dislin.sh" \
            "${AGG_DELAY}" \
            "${AGG_SUMMARY}" \
            "${source}" \
            "${REPORT_DIR}/qsys_type1_delay_${STAMP}_${source}_qsys_header_sync_910cyc"
    done
fi
