#!/bin/bash
set -eu
export LC_ALL=C

QSYS=$1

QSYS="$(realpath -- "$QSYS")"
QSYS_DIR=$(dirname -- "$QSYS")
SEARCH_PATHS=""
USER_COMPONENT_PATHS=""
export MU3E_IP_CORES_ROOT="${MU3E_IP_CORES_ROOT:-/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores}"
export MU3E_IP_CORES="${MU3E_IP_CORES:-${MU3E_IP_CORES_ROOT}}"
QSYS_ISOLATE_CATALOG="${QSYS_ISOLATE_CATALOG:-1}"
QSYS_PATH_HELPER="${MU3E_IP_CORES_ROOT}/firmware_builds/systems/v3_pretest-260511-rc-readyless-260511/script/qsys_search_path.sh"

. "${QSYS_PATH_HELPER}"
qsys_collect_active_search_paths "${MU3E_IP_CORES_ROOT}"

if [ -n "${QSYS_EXTRA_SEARCH_PATHS:-}" ]; then
    IFS=':' read -r -a extra_paths <<< "${QSYS_EXTRA_SEARCH_PATHS}"
    for extra_path in "${extra_paths[@]}"; do
        [ -n "${extra_path}" ] || continue
        qsys_append_search_path "${extra_path}"
    done
fi

if [ "${QSYS_ISOLATE_CATALOG}" != "0" ]; then
    qsys_create_isolated_user_catalog
fi

QSYS_BASENAME=$(basename -- "$QSYS" .qsys)
GENERATED_DIR="${QSYS_DIR}/${QSYS_BASENAME}"
OUTPUT_DIR="${GENERATED_DIR}/synthesis"

if [ -d "${GENERATED_DIR}" ]; then
    chmod -R u+w "${GENERATED_DIR}"
fi
mkdir -p "${OUTPUT_DIR}"

if qsys-generate \
    --synthesis=VHDL \
    --output-directory="${GENERATED_DIR}" \
    --search-path="${SEARCH_PATHS},\$" \
    "$QSYS"; then
    if [ -d "${OUTPUT_DIR}" ]; then
        chmod -R a-w "${OUTPUT_DIR}"
    fi
    find "${GENERATED_DIR}" -maxdepth 1 \( -name '*.qsys' -o -name '*.sopcinfo' \) -exec chmod a-w {} +
else
    exit $?
fi
