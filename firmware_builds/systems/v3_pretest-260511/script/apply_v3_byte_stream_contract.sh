#!/bin/bash
set -eu
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
ROOT="${MU3E_IP_CORES_ROOT:-${DEFAULT_ROOT}}"
SYSTEM_DIR="${ROOT}/firmware_builds/systems/v3_pretest-260511"
TCL="${SYSTEM_DIR}/script/update_v3_byte_stream_contract.tcl"

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

    [ -f "${qsys}" ] || return 0

    QSYS_BYTE_STREAM_ROLE="${role}" \
    qsys-script \
        --system-file="${qsys}" \
        --search-path="${SEARCH_PATHS},\$" \
        --script="${TCL}"
}

for qsys in \
    "${ROOT}/quartus_systems/scifi_datapath_system_v3.qsys" \
    "${ROOT}/quartus_systems/scifi_datapath_system_v3_pipe.qsys" \
    "${ROOT}/quartus_systems/scifi_datapath_system_v3_lat4.qsys"; do
    run_qsys_update datapath "${qsys}"
done

run_qsys_update feb "${ROOT}/quartus_systems/feb_system_v3.qsys"

if [ "${APPLY_BUILD_QSYS:-0}" = "1" ]; then
    for qsys in \
        "${ROOT}/firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3.qsys" \
        "${ROOT}/firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/syn/feb_system_v3.qsys"; do
        if [ -f "${qsys}" ]; then
            chmod u+w "${qsys}" 2>/dev/null || true
            run_qsys_update feb "${qsys}"
        fi
    done
fi
