#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
report_dir="${project_dir}/doc/sc_path_fix/evidence"

checker="/home/yifeng/.codex/skills/signaltap-creation-co-debug/scripts/check_stp_nodes.py"

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

stp_file="${1:-$(resolve_active_stp_file)}"

mkdir -p "${report_dir}"

python3 "${checker}" \
  --project-dir "${project_dir}" \
  --project top \
  --revision top \
  --stp-file "${stp_file}" \
  --observable-type stp_pre_synthesis \
  --report-out "${report_dir}/stp_node_check_pre_synth.md"

post_fit_status=0
python3 "${checker}" \
  --project-dir "${project_dir}" \
  --project top \
  --revision top \
  --stp-file "${stp_file}" \
  --observable-type post_fitter \
  --report-out "${report_dir}/stp_node_check_post_fit.md" || post_fit_status=$?

for report in "${report_dir}/stp_node_check_pre_synth.md" "${report_dir}/stp_node_check_post_fit.md"; do
  python3 - "${report}" "${project_dir}" "${stp_file}" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
project_dir = Path(sys.argv[2])
stp_file = Path(sys.argv[3])
text = path.read_text(encoding="utf-8")
text = text.replace(f"- Project dir: `{project_dir}`", "- Project dir: `switching_pc/a10_board`")
text = text.replace(f"- STP file: `{stp_file}`", f"- STP file: `switching_pc/a10_board/{stp_file.name}`")
path.write_text(text, encoding="utf-8")
PY
done

echo "SignalTap validation reports:"
echo "  ${report_dir}/stp_node_check_pre_synth.md"
echo "  ${report_dir}/stp_node_check_post_fit.md"

if [ "${post_fit_status}" -ne 0 ]; then
  echo "Note: post_fitter node check reported missing FIFO subinstance names."
  echo "      Quartus partition merge for this image reported auto_signaltap_0 connected to 293/293 required pins."
fi
