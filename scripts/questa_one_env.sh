#!/usr/bin/env bash
set -euo pipefail

if [[ "${_QUESTA_ONE_ENV_SH_LOADED:-0}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi
_QUESTA_ONE_ENV_SH_LOADED=1
export _QUESTA_ONE_ENV_SH_LOADED

questa_env_fail() {
  echo "ERROR: $*" >&2
  return 1 2>/dev/null || exit 1
}

find_questa_tool() {
  local tool_name="$1"
  local candidate

  for candidate in \
    "${QUESTA_HOME}/bin/${tool_name}" \
    "${QUESTA_HOME}/linux_x86_64/${tool_name}"
  do
    if [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

QUESTA_HOME_ALLOWED="/data1/questaone_sim/questasim"
export QUESTA_HOME="${QUESTA_HOME:-${QUESTA_HOME_ALLOWED}}"
if [[ "${QUESTA_HOME}" != "${QUESTA_HOME_ALLOWED}" ]]; then
  questa_env_fail "Unsupported QUESTA_HOME=${QUESTA_HOME}. Use ${QUESTA_HOME_ALLOWED} only"
fi
export QUESTA_LICENSE_SERVER="${QUESTA_LICENSE_SERVER:-8161@lic-mentor.ethz.ch}"
export ETH_LIC_SERVER="${ETH_LIC_SERVER:-${QUESTA_LICENSE_SERVER}}"
export ETH_MENTOR_SERVER="${ETH_MENTOR_SERVER:-${QUESTA_LICENSE_SERVER}}"
export SALT_LICENSE_SERVER="${SALT_LICENSE_SERVER:-${QUESTA_LICENSE_SERVER}}"
export MGLS_LICENSE_FILE="${MGLS_LICENSE_FILE:-${QUESTA_LICENSE_SERVER}}"
export LM_LICENSE_FILE="${LM_LICENSE_FILE:-${QUESTA_LICENSE_SERVER}}"
export QSIM_INI="${QSIM_INI:-${QUESTA_HOME}/modelsim.ini}"
export QUESTA_MODELSIM_INI="${QUESTA_MODELSIM_INI:-${QSIM_INI}}"
export QUESTA_FORMAL_HOME="${QUESTA_FORMAL_HOME:-}"

export VLIB="$(find_questa_tool vlib)" || questa_env_fail "vlib not found under ${QUESTA_HOME}"
export VMAP="$(find_questa_tool vmap)" || questa_env_fail "vmap not found under ${QUESTA_HOME}"
export VCOM="$(find_questa_tool vcom)" || questa_env_fail "vcom not found under ${QUESTA_HOME}"
export VLOG="$(find_questa_tool vlog)" || questa_env_fail "vlog not found under ${QUESTA_HOME}"
export VSIM="$(find_questa_tool vsim)" || questa_env_fail "vsim not found under ${QUESTA_HOME}"
export VOPT="$(find_questa_tool vopt)" || questa_env_fail "vopt not found under ${QUESTA_HOME}"
export VCOVER="$(find_questa_tool vcover)" || questa_env_fail "vcover not found under ${QUESTA_HOME}"
export LMUTIL="$(find_questa_tool lmutil)" || questa_env_fail "lmutil not found under ${QUESTA_HOME}"
export QRUN="$(find_questa_tool qrun || true)"

export QUESTA_UVM_HOME="${QUESTA_UVM_HOME:-}"
if [[ -z "${QUESTA_UVM_HOME}" ]]; then
  for candidate in \
    "${QUESTA_HOME}/verilog_src/uvm-1.2" \
    "${QUESTA_HOME}/uvm-1.2"
  do
    if [[ -f "${candidate}/src/uvm_pkg.sv" ]]; then
      export QUESTA_UVM_HOME="${candidate}"
      break
    fi
  done
fi
[[ -n "${QUESTA_UVM_HOME}" ]] || questa_env_fail "UVM 1.2 installation not found under ${QUESTA_HOME}"
export QUESTA_UVM_SRC="${QUESTA_UVM_SRC:-${QUESTA_UVM_HOME}/src}"
[[ -f "${QUESTA_UVM_SRC}/uvm_pkg.sv" ]] || questa_env_fail "UVM package source not found under ${QUESTA_UVM_SRC}"

export QUESTA_UVM_DPI_SO="${QUESTA_UVM_DPI_SO:-}"
if [[ -z "${QUESTA_UVM_DPI_SO}" ]]; then
  for candidate in \
    "${QUESTA_UVM_HOME}/linux_x86_64/uvm_dpi.so" \
    "${QUESTA_HOME}/uvm-1.2/linux_x86_64/uvm_dpi.so" \
    "${QUESTA_HOME}/verilog_src/uvm-1.2/linux_x86_64/uvm_dpi.so"
  do
    if [[ -f "${candidate}" ]]; then
      export QUESTA_UVM_DPI_SO="${candidate}"
      break
    fi
  done
fi
if [[ -n "${QUESTA_UVM_DPI_SO}" ]]; then
  export QUESTA_UVM_DPI_LIB="${QUESTA_UVM_DPI_LIB:-${QUESTA_UVM_DPI_SO%.so}}"
fi

export QUESTA_INTEL_VHDL_LIBS="${QUESTA_INTEL_VHDL_LIBS:-}"
if [[ -z "${QUESTA_INTEL_VHDL_LIBS}" ]]; then
  for candidate in \
    "${QUESTA_HOME}/intel_2026/vhdl" \
    "${QUESTA_HOME}/intel/vhdl"
  do
    if [[ -d "${candidate}" ]]; then
      export QUESTA_INTEL_VHDL_LIBS="${candidate}"
      break
    fi
  done
fi
