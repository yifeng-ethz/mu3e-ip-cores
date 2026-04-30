#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  prepare_phase5_frame_hist_path_stp.sh [--sample-depth N] [--trigger-mode high|rising_edge] [--trigger-signal SIGNAL] [--hitstack 0|1|both]

Purpose:
  Regenerate the Phase-5 frame/deassembly/MTS/histogram SignalTap file,
  validate probe names with Quartus Node Finder, and import the STP into the
  top_stp_pipe_phase5_frame_hist Quartus revision.

Notes:
  The Quartus compile must be rerun after this script changes the tapped node
  set, sample depth, or trigger/data vector structure.
EOF
}

sample_depth="1024"
trigger_mode="rising_edge"
trigger_signal=""
hitstack="0"
project="top"
revision="top_stp_pipe_phase5_frame_hist"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sample-depth)
            sample_depth="$2"
            shift 2
            ;;
        --trigger-mode)
            trigger_mode="$2"
            shift 2
            ;;
        --trigger-signal)
            trigger_signal="$2"
            shift 2
            ;;
        --hitstack)
            hitstack="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if ! [[ "${sample_depth}" =~ ^[0-9]+$ ]] || [[ "${sample_depth}" -le 0 ]]; then
    echo "ERROR: --sample-depth must be a positive integer (got '${sample_depth}')" >&2
    exit 2
fi

if [[ "${trigger_mode}" != "high" && "${trigger_mode}" != "rising_edge" ]]; then
    echo "ERROR: --trigger-mode must be 'high' or 'rising_edge' (got '${trigger_mode}')" >&2
    exit 2
fi

if [[ "${hitstack}" != "0" && "${hitstack}" != "1" && "${hitstack}" != "both" ]]; then
    echo "ERROR: --hitstack must be '0', '1', or 'both' (got '${hitstack}')" >&2
    exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
system_dir="$(cd -- "${script_dir}/.." && pwd)"
project_dir="${system_dir}/syn/board_projects/fe_scifi_feb_v3"
generator="${system_dir}/script/generate_phase5_frame_hist_path_stp.py"
validator="${HOME}/.codex/skills/signaltap-creation-co-debug/scripts/check_stp_nodes.py"
stp_file="${system_dir}/signaltap/phase5_frame_hist_path.stp"
report_file="${system_dir}/signaltap/phase5_frame_hist_path.nodes.md"

if ! command -v quartus_stp >/dev/null 2>&1; then
    echo "ERROR: quartus_stp not found in PATH" >&2
    exit 2
fi

if pgrep -af "quartus_sh --flow compile ${project} -c ${revision}|quartus_map .* ${project} -c ${revision}|quartus_fit .* ${project} -c ${revision}|quartus_asm .* ${project} -c ${revision}|quartus_sta .* ${project} -c ${revision}" >/dev/null 2>&1; then
    echo "ERROR: Quartus compile appears to be active for ${project}/${revision}; refusing to rebind SignalTap mid-build" >&2
    exit 3
fi

echo "PREPARE_PHASE5_STP_PROJECT_DIR  : ${project_dir}"
echo "PREPARE_PHASE5_STP_FILE         : ${stp_file}"
echo "PREPARE_PHASE5_STP_REPORT       : ${report_file}"
echo "PREPARE_PHASE5_STP_TRIGGER_MODE : ${trigger_mode}"
echo "PREPARE_PHASE5_STP_HITSTACK     : ${hitstack}"
if [[ -n "${trigger_signal}" ]]; then
    echo "PREPARE_PHASE5_STP_TRIGGER_NODE : ${trigger_signal}"
fi
echo "PREPARE_PHASE5_STP_SAMPLE_DEPTH : ${sample_depth}"

generator_args=(
    --sample-depth "${sample_depth}"
    --trigger-mode "${trigger_mode}"
    --hitstack "${hitstack}"
    --output "${stp_file}"
)
if [[ -n "${trigger_signal}" ]]; then
    generator_args+=(--trigger-signal "${trigger_signal}")
fi

python3 "${generator}" "${generator_args[@]}"

python3 "${validator}" \
    --project-dir "${project_dir}" \
    --project "${project}" \
    --revision "${revision}" \
    --stp-file "${stp_file}" \
    --observable-type stp_pre_synthesis \
    --report-out "${report_file}"

(
    cd -- "${project_dir}"
    quartus_stp "${project}" -c "${revision}" --enable --stp_file="${stp_file}"
)

echo "PREPARE_PHASE5_STP_DONE"
