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

assert_feb_nshd_128() {
    local guard_log="${QSYS_DIR}/${QSYS_BASE}_nshd128_guard_${STAMP}.log"
    local files=()
    local candidate

    for candidate in \
        "${QSYS}" \
        "${SYSTEM_DIR}/quartus_systems"/hit_stack_system*.qsys \
        "${ROOT}/quartus_systems"/hit_stack_system*.qsys; do
        [ -f "${candidate}" ] || continue
        files+=("$(realpath -- "${candidate}")")
    done

    : > "${guard_log}"
    [ "${#files[@]}" -gt 0 ] || return 0
    if ! awk '
        /<parameter name="N_SHD"/ {
            if ($0 !~ /value="128"/) {
                printf "%s:%d:%s\n", FILENAME, FNR, $0
                bad = 1
            }
        }
        END { exit bad ? 1 : 0 }
    ' "${files[@]}" > "${guard_log}"; then
        echo "ERROR: FEB Qsys N_SHD guard failed; all FEB frame/rbCAM N_SHD parameters must be 128." >&2
        cat "${guard_log}" >&2
        exit 1
    fi
}

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

find_free_xvfb_display() {
    local n="${QSYS_GUI_XVFB_DISPLAY:-99}"

    while [ "${n}" -lt 200 ]; do
        if [ -e "/tmp/.X${n}-lock" ]; then
            local lock_pid
            lock_pid="$(cat "/tmp/.X${n}-lock" 2>/dev/null | tr -d '[:space:]' || true)"
            if [ -n "${lock_pid}" ] && ! kill -0 "${lock_pid}" 2>/dev/null; then
                rm -f -- "/tmp/.X${n}-lock"
            fi
        fi
        if [ ! -e "/tmp/.X${n}-lock" ]; then
            printf ':%s\n' "${n}"
            return 0
        fi
        n=$((n + 1))
    done
    return 1
}

launch_qsys_edit_attempt() {
    local mode="$1"
    local display_name="$2"
    local java_options="$3"
    local log="$4"
    local pidfile="$5"

    {
        printf 'DISPLAY=%s\n' "${DISPLAY:-}"
        printf 'QSYS_GUI_DISPLAY=%s\n' "${display_name}"
        printf 'XAUTHORITY=%s\n' "${XAUTHORITY:-}"
        printf '_JAVA_OPTIONS=%s\n' "${java_options}"
        printf 'GUI_MODE=%s\n' "${mode}"
        printf 'QSYS=%s\n' "${QSYS}"
        printf 'SEARCH_PATH_COUNT=%s\n' "${QSYS_SEARCH_PATH_COUNT}"
        printf 'LAUNCH_TIME=%s\n' "$(date -Iseconds)"
        export DISPLAY="${display_name}"
        export _JAVA_OPTIONS="${java_options}"
        "${QSYS_EDIT_BIN}" \
            --search-path="${SEARCH_PATHS},\$" \
            --family="Arria V" \
            --part=5AGXBA7D4F31C5 \
            --project-directory="${QSYS_DIR}" \
            "${QSYS}"
    } > "${log}" 2>&1 &
    printf '%s\n' "$!" > "${pidfile}"
}

qsys_gui_error_count() {
    local log="$1"

    grep -Ei -c '(^|[[:space:]])(Error:|Exception|AWTError|Can.t connect|No protocol specified|X11)' "${log}" || true
}

