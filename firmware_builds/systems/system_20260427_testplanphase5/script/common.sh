#!/usr/bin/env bash

# Shared guardrails for board_test host-side runners.
# Keep this file side-effect free except for bt_setup_env().

bt_die() {
    printf 'board_test: %s\n' "$*" >&2
    exit 1
}

bt_note() {
    printf 'board_test: %s\n' "$*" >&2
}

bt_repo_root() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "${script_dir}/../../../.." && pwd
}

bt_script_dir() {
    cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

bt_board_test_dir() {
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

bt_find_first_exec() {
    local path
    for path in "$@"; do
        if [[ -n "${path}" && -x "${path}" ]]; then
            printf '%s\n' "${path}"
            return 0
        fi
    done
    return 1
}

bt_require_exec() {
    local path="$1"
    [[ -x "${path}" ]] || bt_die "missing executable: ${path}"
}

bt_require_file() {
    local path="$1"
    [[ -f "${path}" ]] || bt_die "missing file: ${path}"
}

bt_require_device() {
    local path="$1"
    [[ -e "${path}" ]] || bt_die "missing device node: ${path}"
}

bt_assert_u32() {
    local name="$1"
    local value="$2"
    [[ "${value}" =~ ^(0[xX][0-9a-fA-F]+|[0-9]+)$ ]] || bt_die "${name} must be an integer, got '${value}'"
}

bt_prepare_dir() {
    local path="$1"
    mkdir -p "${path}" || bt_die "failed to create directory: ${path}"
}

bt_setup_env() {
    local repo_root
    local board_test_dir
    local script_dir
    local bin_dir
    local generated_dir
    local report_dir

    repo_root="$(bt_repo_root)"
    board_test_dir="$(bt_board_test_dir)"
    script_dir="$(bt_script_dir)"
    bin_dir="${board_test_dir}/bin"
    generated_dir="${board_test_dir}/generated"
    report_dir="${board_test_dir}/reports"

    export BT_REPO_ROOT="${repo_root}"
    export BOARD_TEST_DIR="${board_test_dir}"
    export BOARD_TEST_SCRIPT_DIR="${script_dir}"
    export BOARD_TEST_BIN_DIR="${bin_dir}"
    export BOARD_TEST_GENERATED_DIR="${generated_dir}"
    export BOARD_TEST_REPORT_DIR="${report_dir}"
    export BOARD_TEST_DEVICE="${BOARD_TEST_DEVICE:-/dev/mudaq0}"
    export BOARD_TEST_LINK="${BOARD_TEST_LINK:-2}"
    export BOARD_TEST_DISPLAY="${BOARD_TEST_DISPLAY:-${DISPLAY:-:2}}"
    export DISPLAY="${BOARD_TEST_DISPLAY}"
    export BOARD_TEST_JDI="${BOARD_TEST_JDI:-${repo_root}/board_projects/fe_scifi_feb_v3/output_files/top.jdi}"
    export BOARD_TEST_PROJECT_DIR="${BOARD_TEST_PROJECT_DIR:-${repo_root}/board_projects/fe_scifi_feb_v3}"
    export BOARD_TEST_SYSCON="${BOARD_TEST_SYSCON:-$(bt_find_first_exec \
        /data1/intelFPGA/18.1/quartus/sopc_builder/bin/system-console \
        "$(command -v system-console 2>/dev/null || true)")}"
    export BOARD_TEST_SC_TOOL="${BOARD_TEST_SC_TOOL:-$(bt_find_first_exec \
        "${bin_dir}/sc_tool" \
        /home/yifeng/packages/online_dpv2/online/install/bin/sc_tool)}"
    export BOARD_TEST_RC_TOOL="${BOARD_TEST_RC_TOOL:-$(bt_find_first_exec \
        "${bin_dir}/rc_tool" \
        /home/yifeng/packages/online_dpv2/online/build/switching_pc/tools/rc_tool \
        /home/yifeng/packages/online_dpv2/online/install/bin/rc_tool)}"

    bt_prepare_dir "${bin_dir}"
    bt_prepare_dir "${generated_dir}"
    bt_prepare_dir "${report_dir}"

    bt_require_device "${BOARD_TEST_DEVICE}"
    bt_require_file "${BOARD_TEST_JDI}"
    bt_require_file "${BOARD_TEST_PROJECT_DIR}/output_files/top.sof"
    bt_require_exec "${BOARD_TEST_SYSCON}"
    bt_require_exec "${BOARD_TEST_SC_TOOL}"
    bt_require_exec "${BOARD_TEST_RC_TOOL}"
    bt_assert_u32 "BOARD_TEST_LINK" "${BOARD_TEST_LINK}"
}
