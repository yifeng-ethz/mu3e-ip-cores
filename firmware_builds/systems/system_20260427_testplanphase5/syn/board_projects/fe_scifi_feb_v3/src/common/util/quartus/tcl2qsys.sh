#!/bin/bash
set -euf
export LC_ALL=C

TCL=$1
QSYS=$2

QSYS_DIR=$(dirname -- "$QSYS")
mkdir -p -- "$QSYS_DIR"
SEARCH_PATH=""
USER_COMPONENT_PATHS=""
MU3E_IP_CORES_ROOT="${MU3E_IP_CORES_ROOT:-/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores}"
QSYS_ISOLATE_CATALOG="${QSYS_ISOLATE_CATALOG:-1}"

append_search_path() {
    local candidate="$1"
    [ -d "${candidate}" ] || return 0
    local resolved
    resolved="$(realpath -- "${candidate}")"
    if [ -n "${SEARCH_PATH}" ]; then
        SEARCH_PATH="${SEARCH_PATH},${resolved}"
    else
        SEARCH_PATH="${resolved}"
    fi
    USER_COMPONENT_PATHS="${USER_COMPONENT_PATHS}${resolved}"$'\n'
}

append_component_dir() {
    local candidate="$1"
    [ -d "${candidate}" ] || return 0
    if [ -e "${candidate}/components.ipx" ] || find "${candidate}" -maxdepth 1 \( -name '*_hw.tcl' -o -name '*.qsys' \) | grep -q .; then
        append_search_path "${candidate}"
    fi
}

append_search_path "$(realpath -- "$QSYS_DIR")"

if [ -d "${MU3E_IP_CORES_ROOT}" ]; then
    for candidate in "${MU3E_IP_CORES_ROOT}" "${MU3E_IP_CORES_ROOT}"/* "${MU3E_IP_CORES_ROOT}"/*/legacy/*; do
        [ -d "${candidate}" ] || continue
        append_component_dir "${candidate}"
    done

    append_search_path "${MU3E_IP_CORES_ROOT}/histogram_statistics"
fi

if [ -n "${QSYS_EXTRA_SEARCH_PATHS:-}" ]; then
    IFS=':' read -r -a extra_paths <<< "${QSYS_EXTRA_SEARCH_PATHS}"
    for extra_path in "${extra_paths[@]}"; do
        [ -n "${extra_path}" ] || continue
        append_search_path "${extra_path}"
    done
fi

if [ "${QSYS_ISOLATE_CATALOG}" != "0" ]; then
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

CMD=(
    "source {$TCL};"
    "save_system {$QSYS};"
)

exec \
qsys-script \
    --search-path="${SEARCH_PATH},\$" \
    --cmd="${CMD[*]}"
