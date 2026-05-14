#!/bin/bash
set -eu
export LC_ALL=C

ROOT="${MU3E_IP_CORES_ROOT:-/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores}"
SYSTEM_DIR="${ROOT}/firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512"
export SYSTEM_DIR
QSYS_GENERATE_BIN="${QSYS_GENERATE_BIN:-/data1/intelFPGA/18.1/quartus/sopc_builder/bin/qsys-generate}"
STAMP="${QSYS_GENERATE_STAMP:-$(date +%Y%m%d_%H%M%S)}"
TOP_PATCH_SCRIPT="${SYSTEM_DIR}/script/update_feb_system_v3_dualport_version.tcl"

. "${SYSTEM_DIR}/script/qsys_search_path.sh"

SEARCH_PATHS=""
USER_COMPONENT_PATHS=""
QSYS_SEARCH_PATH_COUNT=0
QSYS_SEARCH_PATH_SEEN=":"
qsys_collect_active_search_paths "${ROOT}"
qsys_create_isolated_user_catalog

run_qsys_generate() {
    local qsys="$1"
    local qsys_dir qsys_base out_root out_dir log status exit_code error_count desc_log

    qsys_dir="$(dirname -- "${qsys}")"
    qsys_base="$(basename -- "${qsys}" .qsys)"
    out_root="${qsys_dir}/${qsys_base}"
    out_dir="${out_root}/synthesis"
    log="${qsys_dir}/${qsys_base}_qsys_generate_${STAMP}_clean.console.log"
    status="${qsys_dir}/${qsys_base}_qsys_generate_${STAMP}_clean.status"

    if [ "${qsys_base}" = "feb_system_v3" ] && [ -f "${TOP_PATCH_SCRIPT}" ]; then
        desc_log="${qsys_dir}/${qsys_base}_top_patch_qsys_script_${STAMP}.log"
        qsys-script \
            --cmd="set ::env(SYSTEM_DIR) {${SYSTEM_DIR}}" \
            --script="${TOP_PATCH_SCRIPT}" > "${desc_log}" 2>&1
    fi

    if [ -d "${out_root}" ]; then
        chmod -R u+w "${out_root}"
    fi
    if [ -f "${qsys_dir}/${qsys_base}.sopcinfo" ]; then
        chmod u+w "${qsys_dir}/${qsys_base}.sopcinfo"
    fi
    mkdir -p "${out_dir}"

    {
        printf 'qsys-generate input: %s\n' "${qsys}"
        printf 'qsys-generate output-directory: %s\n' "${out_root}"
        printf 'qsys-generate synthesis-directory: %s\n' "${out_dir}"
        printf 'qsys-generate search-path-count: %s\n' "${QSYS_SEARCH_PATH_COUNT}"
        printf 'qsys-generate isolated-catalog: %s\n' "${QSYS_USER_CATALOG_ROOT}"
        printf 'qsys-generate clear-output-directory: yes\n'
        printf 'qsys-generate search-path: %s,$\n\n' "${SEARCH_PATHS}"
    } > "${log}"

    set +e
    "${QSYS_GENERATE_BIN}" \
        "${qsys}" \
        --synthesis=VHDL \
        --output-directory="${out_root}" \
        --clear-output-directory \
        --family="Arria V" \
        --part=5AGXBA7D4F31C5 \
        --search-path="${SEARCH_PATHS},\$" >> "${log}" 2>&1
    exit_code=$?
    set -e

    error_count="$(grep -c ' Error:' "${log}" || true)"
    {
        printf 'command=%s %s --synthesis=VHDL --output-directory=%s --clear-output-directory --family=Arria V --part=5AGXBA7D4F31C5 --search-path=<%s paths>,$\n' "${QSYS_GENERATE_BIN}" "${qsys}" "${out_root}" "${QSYS_SEARCH_PATH_COUNT}"
        printf 'exit_code=%s\n' "${exit_code}"
        printf 'error_count=%s\n' "${error_count}"
        printf 'log=%s\n' "${log}"
        printf 'report=%s\n' "${out_root}/${qsys_base}_generation.rpt"
        printf 'isolated_catalog=%s\n' "${QSYS_USER_CATALOG_ROOT}"
    } > "${status}"

    if [ "${exit_code}" -eq 0 ]; then
        if [ -d "${out_dir}" ]; then
            chmod -R a-w "${out_dir}"
        fi
        find "${out_root}" -maxdepth 1 \( -name '*.qsys' -o -name '*.sopcinfo' \) -exec chmod a-w {} +
        find "${qsys_dir}" -maxdepth 1 -name "${qsys_base}.sopcinfo" -exec chmod a-w {} +
    fi

    return "${exit_code}"
}

run_qsys_generate "${SYSTEM_DIR}/quartus_systems/arb_hit_type0_supercore.qsys"
run_qsys_generate "${SYSTEM_DIR}/quartus_systems/scifi_datapath_system_v3.qsys"
run_qsys_generate "${SYSTEM_DIR}/quartus_systems/scifi_datapath_system_v3_pipe.qsys"
run_qsys_generate "${SYSTEM_DIR}/syn/feb_system_v3.qsys"
