#!/usr/bin/env bash
set -euo pipefail

tb_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
system_dir="$(cd "${tb_dir}/.." && pwd)"

echo "tb_int uses the focus-build Qsys regenerator; no raw XML edits are allowed."
echo "Running ${system_dir}/script/regen_focus_system.sh"
exec "${system_dir}/script/regen_focus_system.sh"
