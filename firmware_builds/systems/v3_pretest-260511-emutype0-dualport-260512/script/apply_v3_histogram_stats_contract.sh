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
TCL="${SYSTEM_DIR}/script/update_scifi_datapath_v3_histogram_stats.tcl"
SEARCH_PATHS=""
USER_COMPONENT_PATHS=""

append_search_path() {
    local candidate="$1"
    [ -d "${candidate}" ] || return 0
    local resolved
    resolved="$(realpath -- "${candidate}")"
    if [ -n "${SEARCH_PATHS}" ]; then
        SEARCH_PATHS="${SEARCH_PATHS},${resolved}"
    else
        SEARCH_PATHS="${resolved}"
    fi
    USER_COMPONENT_PATHS="${USER_COMPONENT_PATHS}${resolved}"$'\n'
}

append_component_dir() {
    local candidate="$1"
    [ -d "${candidate}" ] || return 0
    if [ -e "${candidate}/components.ipx" ] || find "${candidate}" -maxdepth 1 \( -name '*_hw.tcl' -o -name '*.qsys' \) | grep -q .; then
        append_search_path "${candidate}"
    elif [ -d "${candidate}/script" ] && find "${candidate}/script" -maxdepth 1 -name '*_hw.tcl' | grep -q .; then
        append_search_path "${candidate}/script"
    fi
}

append_search_path "${ROOT}/histogram_statistics"

if [ -d "${ROOT}" ]; then
    for candidate in "${ROOT}" "${ROOT}"/* "${ROOT}"/*/legacy/* "${ROOT}"/*/reference/* "${ROOT}"/misc/*; do
        [ -d "${candidate}" ] || continue
        append_component_dir "${candidate}"
    done
fi

if [ -n "${QSYS_EXTRA_SEARCH_PATHS:-}" ]; then
    IFS=':' read -r -a extra_paths <<< "${QSYS_EXTRA_SEARCH_PATHS}"
    for extra_path in "${extra_paths[@]}"; do
        [ -n "${extra_path}" ] || continue
        append_search_path "${extra_path}"
    done
fi

if [ "${QSYS_ISOLATE_CATALOG:-1}" != "0" ]; then
    qsys_user_root="$(mktemp -d "${TMPDIR:-/tmp}/qsys_user_catalog.XXXXXX")"
    mkdir -p "${qsys_user_root}/ip/18.1/ip_search_path"
    {
        printf '%s\n' '<library>'
        printf '%s' "${USER_COMPONENT_PATHS}" | awk 'NF && !seen[$0]++ { printf " <path path=\"%s/**/*\" />\n", $0 }'
        printf '%s\n' '</library>'
    } > "${qsys_user_root}/ip/18.1/ip_search_path/user_components.ipx"
    export HOME="${qsys_user_root}"
    export IP_USERDIR="${qsys_user_root}/ip/18.1"
    export IP_GLOBALDIR="${qsys_user_root}/ip/18.1"
fi

for qsys in \
    "${ROOT}/quartus_systems/scifi_datapath_system_v3.qsys" \
    "${ROOT}/quartus_systems/scifi_datapath_system_v3_pipe.qsys" \
    "${ROOT}/quartus_systems/scifi_datapath_system_v3_lat4.qsys"; do
    qsys-script \
        --system-file="${qsys}" \
        --search-path="${SEARCH_PATHS},\$" \
        --script="${TCL}"
done
