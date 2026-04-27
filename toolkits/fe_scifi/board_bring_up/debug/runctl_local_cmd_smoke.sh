#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
probe_tcl="${script_dir}/runctl_local_cmd_probe.tcl"
system_console_bin="${SYSTEM_CONSOLE_BIN:-system-console}"
sleep_ms="${SLEEP_MS:-100}"
read_tuples="${READ_TUPLES:-4}"
status_flag="${STATUS_FLAG:---status}"
master_match="${MASTER_MATCH:-}"

usage() {
    cat <<'EOF'
Usage:
  runctl_local_cmd_smoke.sh [enable|prepare|sync|start|end|abort|all]

Behavior:
  - flush the FE SciFi upload host log FIFO through runctl_mgmt_host.csr
  - inject one or more local run-control command words through CSR_LOCAL_CMD
  - dump the resulting run-control log tuples
  - optionally dump host/emulator status

Environment overrides:
  SYSTEM_CONSOLE_BIN   path to system-console
  SLEEP_MS             delay between injected words
  READ_TUPLES          number of tuples to dump after the command sequence
  STATUS_FLAG          pass '--status' (default) or empty string to skip emulator status reads
  MASTER_MATCH         optional glob passed to --master-match for stable FE master selection
EOF
}

mode="${1:-all}"
inject_args=()

if [[ "${mode}" == "-h" || "${mode}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ ! -f "${probe_tcl}" ]]; then
    echo "ERROR: missing probe script ${probe_tcl}" >&2
    exit 2
fi

case "${mode}" in
    enable)
        inject_args+=(--inject 0x00000032)
        ;;
    sync)
        inject_args+=(--inject 0x00000011)
        ;;
    start)
        inject_args+=(--inject 0x00000012)
        ;;
    end)
        inject_args+=(--inject 0x00000013)
        ;;
    abort)
        inject_args+=(--inject 0x00000014)
        ;;
    prepare)
        inject_args+=(--inject 0x11223310)
        ;;
    all)
        inject_args+=(
            --inject 0x00000032
            --inject 0x11223310
            --inject 0x00000011
            --inject 0x00000012
            --inject 0x00000013
            --inject 0x00000014
        )
        ;;
    *)
        echo "ERROR: unknown mode '${mode}'" >&2
        usage >&2
        exit 2
        ;;
esac

cmd=(
    "${system_console_bin}"
    --script="${probe_tcl}"
    --flush
    --sleep-ms "${sleep_ms}"
    --tuples "${read_tuples}"
)

if [[ -n "${status_flag}" ]]; then
    cmd+=("${status_flag}")
fi
if [[ -n "${master_match}" ]]; then
    cmd+=(--master-match "${master_match}")
fi
cmd+=("${inject_args[@]}")

printf '[probe] %q ' "${cmd[@]}"
printf '\n'
"${cmd[@]}"