launch_qsys_gui_background() {
    local log="${QSYS_DIR}/${QSYS_BASE}_qsys_edit_${STAMP}.log"
    local pidfile="${QSYS_DIR}/${QSYS_BASE}_qsys_edit_${STAMP}.pid"
    local status="${QSYS_DIR}/${QSYS_BASE}_qsys_edit_${STAMP}.status"
    local exit_code=0
    local error_count=0
    local initial_exit_code=0
    local initial_error_count=0
    local initial_log="${log}"
    local initial_pidfile="${pidfile}"
    local gui_mode="x11"
    local gui_display="${QSYS_GUI_DISPLAY:-${DISPLAY:-}}"
    local java_options="${_JAVA_OPTIONS:-}"
    local xvfb_display=""
    local xvfb_server_pidfile="${QSYS_DIR}/${QSYS_BASE}_qsys_edit_${STAMP}_xvfb_server.pid"
    local xvfb_log="${QSYS_DIR}/${QSYS_BASE}_qsys_edit_${STAMP}_xvfb_server.log"
    local xvfb_pid=""

    case "${gui_display}" in
        localhost:*)
            gui_display="127.0.0.1:${gui_display#localhost:}"
            ;;
    esac
    case " ${java_options} " in
        *" -Dsun.java2d.xrender="*) ;;
        *) java_options="${java_options} -Dsun.java2d.xrender=false" ;;
    esac
    case " ${java_options} " in
        *" -Djava.net.preferIPv4Stack="*) ;;
        *) java_options="${java_options} -Djava.net.preferIPv4Stack=true" ;;
    esac
    java_options="${java_options# }"

    launch_qsys_edit_attempt "${gui_mode}" "${gui_display}" "${java_options}" "${log}" "${pidfile}"

    sleep "${QSYS_GUI_CHECK_DELAY:-5}"
    if ! kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
        set +e
        wait "$(cat "${pidfile}")"
        exit_code=$?
        set -e
        error_count="$(qsys_gui_error_count "${log}")"
        initial_exit_code="${exit_code}"
        initial_error_count="${error_count}"
        echo "WARNING: qsys-edit GUI exited early for ${QSYS_BASE}; exit=${exit_code}, errors=${error_count}; see ${log}" >&2

        if [ "${QSYS_GUI_XVFB_FALLBACK:-1}" != "0" ] \
            && command -v Xvfb >/dev/null 2>&1 \
            && grep -Eiq '(AWTError|Can.t connect|No protocol specified|X11)' "${log}"; then
            xvfb_display="$(find_free_xvfb_display || true)"
            if [ -n "${xvfb_display}" ]; then
                Xvfb "${xvfb_display}" \
                    -screen 0 "${QSYS_GUI_XVFB_SCREEN:-1920x1200x24}" \
                    -nolisten tcp > "${xvfb_log}" 2>&1 &
                xvfb_pid="$!"
                printf '%s\n' "${xvfb_pid}" > "${xvfb_server_pidfile}"
                sleep "${QSYS_GUI_XVFB_DELAY:-2}"
                if kill -0 "${xvfb_pid}" 2>/dev/null; then
                    gui_mode="xvfb"
                    log="${QSYS_DIR}/${QSYS_BASE}_qsys_edit_${STAMP}_xvfb.log"
                    pidfile="${QSYS_DIR}/${QSYS_BASE}_qsys_edit_${STAMP}_xvfb.pid"
                    exit_code=0
                    error_count=0
                    echo "INFO: retrying qsys-edit GUI for ${QSYS_BASE} under Xvfb display ${xvfb_display}" >&2
                    launch_qsys_edit_attempt "${gui_mode}" "${xvfb_display}" "${java_options}" "${log}" "${pidfile}"
                    sleep "${QSYS_GUI_CHECK_DELAY:-5}"
                    if ! kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
                        set +e
                        wait "$(cat "${pidfile}")"
                        exit_code=$?
                        set -e
                        error_count="$(qsys_gui_error_count "${log}")"
                        gui_mode="xvfb-failed"
                        echo "WARNING: qsys-edit Xvfb retry exited early for ${QSYS_BASE}; exit=${exit_code}, errors=${error_count}; see ${log}" >&2
                        kill "${xvfb_pid}" 2>/dev/null || true
                    fi
                else
                    gui_mode="xvfb-server-failed"
                    error_count=$((error_count + 1))
                    echo "WARNING: Xvfb failed to start for qsys-edit GUI; see ${xvfb_log}" >&2
                fi
            else
                gui_mode="xvfb-no-display"
                error_count=$((error_count + 1))
                echo "WARNING: no free Xvfb display found for qsys-edit GUI retry" >&2
            fi
        fi
    fi
    {
        printf 'qsys=%s\n' "${QSYS}"
        printf 'pid=%s\n' "$(cat "${pidfile}")"
        printf 'log=%s\n' "${log}"
        printf 'gui_mode=%s\n' "${gui_mode}"
        printf 'display=%s\n' "${gui_display}"
        printf 'xvfb_display=%s\n' "${xvfb_display}"
        printf 'xvfb_pid=%s\n' "${xvfb_pid}"
        printf 'xvfb_pidfile=%s\n' "${xvfb_server_pidfile}"
        printf 'xvfb_log=%s\n' "${xvfb_log}"
        printf 'initial_pid=%s\n' "$(cat "${initial_pidfile}")"
        printf 'initial_log=%s\n' "${initial_log}"
        printf 'initial_early_exit_code=%s\n' "${initial_exit_code}"
        printf 'initial_early_error_count=%s\n' "${initial_error_count}"
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
assert_feb_nshd_128
validate_qsys 0
launch_qsys_gui_background
run_qsys_generate synthesis 0

set_arb_source_debug_level 2
set_qsys_debug_level 2
assert_feb_nshd_128
validate_qsys 2
run_qsys_generate simulation 2

set_arb_source_debug_level 0
set_qsys_debug_level 0
