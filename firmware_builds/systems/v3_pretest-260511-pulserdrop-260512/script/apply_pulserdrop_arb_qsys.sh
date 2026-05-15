#!/bin/bash
set -eu
export LC_ALL=C

ROOT="${MU3E_IP_CORES_ROOT:-/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores}"
SYSTEM_DIR="${ROOT}/firmware_builds/systems/v3_pretest-260511-pulserdrop-260512"
export SYSTEM_DIR

BUILD_SUPERCORE_SCRIPT="${SYSTEM_DIR}/script/build_arb_hit_type0_supercore_qsys.tcl"
REFACTOR_SCRIPT="${SYSTEM_DIR}/script/clone_refactor_v3_emulator_type0_qsys.tcl"

. "${SYSTEM_DIR}/script/qsys_search_path.sh"

SEARCH_PATHS=""
USER_COMPONENT_PATHS=""
QSYS_SEARCH_PATH_COUNT=0
QSYS_SEARCH_PATH_SEEN=":"
mkdir -p "${SYSTEM_DIR}/quartus_systems"
qsys_collect_active_search_paths "${ROOT}"
qsys_create_isolated_user_catalog

qsys-script \
    --search-path="${SEARCH_PATHS},\$" \
    --script="${BUILD_SUPERCORE_SCRIPT}" > "${SYSTEM_DIR}/quartus_systems/arb_hit_type0_supercore_build_qsys_script.log" 2>&1

local_search="${SYSTEM_DIR}/quartus_systems"
if [ -n "${SEARCH_PATHS}" ]; then
    active_search="${local_search},${SEARCH_PATHS}"
else
    active_search="${local_search}"
fi

run_qsys_clone_refactor() {
    local src_qsys="$1"
    local dst_qsys="$2"
    local log="${dst_qsys%.qsys}_pulserdrop_arb_qsys_script.log"

    [ -f "${src_qsys}" ] || {
        printf 'missing source Qsys: %s\n' "${src_qsys}" >&2
        return 1
    }

    qsys-script \
        --search-path="${active_search},\$" \
        --cmd="set ::src_qsys {${src_qsys}}; set ::dst_qsys {${dst_qsys}}" \
        --script="${REFACTOR_SCRIPT}" > "${log}" 2>&1
}

run_qsys_clone_refactor \
    "${ROOT}/quartus_systems/scifi_datapath_system_v3.qsys" \
    "${SYSTEM_DIR}/quartus_systems/scifi_datapath_system_v3.qsys"

run_qsys_clone_refactor \
    "${ROOT}/quartus_systems/scifi_datapath_system_v3_pipe.qsys" \
    "${SYSTEM_DIR}/quartus_systems/scifi_datapath_system_v3_pipe.qsys"
