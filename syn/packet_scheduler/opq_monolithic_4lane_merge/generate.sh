#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "${script_dir}/../../.." && pwd)

qsys_script_bin="${QSYS_SCRIPT_BIN:-qsys-script}"
qsys_generate_bin="${QSYS_GENERATE_BIN:-qsys-generate}"
search_path="${repo_root}/quartus_system,$"

pushd "${script_dir}" >/dev/null

"${qsys_script_bin}" \
    --search-path="${search_path}" \
    --script="${script_dir}/opq_monolithic_4lane_merge.tcl"

"${qsys_generate_bin}" \
    "${script_dir}/opq_monolithic_4lane_merge.qsys" \
    --search-path="${search_path}" \
    --synthesis=VHDL \
    --family="Arria V" \
    --part=5AGXBA7D4F31C5 \
    --output-directory="${script_dir}/generated"

popd >/dev/null
