#!/bin/bash
set -eu
export LC_ALL=C

ROOT="${MU3E_IP_CORES_ROOT:-/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores}"
SYSTEM_DIR="${ROOT}/firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512"
export SYSTEM_DIR
SYN_DIR="${SYSTEM_DIR}/syn"
QSYS="${SYN_DIR}/feb_system_v3.qsys"
QSYS_BASENAME="feb_system_v3"
GENERATED_ROOT="${SYN_DIR}/${QSYS_BASENAME}"
OUT_DIR="${GENERATED_ROOT}/synthesis"
QSYS_GENERATE_BIN="${QSYS_GENERATE_BIN:-/data1/intelFPGA/18.1/quartus/sopc_builder/bin/qsys-generate}"
STAMP="${QSYS_GENERATE_STAMP:-$(date +%Y%m%d_%H%M%S)}"
LOG="${SYN_DIR}/${QSYS_BASENAME}_qsys_generate_${STAMP}_isolated.console.log"
STATUS="${SYN_DIR}/${QSYS_BASENAME}_qsys_generate_${STAMP}_isolated.status"
TOP_PATCH_SCRIPT="${SYSTEM_DIR}/script/update_feb_system_v3_dualport_version.tcl"

. "${SYSTEM_DIR}/script/qsys_search_path.sh"

SEARCH_PATHS=""
USER_COMPONENT_PATHS=""
QSYS_SEARCH_PATH_COUNT=0
QSYS_SEARCH_PATH_SEEN=":"
qsys_collect_active_search_paths "${ROOT}"
qsys_create_isolated_user_catalog

qsys-script \
    --cmd="set ::env(SYSTEM_DIR) {${SYSTEM_DIR}}" \
    --script="${TOP_PATCH_SCRIPT}" > "${SYN_DIR}/${QSYS_BASENAME}_top_patch_qsys_script_${STAMP}.log" 2>&1

if [ -d "${GENERATED_ROOT}" ]; then
    chmod -R u+w "${GENERATED_ROOT}"
fi
if [ -f "${SYN_DIR}/${QSYS_BASENAME}.sopcinfo" ]; then
    chmod u+w "${SYN_DIR}/${QSYS_BASENAME}.sopcinfo"
fi
mkdir -p "${OUT_DIR}"

{
    printf 'qsys-generate input: %s\n' "${QSYS}"
    printf 'qsys-generate output-directory: %s\n' "${GENERATED_ROOT}"
    printf 'qsys-generate synthesis-directory: %s\n' "${OUT_DIR}"
    printf 'qsys-generate search-path-count: %s\n' "${QSYS_SEARCH_PATH_COUNT}"
    printf 'qsys-generate isolated-catalog: %s\n' "${QSYS_USER_CATALOG_ROOT}"
    printf 'qsys-generate excluded: firmware_builds/systems/*/syn and system_20260427_testplanphase5\n'
    printf 'qsys-generate search-path: %s,$\n' "${SEARCH_PATHS}"
    printf '\n'
} > "${LOG}"

set +e
"${QSYS_GENERATE_BIN}" \
    "${QSYS}" \
    --synthesis=VHDL \
    --output-directory="${GENERATED_ROOT}" \
    --family="Arria V" \
    --part=5AGXBA7D4F31C5 \
    --search-path="${SEARCH_PATHS},\$" >> "${LOG}" 2>&1
exit_code=$?
set -e

error_count="$(grep -c ' Error:' "${LOG}" || true)"

{
    printf 'command=%s %s --synthesis=VHDL --output-directory=%s --family=Arria V --part=5AGXBA7D4F31C5 --search-path=<%s paths>,$\n' "${QSYS_GENERATE_BIN}" "${QSYS}" "${GENERATED_ROOT}" "${QSYS_SEARCH_PATH_COUNT}"
    printf 'exit_code=%s\n' "${exit_code}"
    printf 'error_count=%s\n' "${error_count}"
    printf 'log=%s\n' "${LOG}"
    printf 'report=%s\n' "${GENERATED_ROOT}/${QSYS_BASENAME}_generation.rpt"
    printf 'isolated_catalog=%s\n' "${QSYS_USER_CATALOG_ROOT}"
} > "${STATUS}"

if [ "${exit_code}" -eq 0 ]; then
    if [ -d "${OUT_DIR}" ]; then
        chmod -R a-w "${OUT_DIR}"
    fi
    find "${GENERATED_ROOT}" -maxdepth 1 \( -name '*.qsys' -o -name '*.sopcinfo' \) -exec chmod a-w {} +
    find "${SYN_DIR}" -maxdepth 1 -name "${QSYS_BASENAME}.sopcinfo" -exec chmod a-w {} +
fi

exit "${exit_code}"
