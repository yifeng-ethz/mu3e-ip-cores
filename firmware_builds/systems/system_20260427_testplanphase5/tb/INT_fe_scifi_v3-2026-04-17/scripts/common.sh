#!/usr/bin/env bash
set -euo pipefail

INT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEM_DIR="$(cd -- "${INT_DIR}/../.." && pwd)"
FIRMWARE_BUILDS_DIR="$(cd -- "${SYSTEM_DIR}/../.." && pwd)"
REPO_ROOT="$(cd -- "${FIRMWARE_BUILDS_DIR}/.." && pwd)"
BOARD_PROJECT_DIR="${SYSTEM_DIR}/syn/board_projects/fe_scifi_feb_v3"
STATIC_TB_DIR="${INT_DIR}/tb_src"
DOC_ROOT="${INT_DIR}/docs"
CASE_ROOT="${INT_DIR}/cases"
GENERATED_ROOT="${INT_DIR}/generated"
REPORT_ROOT="${INT_DIR}/REPORT"
WORK_ROOT="${INT_DIR}/work"

ONLINE_ROOT="/home/yifeng/packages/online_dpv2/online"
FE_ROOT="${ONLINE_ROOT}/fe_board/fe_scifi"
COMMON_DIR="${ONLINE_ROOT}/common/firmware"

FEB_BENCH_ENTITY="${TB_FEB_BENCH_ENTITY:-feb_system_v3_pipe}"
FEB_TARGET_ENTITY="${TB_FEB_TARGET_ENTITY:-${FEB_BENCH_ENTITY}}"
FEB_SYNTH="${TB_FEB_SYNTH:-${SYSTEM_DIR}/syn/${FEB_TARGET_ENTITY}/synthesis}"
FEB_QIP="${TB_FEB_QIP:-${FEB_SYNTH}/${FEB_TARGET_ENTITY}.qip}"
DP_BENCH_ENTITY="${TB_DP_BENCH_ENTITY:-scifi_datapath_system_v3_pipe}"
DP_TARGET_ENTITY="${TB_DP_TARGET_ENTITY:-${DP_BENCH_ENTITY}}"
DP_SYNTH="${TB_DP_SYNTH:-${SYSTEM_DIR}/syn/${DP_TARGET_ENTITY}/synthesis}"
DP_QIP="${TB_DP_QIP:-${DP_SYNTH}/${DP_TARGET_ENTITY}.qip}"

source "${REPO_ROOT}/scripts/questa_one_env.sh"

INTEL_VHDL_LIBS="${QUESTA_INTEL_VHDL_LIBS}"
INTEL_VERILOG_LIBS="${INTEL_VERILOG_LIBS:-${QUESTA_HOME}/intel/verilog}"

mkdir -p "${DOC_ROOT}" "${CASE_ROOT}" "${GENERATED_ROOT}" "${REPORT_ROOT}" "${WORK_ROOT}"

generated_dir() {
  local domain="$1"
  printf '%s/%s' "${GENERATED_ROOT}" "${domain}"
}

work_dir() {
  local domain="$1"
  printf '%s/%s' "${WORK_ROOT}" "${domain}"
}

report_dir() {
  local domain="$1"
  printf '%s/%s' "${REPORT_ROOT}" "${domain}"
}

prepare_domain_tree() {
  local domain="$1"
  mkdir -p "$(generated_dir "${domain}")" "$(work_dir "${domain}")" "$(report_dir "${domain}")"
}

setup_questa_license() {
  local questa_license eth_lic_server

  questa_license="${QUESTA_HOME}/LR-287689_License.dat"
  eth_lic_server="8161@lic-mentor.ethz.ch"

  if [[ -f "${questa_license}" ]]; then
    export LM_LICENSE_FILE="${eth_lic_server}:${questa_license}"
  else
    export LM_LICENSE_FILE="${eth_lic_server}"
  fi
  export MGLS_LICENSE_FILE="${LM_LICENSE_FILE}"
}

run_vcom() {
  "${VCOM}" -suppress 12110 "$@"
}

run_vlog() {
  "${VLOG}" -suppress 12110 "$@"
}

compile_feb_sim_overrides() {
  local work_dir="$1"

  run_vcom -work "${work_dir}" -2008 "${STATIC_TB_DIR}/alt_dpram.vhd"
  run_vcom -work "${work_dir}" -2008 "${BOARD_PROJECT_DIR}/src/wrappers/feb_system_v3/sc_downlink_cdc_bridge.vhd"
}

