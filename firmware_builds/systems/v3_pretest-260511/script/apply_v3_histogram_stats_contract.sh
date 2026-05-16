#!/bin/bash
set -eu
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
ROOT="${MU3E_IP_CORES_ROOT:-${DEFAULT_ROOT}}"
TCL="${ROOT}/firmware_builds/systems/v3_pretest-260511/script/update_scifi_datapath_v3_histogram_stats.tcl"
MUTRIG_TCL="${ROOT}/firmware_builds/systems/v3_pretest-260511/script/update_mutrig_datapath_v3_frame_fifo.tcl"
HIT_STACK_TCL="${ROOT}/firmware_builds/systems/v3_pretest-260511/script/update_hit_stack_synthesis_debug0.tcl"
PARENT_TCL="${ROOT}/firmware_builds/systems/v3_pretest-260511/script/refresh_v3_histogram_parent_binding.tcl"
export MU3E_IP_CORES_ROOT="${ROOT}"

source "${ROOT}/firmware_builds/systems/v3_pretest-260511/script/qsys_search_path.sh"
qsys_collect_active_search_paths "${ROOT}"

if [ -n "${QSYS_EXTRA_SEARCH_PATHS:-}" ]; then
    IFS=':' read -r -a extra_paths <<< "${QSYS_EXTRA_SEARCH_PATHS}"
    for extra_path in "${extra_paths[@]}"; do
        [ -n "${extra_path}" ] || continue
        qsys_append_search_path "${extra_path}"
    done
fi

if [ "${QSYS_ISOLATE_CATALOG:-1}" != "0" ]; then
    qsys_create_isolated_user_catalog
fi

qsys-script \
    --system-file="${ROOT}/quartus_systems/mutrig_datapath_system_v3.qsys" \
    --search-path="${SEARCH_PATHS},\$" \
    --script="${MUTRIG_TCL}"

qsys-script \
    --system-file="${ROOT}/quartus_systems/hit_stack_system.qsys" \
    --search-path="${SEARCH_PATHS},\$" \
    --script="${HIT_STACK_TCL}"

for qsys in \
    "${ROOT}/quartus_systems/scifi_datapath_system_v3.qsys" \
    "${ROOT}/quartus_systems/scifi_datapath_system_v3_pipe.qsys" \
    "${ROOT}/quartus_systems/scifi_datapath_system_v3_lat4.qsys"; do
    qsys-script \
        --system-file="${qsys}" \
        --search-path="${SEARCH_PATHS},\$" \
        --script="${TCL}"
done

tclsh "${PARENT_TCL}"
