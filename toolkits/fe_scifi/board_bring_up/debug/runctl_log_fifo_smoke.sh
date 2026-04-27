#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
probe_tcl="${script_dir}/runctl_log_fifo_probe.tcl"
rw_bin="${RW_BIN:-/home/yifeng/packages/online_dpv2/online/install/bin/rw}"
system_console_bin="${SYSTEM_CONSOLE_BIN:-system-console}"
settle_s="${SETTLE_S:-1}"
read_tuples="${READ_TUPLES:-4}"

usage() {
    cat <<'EOF'
Usage:
  runctl_log_fifo_smoke.sh [sync|start|end|all]

Behavior:
  - flush the FE SciFi upload host log FIFO over JTAG
  - pulse one or more reset-link commands through the Arria10 PCIe CSR path
  - dump the resulting run-control log tuples from the FE upload subsystem

Environment overrides:
  RW_BIN               path to the MuDAQ CSR utility
  SYSTEM_CONSOLE_BIN   path to system-console
  SETTLE_S             sleep in seconds between assert/deassert pulses
  READ_TUPLES          number of tuples to dump after the command sequence
EOF
}

pulse_cmd() {
    local value="$1"
    "${rw_bin}" wwr 0x28 "${value}" >/dev/null
    sleep "${settle_s}"
    "${rw_bin}" wwr 0x28 0x0 >/dev/null
    sleep "${settle_s}"
}

mode="${1:-all}"
expected_regex=""

if [[ "${mode}" == "-h" || "${mode}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ ! -x "${rw_bin}" ]]; then
    echo "ERROR: rw utility not found at ${rw_bin}" >&2
    exit 2
fi
if [[ ! -f "${probe_tcl}" ]]; then
    echo "ERROR: missing probe script ${probe_tcl}" >&2
    exit 2
fi

echo "[probe] flushing runctl log FIFO"
timeout 30s "${system_console_bin}" --script="${probe_tcl}" --flush --tuples 0

case "${mode}" in
    sync)
        expected_regex='TUPLE_[0-9]+_CMD=RUN_SYNC'
        echo "[cmd] RUN_SYNC"
        pulse_cmd 0xE0000011
        ;;
    start)
        expected_regex='TUPLE_[0-9]+_CMD=START_RUN'
        echo "[cmd] START_RUN"
        pulse_cmd 0xE0000012
        ;;
    end)
        expected_regex='TUPLE_[0-9]+_CMD=END_RUN'
        echo "[cmd] END_RUN"
        pulse_cmd 0xE0000013
        ;;
    all)
        expected_regex='TUPLE_[0-9]+_CMD=(RUN_SYNC|START_RUN|END_RUN)'
        echo "[cmd] RUN_SYNC"
        pulse_cmd 0xE0000011
        echo "[cmd] START_RUN"
        pulse_cmd 0xE0000012
        echo "[cmd] END_RUN"
        pulse_cmd 0xE0000013
        ;;
    *)
        echo "ERROR: unknown mode '${mode}'" >&2
        usage >&2
        exit 2
        ;;
esac

echo "[probe] reading back ${read_tuples} tuple(s)"
probe_output="$(timeout 30s "${system_console_bin}" --script="${probe_tcl}" --tuples "${read_tuples}")"
printf '%s\n' "${probe_output}"

if ! printf '%s\n' "${probe_output}" | rg -q "${expected_regex}"; then
    echo "ERROR: expected run-control command(s) not observed in FE upload log FIFO" >&2
    exit 1
fi
