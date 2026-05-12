#!/bin/bash
set -eu
export LC_ALL=C

ROOT="${MU3E_IP_CORES_ROOT:-/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores}"
SYSTEM_DIR="${ROOT}/firmware_builds/systems/v3_pretest-260511-pulserdrop-260512"
TCL="${SYSTEM_DIR}/script/add_mclk125_reset_bridge_v3.tcl"
LOG="${SYSTEM_DIR}/syn/feb_system_v3_mclk125_reset_bridge_qsys_script.log"

SEARCH_PATHS=""
USER_COMPONENT_PATHS=""
QSYS_SEARCH_PATH_COUNT=0
QSYS_SEARCH_PATH_SEEN=":"

. "${SYSTEM_DIR}/script/qsys_search_path.sh"

qsys_collect_active_search_paths "${ROOT}"
qsys_create_isolated_user_catalog

run_qsys_update() {
    local qsys="$1"

    [ -f "${qsys}" ] || return 0

    chmod u+w "${qsys}"
    qsys-script \
        --system-file="${qsys}" \
        --search-path="${SEARCH_PATHS},\$" \
        --cmd="set ::qsys_target {${qsys}}" \
        --script="${TCL}"
}

{
    printf 'mclk125 reset bridge qsys-script log\n'
    printf 'root=%s\n' "${ROOT}"
    printf 'search_path_count=%s\n' "${QSYS_SEARCH_PATH_COUNT}"
    printf 'isolated_catalog=%s\n' "${QSYS_USER_CATALOG_ROOT}"
    printf '\n'
} > "${LOG}"

run_qsys_update "${ROOT}/quartus_systems/scifi_datapath_system_v3.qsys" >> "${LOG}" 2>&1
run_qsys_update "${ROOT}/quartus_systems/feb_system_v3.qsys" >> "${LOG}" 2>&1
run_qsys_update "${SYSTEM_DIR}/syn/feb_system_v3.qsys" >> "${LOG}" 2>&1
