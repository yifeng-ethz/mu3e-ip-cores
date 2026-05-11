#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
root_dir="/home/yifeng/packages/online_sc/online"
sweep_py="${root_dir}/switching_pc/tools/sc_scratchpad_sweep.py"
signaltap_check="${project_dir}/scripts/check_sc_signaltap.sh"
sof_file="${project_dir}/output_files/top.sof"
fit_summary="${project_dir}/output_files/top.fit.summary"
sta_summary="${project_dir}/output_files/top.sta.summary"

resolve_active_stp_file() {
    python3 - "${project_dir}/top.qsf" "${project_dir}" <<'PY'
import re
import sys
from pathlib import Path

qsf_path = Path(sys.argv[1])
project_dir = Path(sys.argv[2])
pattern = re.compile(r'^\s*set_global_assignment\s+-name\s+(USE_SIGNALTAP_FILE|SIGNALTAP_FILE)\s+"([^"]+)"')
assignments = {}

if qsf_path.exists():
    for line in qsf_path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = pattern.match(line)
        if m is None:
            continue
        stp_path = Path(m.group(2))
        if not stp_path.is_absolute():
            stp_path = project_dir / stp_path
        assignments[m.group(1)] = stp_path

for key in ("SIGNALTAP_FILE", "USE_SIGNALTAP_FILE"):
    path = assignments.get(key)
    if path is not None:
        print(path)
        raise SystemExit(0)

print(project_dir / "top_sc_link2_packets_example1_format.stp")
PY
}

stp_file="$(resolve_active_stp_file)"

phase="all"
link="2"
addr="0x0"
value="0xA5A55A5A"
seed="12648430"
random_ops="64"
hw_pattern="${HW_PATTERN:-DE5*}"
skip_signaltap_check="0"
stp_rx_current_link="2"

usage() {
    cat <<'EOF'
Usage:
  run_sc_hw_bringup.sh [--phase all|smoke|stp|random] [--link N] [--addr HEX] [--value HEX]
                       [--seed N] [--random-ops N] [--hw-pattern GLOB] [--stp-rx-current-link N]
                       [--skip-signaltap-check]

Behavior:
  - assumes SWB and FEB are already programmed
  - validates the active SC SignalTap file unless skipped
  - auto-detects STP instance / signal-set / trigger names from the current .stp
  - runs the first recommended hardware checks on Link02 by default

Phases:
  all
    1. single smoke write/read with test_slowcontrol
    2. one strict SignalTap-backed write/read transaction using sc_scratchpad_sweep.py
    3. short random scratchpad stress without SignalTap

  smoke
    single direct write/read only

  stp
    one strict SignalTap-backed write/read transaction only

  random
    short random scratchpad stress only
EOF
}

pick_test_bin() {
    local cand
    for cand in \
        "${root_dir}/build-codex/switching_pc/tools/test_slowcontrol" \
        "${root_dir}/build/switching_pc/tools/test_slowcontrol" \
        "${root_dir}/install/bin/test_slowcontrol"
    do
        if [[ -x "${cand}" ]]; then
            printf '%s\n' "${cand}"
            return 0
        fi
    done
    return 1
}

ensure_no_jtag_conflict() {
    if pgrep -f 'quartus_(pgm|stp)' >/dev/null; then
        echo "Refusing to start while another quartus_pgm/quartus_stp process is active." >&2
        exit 2
    fi
}

extract_stp_metadata() {
    readarray -d '' -t stp_meta < <(
        python3 - "${stp_file}" <<'PY'
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
root = ET.parse(path).getroot()
inst = root.find('./instance')
if inst is None:
    raise SystemExit("STP has no instance")
signal_set = root.find('./instance/signal_set')
if signal_set is None:
    raise SystemExit("STP has no signal_set")
trigger = signal_set.find('./trigger')
if trigger is None:
    raise SystemExit("STP has no trigger")
sys.stdout.write(inst.get('name', '') + '\0')
sys.stdout.write(signal_set.get('name', '') + '\0')
sys.stdout.write(trigger.get('name', '') + '\0')
PY
    )

    if [[ "${#stp_meta[@]}" -lt 3 ]]; then
        echo "Failed to extract STP metadata from ${stp_file}" >&2
        exit 2
    fi

    stp_instance="${stp_meta[0]}"
    stp_signal_set="${stp_meta[1]}"
    stp_trigger="${stp_meta[2]}"
}

