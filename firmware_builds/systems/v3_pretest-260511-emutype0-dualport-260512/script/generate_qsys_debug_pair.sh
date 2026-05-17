#!/bin/bash
set -eu
export LC_ALL=C

QSYS="${1:?usage: generate_qsys_debug_pair.sh <system.qsys>}"
QSYS="$(realpath -- "${QSYS}")"
QSYS_DIR="$(dirname -- "${QSYS}")"
QSYS_BASE="$(basename -- "${QSYS}" .qsys)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(realpath -m -- "${SCRIPT_DIR}/..")"
ROOT="${MU3E_IP_CORES_ROOT:-$(realpath -m -- "${SYSTEM_DIR}/../../..")}"
export SYSTEM_DIR
export MU3E_IP_CORES_ROOT="${ROOT}"

QSYS_GENERATE_BIN="${QSYS_GENERATE_BIN:-/data1/intelFPGA/18.1/quartus/sopc_builder/bin/qsys-generate}"
QSYS_SCRIPT_BIN="${QSYS_SCRIPT_BIN:-/data1/intelFPGA/18.1/quartus/sopc_builder/bin/qsys-script}"
QSYS_EDIT_BIN="${QSYS_EDIT_BIN:-/data1/intelFPGA/18.1/quartus/sopc_builder/bin/qsys-edit}"
STAMP="${QSYS_GENERATE_STAMP:-$(date +%Y%m%d_%H%M%S)}"
SET_DEBUG_SCRIPT="${SYSTEM_DIR}/script/set_qsys_debug_level.tcl"
ARB_BUILD_SCRIPT="${SYSTEM_DIR}/script/build_arb_hit_type0_supercore_qsys.tcl"
TOP_PATCH_SCRIPT="${SYSTEM_DIR}/script/update_feb_system_v3_dualport_version.tcl"

. "${SYSTEM_DIR}/script/qsys_search_path.sh"

SEARCH_PATHS=""
USER_COMPONENT_PATHS=""
QSYS_SEARCH_PATH_COUNT=0
QSYS_SEARCH_PATH_SEEN=":"
qsys_collect_active_search_paths "${ROOT}"
qsys_append_search_path "${QSYS_DIR}"
qsys_create_isolated_user_catalog

GENERATED_DIR="${QSYS_DIR}/${QSYS_BASE}"
SYNTHESIS_DIR="${GENERATED_DIR}/synthesis"
SIMULATION_DIR="${GENERATED_DIR}/simulation"

run_top_patch_if_needed() {
    if [ "${QSYS_BASE}" = "feb_system_v3" ] && [ -f "${TOP_PATCH_SCRIPT}" ]; then
        "${QSYS_SCRIPT_BIN}" \
            --cmd="set ::env(SYSTEM_DIR) {${SYSTEM_DIR}}; set ::system_dir {${SYSTEM_DIR}}" \
            --script="${TOP_PATCH_SCRIPT}" \
            > "${QSYS_DIR}/${QSYS_BASE}_top_patch_qsys_script_${STAMP}.log" 2>&1
    fi
}

set_arb_source_debug_level() {
    local debug_level="$1"
    local arb_qsys="${SYSTEM_DIR}/quartus_systems/arb_hit_type0_supercore.qsys"

    [ -f "${ARB_BUILD_SCRIPT}" ] || return 0
    [ -f "${arb_qsys}" ] || return 0
    chmod u+w "${arb_qsys}" 2>/dev/null || true
    "${QSYS_SCRIPT_BIN}" \
        --search-path="${SEARCH_PATHS},\$" \
        --cmd="set ::system_dir {${SYSTEM_DIR}}; set ::debug_level {${debug_level}}; set ::env(SYSTEM_DIR) {${SYSTEM_DIR}}; set ::env(DEBUG_LEVEL) {${debug_level}}" \
        --script="${ARB_BUILD_SCRIPT}" \
        > "${SYSTEM_DIR}/quartus_systems/arb_hit_type0_supercore_debug${debug_level}_build_${STAMP}.log" 2>&1
    chmod a-w "${arb_qsys}" 2>/dev/null || true
}

set_qsys_debug_level() {
    local debug_level="$1"
    local log="${QSYS_DIR}/${QSYS_BASE}_set_debug${debug_level}_${STAMP}.log"

    chmod u+w "${QSYS}" 2>/dev/null || true
    "${QSYS_SCRIPT_BIN}" \
        --system-file="${QSYS}" \
        --search-path="${SEARCH_PATHS},\$" \
        --cmd="set ::debug_level {${debug_level}}" \
        --script="${SET_DEBUG_SCRIPT}" \
        > "${log}" 2>&1
    chmod a-w "${QSYS}" 2>/dev/null || true
}

