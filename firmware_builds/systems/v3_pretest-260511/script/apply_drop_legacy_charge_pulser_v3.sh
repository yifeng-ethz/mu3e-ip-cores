#!/bin/bash
set -eu
export LC_ALL=C

ROOT="${MU3E_IP_CORES_ROOT:-/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores}"
SYSTEM_DIR="${ROOT}/firmware_builds/systems/v3_pretest-260511"
TCL="${SYSTEM_DIR}/script/drop_legacy_charge_pulser_v3.tcl"
STAMP="${QSYS_DROP_STAMP:-$(date +%Y%m%d_%H%M%S)}"
LOG="${SYSTEM_DIR}/syn/feb_system_v3_drop_legacy_charge_pulser_${STAMP}.qsys_script.log"

SEARCH_PATHS=""
USER_COMPONENT_PATHS=""
QSYS_SEARCH_PATH_COUNT=0
QSYS_SEARCH_PATH_SEEN=":"

. "${SYSTEM_DIR}/script/qsys_search_path.sh"

qsys_collect_active_search_paths "${ROOT}"
qsys_create_isolated_user_catalog

run_qsys_update() {
    local role="$1"
    local qsys="$2"

    chmod u+w "${qsys}"
    qsys-script \
        --system-file="${qsys}" \
        --search-path="${SEARCH_PATHS},\$" \
        --cmd="set ::qsys_drop_role {${role}}; set ::qsys_target {${qsys}}" \
        --script="${TCL}" >> "${LOG}" 2>&1
}

{
    printf 'drop legacy charge pulser qsys-script log\n'
    printf 'search-path-count=%s\n' "${QSYS_SEARCH_PATH_COUNT}"
    printf 'isolated-catalog=%s\n' "${QSYS_USER_CATALOG_ROOT}"
    printf '\n'
} > "${LOG}"

run_qsys_update debug_sc "${ROOT}/quartus_systems/debug_sc_system_v3.qsys"
run_qsys_update feb "${ROOT}/quartus_systems/feb_system_v3.qsys"

chmod a-w \
    "${ROOT}/quartus_systems/debug_sc_system_v3.qsys" \
    "${ROOT}/quartus_systems/feb_system_v3.qsys"