create_work_lib() {
  local work_dir="$1"

  rm -rf "${work_dir}"
  "${VLIB}" "${work_dir}"
  "${VMAP}" "${work_dir}" "${work_dir}"
}

map_intel_libs() {
  local work_dir="$1"

  "${VMAP}" lpm "${INTEL_VHDL_LIBS}/220model"
  "${VMAP}" altera "${INTEL_VHDL_LIBS}/altera"
  "${VMAP}" altera_mf "${INTEL_VHDL_LIBS}/altera_mf"
  "${VMAP}" altera_ver "${INTEL_VERILOG_LIBS}/altera"
  "${VMAP}" altera_mf_ver "${INTEL_VERILOG_LIBS}/altera_mf"
  "${VMAP}" altera_lnsim_ver "${INTEL_VERILOG_LIBS}/altera_lnsim"
  "${VMAP}" lpm_ver "${INTEL_VERILOG_LIBS}/220model"
  "${VMAP}" 220model_ver "${INTEL_VERILOG_LIBS}/220model"
  "${VMAP}" twentynm_ver "${INTEL_VERILOG_LIBS}/twentynm"
  "${VMAP}" sgate_ver "${INTEL_VERILOG_LIBS}/sgate"
  "${VMAP}" work "${work_dir}"
}

compile_common_fw_deps() {
  local work_dir="$1"

  run_vcom -work "${work_dir}" -2008 "${COMMON_DIR}/util/util_slv.vhd"
  run_vcom -work "${work_dir}" -2008 "${COMMON_DIR}/util/util_pkg.vhd"
  run_vcom -work "${work_dir}" -2008 "${COMMON_DIR}/registers/mudaq.vhd"
  run_vcom -work "${work_dir}" -2008 "${ONLINE_ROOT}/fe_board/fe/util/fifo_reg.vhd"
  run_vcom -work "${work_dir}" -2008 "${COMMON_DIR}/util/ff_sync.vhd"
  run_vcom -work "${work_dir}" -2008 "${COMMON_DIR}/util/reset_sync.vhd"
  run_vcom -work "${work_dir}" -2008 "${COMMON_DIR}/util/quartus/ip_scfifo_v2.vhd"
  run_vcom -work "${work_dir}" -2008 "${COMMON_DIR}/util/quartus/ip_dcfifo_v2.vhd"
  run_vcom -work "${work_dir}" -2008 "${COMMON_DIR}/a10/link/mu3e_pkg.vhd"
  run_vcom -work "${work_dir}" -2008 "${COMMON_DIR}/a10/link/link_scfifo.vhd"
  run_vcom -work "${work_dir}" -2008 "${COMMON_DIR}/a10/swb/swb_sc_main.vhd"
  run_vcom -work "${work_dir}" -2008 "${COMMON_DIR}/a10/swb/swb_sc_secondary.vhd"
  run_vcom -work "${work_dir}" -2008 "${FE_ROOT}/generated/components_pkg.vhd"
}

should_skip_qip_file() {
  local path="$1"
  local skip_regex="${2:-}"

  if [[ -z "${skip_regex}" ]]; then
    return 1
  fi

  [[ "$(basename "${path}")" =~ ${skip_regex} ]]
}

