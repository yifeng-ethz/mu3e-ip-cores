#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  prepare_phase5_injector_path_stp.sh [--sample-depth N] [--trigger-mode high|rising_edge] [--profile micro|compact]

Purpose:
  Regenerate the Phase-5 injector-to-emulator SignalTap file,
  validate probe names with Quartus Node Finder, and import the STP into the
  top_stp_pipe_phase5_injector Quartus revision.

Notes:
  Run quartus_map after this script and check the SignalTap connection table
  before starting a full fit/asm/sta compile.
EOF
}

sample_depth="1024"
trigger_mode="rising_edge"
profile="micro"
project="top"
revision="top_stp_pipe_phase5_injector"

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
        --profile)
            profile="$2"
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

if [[ "${profile}" != "micro" && "${profile}" != "compact" ]]; then
    echo "ERROR: --profile must be 'micro' or 'compact' (got '${profile}')" >&2
    exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
system_dir="$(cd -- "${script_dir}/.." && pwd)"
project_dir="${system_dir}/syn/board_projects/fe_scifi_feb_v3"
generator="${system_dir}/script/generate_phase5_injector_path_stp.py"
validator="${HOME}/.codex/skills/signaltap-creation-co-debug/scripts/check_stp_nodes.py"
stp_file="${system_dir}/signaltap/phase5_injector_path_lvds.stp"
report_file="${system_dir}/signaltap/phase5_injector_path_lvds.nodes.md"

if ! command -v quartus_stp >/dev/null 2>&1; then
    echo "ERROR: quartus_stp not found in PATH" >&2
    exit 2
fi

if pgrep -af "quartus_sh --flow compile ${project} -c ${revision}|quartus_map .* ${project} -c ${revision}|quartus_fit .* ${project} -c ${revision}|quartus_asm .* ${project} -c ${revision}|quartus_sta .* ${project} -c ${revision}" >/dev/null 2>&1; then
    echo "ERROR: Quartus compile appears to be active for ${project}/${revision}; refusing to rebind SignalTap mid-build" >&2
    exit 3
fi

echo "PREPARE_PHASE5_INJECTOR_STP_PROJECT_DIR  : ${project_dir}"
echo "PREPARE_PHASE5_INJECTOR_STP_FILE         : ${stp_file}"
echo "PREPARE_PHASE5_INJECTOR_STP_REPORT       : ${report_file}"
echo "PREPARE_PHASE5_INJECTOR_STP_TRIGGER_MODE : ${trigger_mode}"
echo "PREPARE_PHASE5_INJECTOR_STP_SAMPLE_DEPTH : ${sample_depth}"
echo "PREPARE_PHASE5_INJECTOR_STP_PROFILE      : ${profile}"

python3 "${generator}" \
    --sample-depth "${sample_depth}" \
    --trigger-mode "${trigger_mode}" \
    --profile "${profile}" \
    --output "${stp_file}"

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

echo "PREPARE_PHASE5_INJECTOR_STP_DONE"