validate_qsys() {
    local debug_level="$1"
    local log="${QSYS_DIR}/${QSYS_BASE}_qsys_validate_${STAMP}_debug${debug_level}.console.log"
    local status="${QSYS_DIR}/${QSYS_BASE}_qsys_validate_${STAMP}_debug${debug_level}.status"
    local exit_code error_count

    set +e
    "${QSYS_SCRIPT_BIN}" \
        --system-file="${QSYS}" \
        --search-path="${SEARCH_PATHS},\$" \
        --cmd="package require -exact qsys 18.1; validate_system" > "${log}" 2>&1
    exit_code=$?
    set -e
    error_count="$(grep -c ' Error:' "${log}" || true)"
    {
        printf 'qsys=%s\n' "${QSYS}"
        printf 'debug_level=%s\n' "${debug_level}"
        printf 'exit_code=%s\n' "${exit_code}"
        printf 'error_count=%s\n' "${error_count}"
        printf 'log=%s\n' "${log}"
        printf 'search_path_count=%s\n' "${QSYS_SEARCH_PATH_COUNT}"
        printf 'isolated_catalog=%s\n' "${QSYS_USER_CATALOG_ROOT}"
    } > "${status}"
    if [ "${exit_code}" -ne 0 ] || [ "${error_count}" -ne 0 ]; then
        echo "WARNING: qsys-script validate_system reported errors for ${QSYS_BASE} DEBUG_LEVEL=${debug_level}; see ${log}" >&2
    fi
}

launch_qsys_gui_background() {
    local log="${QSYS_DIR}/${QSYS_BASE}_qsys_edit_${STAMP}.log"
    local pidfile="${QSYS_DIR}/${QSYS_BASE}_qsys_edit_${STAMP}.pid"
    local status="${QSYS_DIR}/${QSYS_BASE}_qsys_edit_${STAMP}.status"
    local exit_code=0
    local error_count=0

    {
        printf 'DISPLAY=%s\n' "${DISPLAY:-}"
        printf 'XAUTHORITY=%s\n' "${XAUTHORITY:-}"
        printf 'QSYS=%s\n' "${QSYS}"
        printf 'SEARCH_PATH_COUNT=%s\n' "${QSYS_SEARCH_PATH_COUNT}"
        printf 'LAUNCH_TIME=%s\n' "$(date -Iseconds)"
        export _JAVA_OPTIONS="${_JAVA_OPTIONS:--Dsun.java2d.xrender=false}"
        "${QSYS_EDIT_BIN}" \
            --search-path="${SEARCH_PATHS},\$" \
            --family="Arria V" \
            --part=5AGXBA7D4F31C5 \
            --project-directory="${QSYS_DIR}" \
            "${QSYS}"
    } > "${log}" 2>&1 &
    printf '%s\n' "$!" > "${pidfile}"

    sleep "${QSYS_GUI_CHECK_DELAY:-5}"
    if ! kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
        set +e
        wait "$(cat "${pidfile}")"
        exit_code=$?
        set -e
        error_count="$(grep -Ei -c '(^|[[:space:]])(Error:|Exception|AWTError|Can.t connect|No protocol specified)' "${log}" || true)"
        echo "WARNING: qsys-edit GUI exited early for ${QSYS_BASE}; exit=${exit_code}, errors=${error_count}; see ${log}" >&2
    fi
    {
        printf 'qsys=%s\n' "${QSYS}"
        printf 'pid=%s\n' "$(cat "${pidfile}")"
        printf 'log=%s\n' "${log}"
        printf 'early_exit_code=%s\n' "${exit_code}"
        printf 'early_error_count=%s\n' "${error_count}"
    } > "${status}"
}

