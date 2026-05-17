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
TOPOLOGY_SCRIPT="${SYSTEM_DIR}/script/update_dualport_histogram_topology.tcl"
VERSION_SCRIPT="${SYSTEM_DIR}/script/update_feb_system_v3_dualport_version.tcl"
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
    local script="$2"
    local log="$3"

    [ -f "${qsys}" ] || return 0
    chmod u+w "${qsys}" 2>/dev/null || true
    qsys-script \
        --system-file="${qsys}" \
        --search-path="${SEARCH_PATHS},\$" \
        --script="${script}" > "${log}" 2>&1
    chmod a-w "${qsys}"
}

run_qsys_update \
    "${SYSTEM_DIR}/quartus_systems/scifi_datapath_system_v3.qsys" \
    "${TOPOLOGY_SCRIPT}" \
    "${SYSTEM_DIR}/quartus_systems/scifi_datapath_system_v3_dualport_hist_qsys_script.log"

run_qsys_update \
    "${SYSTEM_DIR}/quartus_systems/scifi_datapath_system_v3_pipe.qsys" \
    "${TOPOLOGY_SCRIPT}" \
    "${SYSTEM_DIR}/quartus_systems/scifi_datapath_system_v3_pipe_dualport_hist_qsys_script.log"

qsys-script \
    --cmd="set ::env(SYSTEM_DIR) {${SYSTEM_DIR}}" \
    --script="${VERSION_SCRIPT}" > "${SYSTEM_DIR}/syn/feb_system_v3_dualport_version_qsys_script.log" 2>&1

if [ -f "${SYSTEM_DIR}/syn/feb_system_v3.sopcinfo" ]; then
    chmod a-w "${SYSTEM_DIR}/syn/feb_system_v3.sopcinfo"
fi

if [ -d "${SYSTEM_DIR}/syn/feb_system_v3/synthesis" ]; then
    chmod -R a-w "${SYSTEM_DIR}/syn/feb_system_v3/synthesis"
fi
