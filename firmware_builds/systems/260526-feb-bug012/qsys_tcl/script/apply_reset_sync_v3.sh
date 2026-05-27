#!/bin/bash
set -eu
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "${MU3E_IP_CORES_ROOT:-}" ]; then
    ROOT="${MU3E_IP_CORES_ROOT}"
    SYSTEM_DIR="${ROOT}/firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512"
else
    SYSTEM_DIR="$(realpath -m -- "${SCRIPT_DIR}/..")"
    ROOT="$(realpath -m -- "${SYSTEM_DIR}/../../..")"
fi
SCRIPT="${SYSTEM_DIR}/script/add_mclk125_reset_bridge_v3.tcl"
export SYSTEM_DIR

. "${SYSTEM_DIR}/script/qsys_search_path.sh"

SEARCH_PATHS=""
USER_COMPONENT_PATHS=""
QSYS_SEARCH_PATH_COUNT=0
QSYS_SEARCH_PATH_SEEN=":"
qsys_collect_active_search_paths "${ROOT}"
qsys_create_isolated_user_catalog

run_qsys_update() {
    local qsys="$1"
    local log="${qsys%.qsys}_reset_sync_qsys_script.log"
    [ -f "${qsys}" ] || return 0

    chmod u+w "${qsys}" 2>/dev/null || true
    qsys-script \
        --cmd="set ::qsys_target {${qsys}}" \
        --system-file="${qsys}" \
        --search-path="${SEARCH_PATHS},\$" \
        --script="${SCRIPT}" > "${log}" 2>&1
    chmod a-w "${qsys}"
}

run_qsys_update "${SYSTEM_DIR}/quartus_systems/scifi_datapath_system_v3.qsys"
run_qsys_update "${SYSTEM_DIR}/generated/qsys/feb_system_v3.qsys"