run_qsys_generate() {
    local target="$1"
    local debug_level="$2"
    local target_arg
    local target_dir
    local generate_dir="${GENERATED_DIR}"
    local generated_target_dir
    local log
    local status
    local exit_code
    local error_count

    if [ "${target}" = "synthesis" ]; then
        target_arg="--synthesis=VHDL"
        target_dir="${SYNTHESIS_DIR}"
        generated_target_dir="${target_dir}"
    elif [ "${target}" = "simulation" ]; then
        target_arg="--synthesis=VHDL"
        target_dir="${SIMULATION_DIR}"
        generate_dir="${GENERATED_DIR}/.simulation_debug${debug_level}_gen"
        generated_target_dir="${generate_dir}/synthesis"
    else
        echo "ERROR: unsupported Qsys target ${target}" >&2
        exit 2
    fi

    if [ -d "${target_dir}" ]; then
        chmod -R u+w "${target_dir}"
    fi
    if [ "${target}" = "simulation" ] && [ -d "${generate_dir}" ]; then
        chmod -R u+w "${generate_dir}"
        rm -rf -- "${generate_dir}"
    fi
    if [ -f "${QSYS_DIR}/${QSYS_BASE}.sopcinfo" ]; then
        chmod u+w "${QSYS_DIR}/${QSYS_BASE}.sopcinfo"
    fi
    mkdir -p "${target_dir}" "${generate_dir}"
    log="${QSYS_DIR}/${QSYS_BASE}_qsys_generate_${STAMP}_${target}_debug${debug_level}.console.log"
    status="${QSYS_DIR}/${QSYS_BASE}_qsys_generate_${STAMP}_${target}_debug${debug_level}.status"
    {
        printf 'qsys-generate input: %s\n' "${QSYS}"
        printf 'qsys-generate target: %s\n' "${target}"
        printf 'qsys-generate debug-level: %s\n' "${debug_level}"
        printf 'qsys-generate output-directory: %s\n' "${generate_dir}"
        printf 'qsys-generate target-directory: %s\n' "${target_dir}"
        printf 'qsys-generate generated-target-directory: %s\n' "${generated_target_dir}"
        printf 'qsys-generate search-path-count: %s\n' "${QSYS_SEARCH_PATH_COUNT}"
        printf 'qsys-generate isolated-catalog: %s\n' "${QSYS_USER_CATALOG_ROOT}"
        printf 'qsys-generate search-path: %s,$\n\n' "${SEARCH_PATHS}"
    } > "${log}"

    set +e
    "${QSYS_GENERATE_BIN}" \
        "${QSYS}" \
        "${target_arg}" \
        --output-directory="${generate_dir}" \
        --clear-output-directory \
        --family="Arria V" \
        --part=5AGXBA7D4F31C5 \
        --search-path="${SEARCH_PATHS},\$" >> "${log}" 2>&1
    exit_code=$?
    set -e

    error_count="$(grep -c ' Error:' "${log}" || true)"
    {
        printf 'command=%s %s %s --output-directory=%s --clear-output-directory --family=Arria V --part=5AGXBA7D4F31C5 --search-path=<%s paths>,$\n' "${QSYS_GENERATE_BIN}" "${QSYS}" "${target_arg}" "${generate_dir}" "${QSYS_SEARCH_PATH_COUNT}"
        printf 'exit_code=%s\n' "${exit_code}"
        printf 'error_count=%s\n' "${error_count}"
        printf 'debug_level=%s\n' "${debug_level}"
        printf 'target=%s\n' "${target}"
        printf 'log=%s\n' "${log}"
        printf 'report=%s\n' "${generate_dir}/${QSYS_BASE}_generation.rpt"
        printf 'isolated_catalog=%s\n' "${QSYS_USER_CATALOG_ROOT}"
    } > "${status}"

    if [ "${exit_code}" -ne 0 ] || [ "${error_count}" -ne 0 ]; then
        echo "ERROR: qsys-generate ${target} DEBUG_LEVEL=${debug_level} failed for ${QSYS_BASE}; see ${log}" >&2
        exit "${exit_code}"
    fi
    if [ "${target}" = "simulation" ]; then
        rm -rf -- "${target_dir}"
        mv -- "${generated_target_dir}" "${target_dir}"
        rm -rf -- "${generate_dir}"
    fi
    chmod -R a-w "${target_dir}" 2>/dev/null || true
    find "${GENERATED_DIR}" -maxdepth 1 \( -name '*.qsys' -o -name '*.sopcinfo' \) -exec chmod a-w {} + 2>/dev/null || true
    find "${QSYS_DIR}" -maxdepth 1 -name "${QSYS_BASE}.sopcinfo" -exec chmod a-w {} + 2>/dev/null || true
}

run_top_patch_if_needed

set_arb_source_debug_level 0
set_qsys_debug_level 0
validate_qsys 0
launch_qsys_gui_background
run_qsys_generate synthesis 0

set_arb_source_debug_level 2
set_qsys_debug_level 2
validate_qsys 2
run_qsys_generate simulation 2

set_arb_source_debug_level 0
set_qsys_debug_level 0
