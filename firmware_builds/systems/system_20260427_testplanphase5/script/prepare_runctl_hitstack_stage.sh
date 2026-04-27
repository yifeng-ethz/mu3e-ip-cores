#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  prepare_runctl_hitstack_stage.sh --target {0|1} [--sample-depth N] [--trigger-mode MODE]

Purpose:
  Regenerate one narrow hit-stack SignalTap pass, validate all probe names with
  Quartus Node Finder, and bind the STP into the FEB project.

Safety:
  Refuses to touch the project while a Quartus compile is already running for
  the same revision.
EOF
}

target=""
sample_depth="512"
trigger_mode="high"
project="top"
revision="top"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            target="$2"
            shift 2
            ;;
        --sample-depth)
            sample_depth="$2"
            shift 2
            ;;
        --trigger-mode)
            trigger_mode="$2"
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

if [[ -z "${target}" ]]; then
    echo "ERROR: --target is required" >&2
    usage >&2
    exit 2
fi

if [[ "${target}" != "0" && "${target}" != "1" ]]; then
    echo "ERROR: --target must be 0 or 1 (got '${target}')" >&2
    exit 2
fi

if ! [[ "${sample_depth}" =~ ^[0-9]+$ ]] || [[ "${sample_depth}" -le 0 ]]; then
    echo "ERROR: --sample-depth must be a positive integer (got '${sample_depth}')" >&2
    exit 2
fi

if [[ "${trigger_mode}" != "high" && "${trigger_mode}" != "rising_edge" ]]; then
    echo "ERROR: --trigger-mode must be 'high' or 'rising_edge' (got '${trigger_mode}')" >&2
    exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
system_dir="$(cd -- "${script_dir}/.." && pwd)"
repo_root="$(cd -- "${script_dir}/../../../.." && pwd)"
project_dir="${repo_root}/board_projects/fe_scifi_feb_v3"
generator="${system_dir}/script/generate_runctl_hitstack_stage_stp.py"
validator="${HOME}/.codex/skills/signaltap-creation-co-debug/scripts/check_stp_nodes.py"
stp_file="${system_dir}/signaltap/phase4d_runctl_hitstack${target}_stage.stp"
report_file="${system_dir}/signaltap/phase4d_runctl_hitstack${target}_stage_nodes.md"

if ! command -v quartus_stp >/dev/null 2>&1; then
    echo "ERROR: quartus_stp not found in PATH" >&2
    exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found in PATH" >&2
    exit 2
fi

if [[ ! -f "${generator}" ]]; then
    echo "ERROR: missing generator: ${generator}" >&2
    exit 2
fi

if [[ ! -f "${validator}" ]]; then
    echo "ERROR: missing validator: ${validator}" >&2
    exit 2
fi

if pgrep -af "quartus_sh --flow compile ${project} -c ${revision}|quartus_map .* ${project} -c ${revision}|quartus_fit .* ${project} -c ${revision}|quartus_asm .* ${project} -c ${revision}|quartus_sta .* ${project} -c ${revision}" >/dev/null 2>&1; then
    echo "ERROR: Quartus compile appears to be active for ${project}/${revision}; refusing to rebind SignalTap mid-build" >&2
    exit 3
fi

echo "PREPARE_STAGE_TARGET       : ${target}"
echo "PREPARE_STAGE_PROJECT_DIR  : ${project_dir}"
echo "PREPARE_STAGE_STP          : ${stp_file}"
echo "PREPARE_STAGE_REPORT       : ${report_file}"
echo "PREPARE_STAGE_TRIGGER_MODE : ${trigger_mode}"
echo "PREPARE_STAGE_SAMPLE_DEPTH : ${sample_depth}"

python3 "${generator}" \
    --target "${target}" \
    --sample-depth "${sample_depth}" \
    --trigger-mode "${trigger_mode}" \
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

echo "PREPARE_STAGE_DONE         : target=${target}"
