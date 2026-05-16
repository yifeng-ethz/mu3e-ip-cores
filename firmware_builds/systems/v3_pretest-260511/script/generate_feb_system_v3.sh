#!/bin/bash
set -eu
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
ROOT="${MU3E_IP_CORES_ROOT:-${DEFAULT_ROOT}}"
SYN_DIR="${ROOT}/firmware_builds/systems/v3_pretest-260511/syn"
QSYS="${SYN_DIR}/feb_system_v3.qsys"
QSYS_BASENAME="feb_system_v3"
GENERATED_ROOT="${SYN_DIR}/${QSYS_BASENAME}"
OUT_DIR="${GENERATED_ROOT}/synthesis"
DEBUG_OUT_DIR="${GENERATED_ROOT}/synthesis_debug"
DEBUG_QSYS_ROOT="${GENERATED_ROOT}/qsys_debug_sources"
DEBUG_QSYS="${DEBUG_QSYS_ROOT}/${QSYS_BASENAME}.qsys"
DEBUG_TMP_ROOT="${GENERATED_ROOT}/debug_generation_tmp"
MANIFEST_SCRIPT="${ROOT}/firmware_builds/systems/v3_pretest-260511/script/feb_generated_dut_manifest.py"
QSYS_GENERATE_BIN="${QSYS_GENERATE_BIN:-/data1/intelFPGA/18.1/quartus/sopc_builder/bin/qsys-generate}"
STAMP="${QSYS_GENERATE_STAMP:-$(date +%Y%m%d_%H%M%S)}"
LOG="${SYN_DIR}/${QSYS_BASENAME}_qsys_generate_${STAMP}_isolated.console.log"
STATUS="${SYN_DIR}/${QSYS_BASENAME}_qsys_generate_${STAMP}_isolated.status"
QSYS_GENERATE_DEBUG="${QSYS_GENERATE_DEBUG:-1}"

. "${ROOT}/firmware_builds/systems/v3_pretest-260511/script/qsys_search_path.sh"

SEARCH_PATHS=""
USER_COMPONENT_PATHS=""
QSYS_SEARCH_PATH_COUNT=0
QSYS_SEARCH_PATH_SEEN=":"
qsys_collect_active_search_paths "${ROOT}"
qsys_create_isolated_user_catalog

if [ -d "${GENERATED_ROOT}" ]; then
    chmod -R u+w "${GENERATED_ROOT}"
    if [ "${QSYS_GENERATE_CLEAN:-1}" != "0" ]; then
        rm -rf "${GENERATED_ROOT}"
    fi
fi
if [ -f "${SYN_DIR}/${QSYS_BASENAME}.sopcinfo" ]; then
    chmod u+w "${SYN_DIR}/${QSYS_BASENAME}.sopcinfo"
fi
mkdir -p "${OUT_DIR}"

{
    printf 'qsys-generate input: %s\n' "${QSYS}"
    printf 'qsys-generate output-directory: %s\n' "${GENERATED_ROOT}"
    printf 'qsys-generate synthesis-directory: %s\n' "${OUT_DIR}"
    printf 'qsys-generate synthesis-debug-directory: %s\n' "${DEBUG_OUT_DIR}"
    printf 'qsys-generate emit-debug-tree: %s\n' "${QSYS_GENERATE_DEBUG}"
    printf 'qsys-generate search-path-count: %s\n' "${QSYS_SEARCH_PATH_COUNT}"
    printf 'qsys-generate isolated-catalog: %s\n' "${QSYS_USER_CATALOG_ROOT}"
    printf 'qsys-generate excluded: firmware_builds/systems/*/syn, system_20260427_testplanphase5, and stale run-control hit_stack_system references\n'
    printf 'qsys-generate search-path: %s,$\n' "${SEARCH_PATHS}"
    printf '\n'
} > "${LOG}"

run_qsys_generate() {
    local input_qsys="$1"
    local output_root="$2"
    local search_paths="$3"
    local label="$4"
    local local_log="$5"

    {
        printf '\n[%s] qsys-generate input: %s\n' "${label}" "${input_qsys}"
        printf '[%s] qsys-generate output-directory: %s\n' "${label}" "${output_root}"
    } >> "${local_log}"

    set +e
    "${QSYS_GENERATE_BIN}" \
        "${input_qsys}" \
        --synthesis=VHDL \
        --output-directory="${output_root}" \
        --family="Arria V" \
        --part=5AGXBA7D4F31C5 \
        --search-path="${search_paths},\$" >> "${local_log}" 2>&1
    local qsys_exit=$?
    set -e
    return "${qsys_exit}"
}

set +e
run_qsys_generate "${QSYS}" "${GENERATED_ROOT}" "${SEARCH_PATHS}" "synthesis" "${LOG}"
exit_code=$?
set -e
debug_exit_code=0