compile_qip() {
  local work_dir="$1"
  local synth_dir="$2"
  local qip_file="$3"
  local tag="$4"
  local skip_regex="${5:-}"
  local pending_vhdl prev_pending cur_pending next_pending f
  local compile_err_dir compile_log safe_name

  echo "═══ Compiling ${tag} QIP sources ═══"

  while IFS= read -r f; do
    [[ -n "${f}" ]] || continue
    f="${synth_dir}/${f}"
    if should_skip_qip_file "${f}" "${skip_regex}"; then
      continue
    fi
    echo "[vcom][pkg][${tag}] ${f}"
    run_vcom -work "${work_dir}" -2008 "${f}"
  done < <(awk -F'"' '/VHDL_FILE/ && $4 ~ /_pkg\.vhd$/ { print $4 }' "${qip_file}")

  pending_vhdl="$(mktemp)"
  compile_err_dir="$(mktemp -d)"
  while IFS= read -r f; do
    [[ -n "${f}" ]] || continue
    f="${synth_dir}/${f}"
    if should_skip_qip_file "${f}" "${skip_regex}"; then
      continue
    fi
    printf '%s\n' "${f}" >> "${pending_vhdl}"
  done < <(awk -F'"' '/VHDL_FILE/ && $4 !~ /_pkg\.vhd$/ { print $4 }' "${qip_file}")

  prev_pending=-1
  while [[ -s "${pending_vhdl}" ]]; do
    cur_pending="$(wc -l < "${pending_vhdl}")"
    if [[ "${cur_pending}" == "${prev_pending}" ]]; then
      echo "Unresolved VHDL compile-order dependencies remain in ${tag}:"
      cat "${pending_vhdl}"
      while IFS= read -r f; do
        [[ -n "${f}" ]] || continue
        safe_name="$(printf '%s' "${f}" | md5sum | awk '{print $1}')"
        compile_log="${compile_err_dir}/${safe_name}.log"
        if [[ -f "${compile_log}" ]]; then
          cat "${compile_log}"
        fi
      done < "${pending_vhdl}"
      rm -rf "${compile_err_dir}"
      rm -f "${pending_vhdl}"
      exit 1
    fi
    prev_pending="${cur_pending}"
    next_pending="$(mktemp)"
    while IFS= read -r f; do
      [[ -n "${f}" ]] || continue
      echo "[vcom][${tag}] ${f}"
      safe_name="$(printf '%s' "${f}" | md5sum | awk '{print $1}')"
      compile_log="${compile_err_dir}/${safe_name}.log"
      if run_vcom -work "${work_dir}" -2008 "${f}" >"${compile_log}" 2>&1; then
        cat "${compile_log}"
        rm -f "${compile_log}"
        :
      else
        echo "${f}" >> "${next_pending}"
      fi
    done < "${pending_vhdl}"
    rm -f "${pending_vhdl}"
    pending_vhdl="${next_pending}"
  done
  rm -rf "${compile_err_dir}"
  rm -f "${pending_vhdl}"

  while IFS= read -r f; do
    [[ -n "${f}" ]] || continue
    f="${synth_dir}/${f}"
    if should_skip_qip_file "${f}" "${skip_regex}"; then
      continue
    fi
    echo "[vlog][${tag}] ${f}"
    run_vlog -work "${work_dir}" \
      -L altera_ver -L altera_mf_ver -L altera_lnsim_ver -L lpm_ver -L 220model_ver -L twentynm_ver -L sgate_ver \
      "${f}"
  done < <(awk -F'"' '/VERILOG_FILE/ { print $4 }' "${qip_file}")

  while IFS= read -r f; do
    [[ -n "${f}" ]] || continue
    f="${synth_dir}/${f}"
    if should_skip_qip_file "${f}" "${skip_regex}"; then
      continue
    fi
    echo "[vlog -sv][${tag}] ${f}"
    run_vlog -work "${work_dir}" -sv \
      -L altera_ver -L altera_mf_ver -L altera_lnsim_ver -L lpm_ver -L 220model_ver -L twentynm_ver -L sgate_ver \
      "${f}"
  done < <(awk -F'"' '/SYSTEMVERILOG_FILE/ { print $4 }' "${qip_file}")
}

symlink_init_files() {
  local target_dir="$1"
  shift
  local src_dir f base

  for src_dir in "$@"; do
    while IFS= read -r f; do
      base="$(basename "${f}")"
      if [[ ! -e "${target_dir}/${base}" ]]; then
        ln -sf "${f}" "${target_dir}/${base}"
      fi
    done < <(find "${src_dir}" -type f \( -name '*.hex' -o -name '*.txt' -o -name '*.dat' -o -name '*.mif' -o -name '*.ver' \))
  done
}

materialize_mif_runtime_aliases() {
  local target_dir="$1"
  local runtime_script="${INT_DIR}/scripts/mif_runtime_init.py"
  local mif_files=()

  while IFS= read -r f; do
    [[ -n "${f}" ]] || continue
    mif_files+=("${f}")
  done < <(find "${target_dir}" -maxdepth 1 \( -type f -o -type l \) -name '*.mif' | sort)

  if [[ ${#mif_files[@]} -eq 0 ]]; then
    return 0
  fi

  python3 "${runtime_script}" --out-dir "${target_dir}" "${mif_files[@]}"
}

run_vsim_logged() {
  local log_file="$1"
  shift

  local status=0
  "$@" 2>&1 | tee "${log_file}" || status=$?
  if grep -Eq '^\*\* Fatal:|\[FAIL\]' "${log_file}"; then
    return 1
  fi
  return "${status}"
}
