#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/run_rc.sh"
"${SCRIPT_DIR}/run_sc.sh"
"${SCRIPT_DIR}/run_dp_e2e.sh"