if [ "${exit_code}" -eq 0 ]; then
    python3 "${MANIFEST_SCRIPT}" write \
        --variant synthesis \
        --dut-dir "${OUT_DIR}" \
        --qsys "${QSYS}" >> "${LOG}" 2>&1
fi

if [ "${exit_code}" -eq 0 ] && [ "${QSYS_GENERATE_DEBUG}" != "0" ]; then
    rm -rf "${DEBUG_QSYS_ROOT}" "${DEBUG_TMP_ROOT}" "${DEBUG_OUT_DIR}"
    python3 "${MANIFEST_SCRIPT}" make-debug-qsys-tree \
        --root "${ROOT}" \
        --top-qsys "${QSYS}" \
        --out-dir "${DEBUG_QSYS_ROOT}" \
        --debug-level 2 >> "${LOG}" 2>&1

    DEBUG_SEARCH_PATHS="${DEBUG_QSYS_ROOT},${DEBUG_QSYS_ROOT}/quartus_systems"
    if [ -n "${SEARCH_PATHS}" ]; then
        DEBUG_SEARCH_PATHS="${DEBUG_SEARCH_PATHS},${SEARCH_PATHS}"
    fi

    set +e
    run_qsys_generate "${DEBUG_QSYS}" "${DEBUG_TMP_ROOT}" "${DEBUG_SEARCH_PATHS}" "synthesis_debug" "${LOG}"
    debug_exit_code=$?
    set -e

    if [ "${debug_exit_code}" -eq 0 ]; then
        rm -rf "${DEBUG_OUT_DIR}"
        mv "${DEBUG_TMP_ROOT}/synthesis" "${DEBUG_OUT_DIR}"
        if [ -f "${DEBUG_TMP_ROOT}/${QSYS_BASENAME}.sopcinfo" ]; then
            cp "${DEBUG_TMP_ROOT}/${QSYS_BASENAME}.sopcinfo" "${GENERATED_ROOT}/${QSYS_BASENAME}_debug.sopcinfo"
        fi
        if [ -f "${DEBUG_TMP_ROOT}/${QSYS_BASENAME}_generation.rpt" ]; then
            cp "${DEBUG_TMP_ROOT}/${QSYS_BASENAME}_generation.rpt" "${GENERATED_ROOT}/${QSYS_BASENAME}_debug_generation.rpt"
        fi
        python3 "${MANIFEST_SCRIPT}" write \
            --variant synthesis_debug \
            --dut-dir "${DEBUG_OUT_DIR}" \
            --qsys "${DEBUG_QSYS}" >> "${LOG}" 2>&1
    fi
fi

error_count="$(grep -c ' Error:' "${LOG}" || true)"
if [ "${exit_code}" -ne 0 ]; then
    final_exit_code="${exit_code}"
elif [ "${debug_exit_code}" -ne 0 ]; then
    final_exit_code="${debug_exit_code}"
else
    final_exit_code=0
fi

{
    printf 'command=%s %s --synthesis=VHDL --output-directory=%s --family=Arria V --part=5AGXBA7D4F31C5 --search-path=<%s paths>,$\n' "${QSYS_GENERATE_BIN}" "${QSYS}" "${GENERATED_ROOT}" "${QSYS_SEARCH_PATH_COUNT}"
    printf 'exit_code=%s\n' "${exit_code}"
    printf 'debug_exit_code=%s\n' "${debug_exit_code}"
    printf 'final_exit_code=%s\n' "${final_exit_code}"
    printf 'error_count=%s\n' "${error_count}"
    printf 'log=%s\n' "${LOG}"
    printf 'report=%s\n' "${GENERATED_ROOT}/${QSYS_BASENAME}_generation.rpt"
    printf 'manifest=%s\n' "${OUT_DIR}/.qsys_dut_manifest.json"
    printf 'debug_report=%s\n' "${GENERATED_ROOT}/${QSYS_BASENAME}_debug_generation.rpt"
    printf 'debug_manifest=%s\n' "${DEBUG_OUT_DIR}/.qsys_dut_manifest.json"
    printf 'isolated_catalog=%s\n' "${QSYS_USER_CATALOG_ROOT}"
} > "${STATUS}"

if [ "${final_exit_code}" -eq 0 ]; then
    if [ -d "${OUT_DIR}" ]; then
        chmod -R a-w "${OUT_DIR}"
    fi
    if [ -d "${DEBUG_OUT_DIR}" ]; then
        chmod -R a-w "${DEBUG_OUT_DIR}"
    fi
    find "${GENERATED_ROOT}" -maxdepth 1 \( -name '*.qsys' -o -name '*.sopcinfo' \) -exec chmod a-w {} +
    find "${SYN_DIR}" -maxdepth 1 -name "${QSYS_BASENAME}.sopcinfo" -exec chmod a-w {} +
fi

exit "${final_exit_code}"
