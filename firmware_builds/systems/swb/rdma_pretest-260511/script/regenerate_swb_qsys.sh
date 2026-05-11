#!/usr/bin/env bash
set -euo pipefail

system_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "${system_root}/../../../.." && pwd)"
board="${system_root}/syn/board_projects/swb_a10"
hub="${repo_root}/quartus_systems/swb"
opq_dir="${board}/a10/merger/qsys/opq_upstream_4lane_native_sv"

qsys_script="${QSYS_SCRIPT:-${QUARTUS_ROOTDIR}/sopc_builder/bin/qsys-script}"
qsys_generate="${QSYS_GENERATE:-${QUARTUS_ROOTDIR}/sopc_builder/bin/qsys-generate}"

export OPQ_SOURCE_ROOT="${OPQ_SOURCE_ROOT:-${repo_root}/packet_scheduler}"

"${qsys_script}" \
    --search-path="${hub},$" \
    --script="${system_root}/script/regenerate_opq_upstream_4lane.tcl"

make -C "${board}" pre_flow
make -C "${board}" -B opq_qsys_unpack generated/include.qip

"${qsys_generate}" \
    --synthesis=VHDL \
    --output-directory="${opq_dir}/opq_upstream_4lane" \
    --search-path="${opq_dir},${hub},$" \
    "${opq_dir}/opq_upstream_4lane.qsys"

chmod -R a-w \
    "${hub}/opq_upstream_4lane.qsys" \
    "${opq_dir}/opq_upstream_4lane.qsys" \
    "${opq_dir}/opq_upstream_4lane.sopcinfo" \
    "${opq_dir}/generated" \
    "${opq_dir}/opq_upstream_4lane"

find "${board}/generated" \( -type d -name synthesis -o -type d -name synth \) -exec chmod -R a-w {} +