print_build_info() {
    local alm reg ram wns
    alm="$(awk -F':' '/Logic utilization \(in ALMs\)/{gsub(/^ +| +$/,"",$2); print $2}' "${fit_summary}")"
    reg="$(awk -F':' '/Total registers/{gsub(/^ +| +$/,"",$2); print $2}' "${fit_summary}")"
    ram="$(awk -F':' '/Total RAM Blocks/{gsub(/^ +| +$/,"",$2); print $2}' "${fit_summary}")"
    wns="$(awk '/coreclkout/{getline; if ($1=="Slack") print $3}' "${sta_summary}" | head -n1)"

    echo "Image      : ${sof_file}"
    echo "SignalTap  : ${stp_file}"
    echo "Fit        : ${alm}"
    echo "Registers  : ${reg}"
    echo "RAM Blocks : ${ram}"
    echo "coreclkout : WNS ${wns} ns"
}

run_smoke() {
    echo "[smoke] write ${value} -> ${addr} on link ${link}"
    "${test_bin}" "${link}" --write "${addr}" "${value}" --once
    echo "[smoke] read ${addr} on link ${link}"
    "${test_bin}" "${link}" --read "${addr}" 1 --once
}

run_stp_once() {
    local out_json="${project_dir}/output_files/sc_hw_bringup_stp.json"
    echo "[stp] one strict SignalTap-backed write/read transaction"
    python3 "${sweep_py}" \
        --root "${root_dir}" \
        --test-bin "${test_bin}" \
        --mode scan \
        --iterations 1 \
        --scan-start "$(python3 - "${addr}" <<'PY'
import sys
print(int(sys.argv[1], 0))
PY
)" \
        --seed "${seed}" \
        --link "${link}" \
        --use-signaltap \
        --stp-strict \
        --stp-scan-count 1 \
        --stp-file "${stp_file}" \
        --stp-instance "${stp_instance}" \
        --stp-signal-set "${stp_signal_set}" \
        --stp-trigger "${stp_trigger}" \
        --stp-rx-current-link "${stp_rx_current_link}" \
        --stp-hw-pattern "${hw_pattern}" \
        --out-json "${out_json}"
    echo "[stp] result json: ${out_json}"
}

run_random() {
    local out_json="${project_dir}/output_files/sc_hw_bringup_random.json"
    echo "[random] ${random_ops} mixed-random scratchpad ops on link ${link}"
    python3 "${sweep_py}" \
        --root "${root_dir}" \
        --test-bin "${test_bin}" \
        --mode random \
        --full-scope-profile mixed-random \
        --link "${link}" \
        --seed "${seed}" \
        --random-ops "${random_ops}" \
        --out-json "${out_json}"
    echo "[random] result json: ${out_json}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --phase)
            phase="$2"
            shift 2
            ;;
        --link)
            link="$2"
            shift 2
            ;;
        --addr)
            addr="$2"
            shift 2
            ;;
        --value)
            value="$2"
            shift 2
            ;;
        --seed)
            seed="$2"
            shift 2
            ;;
        --random-ops)
            random_ops="$2"
            shift 2
            ;;
        --hw-pattern)
            hw_pattern="$2"
            shift 2
            ;;
        --stp-rx-current-link)
            stp_rx_current_link="$2"
            shift 2
            ;;
        --skip-signaltap-check)
            skip_signaltap_check="1"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! -f "${sof_file}" ]]; then
    echo "Missing SOF: ${sof_file}" >&2
    exit 2
fi
if [[ ! -f "${fit_summary}" || ! -f "${sta_summary}" ]]; then
    echo "Missing fit/sta summaries in ${project_dir}/output_files" >&2
    exit 2
fi
if [[ ! -f "${stp_file}" ]]; then
    echo "Missing STP: ${stp_file}" >&2
    exit 2
fi

if ! test_bin="$(pick_test_bin)"; then
    echo "Could not find test_slowcontrol binary." >&2
    echo "Build it with:" >&2
    echo "  cmake --build /home/yifeng/packages/online_sc/online/build-codex --target test_slowcontrol" >&2
    exit 2
fi

ensure_no_jtag_conflict
extract_stp_metadata
print_build_info
echo "STP instance : ${stp_instance}"
echo "Signal set   : ${stp_signal_set}"
echo "Trigger      : ${stp_trigger}"

if [[ "${skip_signaltap_check}" != "1" ]]; then
    echo "[check] validating SC SignalTap file"
    "${signaltap_check}"
fi

case "${phase}" in
    all)
        run_smoke
        run_stp_once
        run_random
        ;;
    smoke)
        run_smoke
        ;;
    stp)
        run_stp_once
        ;;
    random)
        run_random
        ;;
    *)
        echo "Unknown phase: ${phase}" >&2
        exit 2
        ;;
esac
