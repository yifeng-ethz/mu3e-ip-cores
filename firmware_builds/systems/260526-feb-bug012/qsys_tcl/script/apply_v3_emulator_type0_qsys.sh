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
SCRIPT="${SYSTEM_DIR}/script/refactor_v3_emulator_type0_qsys.tcl"
BUILD_SUPERCORE_SCRIPT="${SYSTEM_DIR}/script/build_arb_hit_type0_supercore_qsys.tcl"
DESCRIPTION_SCRIPT="${SYSTEM_DIR}/script/update_emulator_type0_descriptions.tcl"
TOP_PATCH_SCRIPT="${SYSTEM_DIR}/script/update_feb_system_v3_dualport_version.tcl"
export SYSTEM_DIR

. "${SYSTEM_DIR}/script/qsys_search_path.sh"

SEARCH_PATHS=""
USER_COMPONENT_PATHS=""
QSYS_SEARCH_PATH_COUNT=0
QSYS_SEARCH_PATH_SEEN=":"
qsys_collect_active_search_paths "${ROOT}"
qsys_create_isolated_user_catalog

qsys-script \
    --search-path="${SEARCH_PATHS},\$" \
    --script="${BUILD_SUPERCORE_SCRIPT}" > "${SYSTEM_DIR}/quartus_systems/arb_hit_type0_supercore_build_qsys_script.log" 2>&1

run_qsys_update() {
    local qsys="$1"
    local log="${qsys%.qsys}_emulator_type0_qsys_script.log"
    [ -f "${qsys}" ] || return 0

    chmod u+w "${qsys}" 2>/dev/null || true
    qsys-script \
        --system-file="${qsys}" \
        --search-path="${SEARCH_PATHS},\$" \
        --script="${SCRIPT}" > "${log}" 2>&1
    chmod a-w "${qsys}"
}

run_qsys_update "${SYSTEM_DIR}/quartus_systems/scifi_datapath_system_v3.qsys"

qsys-script \
    --cmd="set ::env(SYSTEM_DIR) {${SYSTEM_DIR}}" \
    --script="${DESCRIPTION_SCRIPT}" > "${SYSTEM_DIR}/quartus_systems/emulator_type0_description_qsys_script.log" 2>&1

qsys-script \
    --cmd="set ::env(SYSTEM_DIR) {${SYSTEM_DIR}}" \
    --script="${TOP_PATCH_SCRIPT}" > "${SYSTEM_DIR}/syn/feb_system_v3_top_patch_qsys_script.log" 2>&1
