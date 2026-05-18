#!/usr/bin/env bash
set -euo pipefail

system_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(git -C "${system_root}" rev-parse --show-toplevel)"
board="${system_root}/syn/board_projects/swb_a10"
hub="${repo_root}/quartus_systems/swb"
opq_dir="${board}/misc/a10/merger/qsys/opq_upstream_4lane_native_sv"

quartus_root="${QUARTUS_ROOTDIR:-/data1/intelFPGA/18.1/quartus}"
qsys_script="${QSYS_SCRIPT:-${quartus_root}/sopc_builder/bin/qsys-script}"
qsys_generate="${QSYS_GENERATE:-${quartus_root}/sopc_builder/bin/qsys-generate}"
opq_synth_debug_level="${OPQ_SYNTH_DEBUG_LEVEL:-0}"
opq_sim_debug_level="${OPQ_SIM_DEBUG_LEVEL:-2}"

export REPO_ROOT="${repo_root}"
export OPQ_SOURCE_ROOT="${OPQ_SOURCE_ROOT:-${repo_root}/packet_scheduler}"

for path in \
    "${opq_dir}/generated" \
    "${opq_dir}/opq_upstream_4lane" \
    "${opq_dir}/simulation" \
    "${opq_dir}/opq_upstream_4lane.qsys" \
    "${opq_dir}/opq_upstream_4lane.sopcinfo"
do
    [ ! -e "${path}" ] || chmod -R u+w "${path}"
done

"${qsys_script}" \
    --search-path="${hub},$" \
    --cmd="set ::OPQ_DEBUG_LEVEL {${opq_synth_debug_level}}; source {${system_root}/script/regenerate_opq_upstream_4lane.tcl}"

make -C "${board}" pre_flow
make -C "${board}" -B opq_qsys_unpack generated/include.qip

"${qsys_generate}" \
    --synthesis=VHDL \
    --clear-output-directory \
    --output-directory="${opq_dir}/opq_upstream_4lane" \
    --search-path="${opq_dir},${hub},$" \
    "${opq_dir}/opq_upstream_4lane.qsys"

[ ! -e "${opq_dir}/simulation" ] || chmod -R u+w "${opq_dir}/simulation"
mkdir -p "${opq_dir}/simulation"
(
    cd "${opq_dir}/simulation"
    "${qsys_script}" \
        --search-path="${opq_dir},${hub},$" \
        --cmd="set ::OPQ_DEBUG_LEVEL {${opq_sim_debug_level}}; source {${opq_dir}/opq_upstream_4lane.tcl}"
)

"${qsys_generate}" \
    --simulation=VERILOG \
    --allow-mixed-language-simulation \
    --clear-output-directory \
    --output-directory="${opq_dir}/simulation" \
    --search-path="${opq_dir},${hub},$" \
    "${opq_dir}/simulation/opq_upstream_4lane.qsys"

chmod -R a-w \
    "${hub}/opq_upstream_4lane.qsys" \
    "${opq_dir}/opq_upstream_4lane.qsys" \
    "${opq_dir}/opq_upstream_4lane.sopcinfo" \
    "${opq_dir}/generated" \
    "${opq_dir}/opq_upstream_4lane" \
    "${opq_dir}/simulation"

find "${board}/generated" \( -type d -name synthesis -o -type d -name synth \) -exec chmod -R a-w {} +
