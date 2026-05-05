#!/usr/bin/env bash
set -euo pipefail

script_dir=$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)
system_dir=$(
    cd -- "${script_dir}/.." && pwd
)
syn_dir="${system_dir}/syn"
repo_root=$(
    cd -- "${system_dir}/../../.." && pwd
)

inner_name="full8lane_type0_datapath"
control_name="full8lane_control_path_subsystem"
supercore_name="arb_hit_type0_supercore"
outer_name="full8lane_type0_system"
ipx_path="${syn_dir}/mu3e_ip_cores.ipx"
components_ipx_path="${syn_dir}/components.ipx"
upload_readyless_ip_dir="${syn_dir}/ip/upload_system_v3_readyless"
hit_stack_readyless_ip_dir="${syn_dir}/ip/hit_stack_system_readyless"
full8lane_onewire_ip_dir="${syn_dir}/ip/full8lane_onewire_master"
full8lane_sc_hub_ip_dir="${syn_dir}/ip/full8lane_sc_hub_v2"
full8lane_histogram_ip_dir="${syn_dir}/ip/full8lane_histogram_statistics_v2"
histogram_compat_ip_dir="${syn_dir}/ip/histogram_statistics_v2"
search_path="${syn_dir},${repo_root}/misc/arb_hit_type0/script,${upload_readyless_ip_dir},${hit_stack_readyless_ip_dir},${full8lane_onewire_ip_dir},${full8lane_sc_hub_ip_dir},${full8lane_histogram_ip_dir},${histogram_compat_ip_dir},${ipx_path},${components_ipx_path},\$"

for name in "${control_name}" "${supercore_name}" "${inner_name}" "${outer_name}"; do
    for path in \
        "${syn_dir}/${name}.qsys" \
        "${syn_dir}/${name}.sopcinfo" \
        "${syn_dir}/${name}/synthesis"; do
        if [[ -e "${path}" ]]; then
            chmod -R a+w "${path}"
        fi
    done
done

(
    cd "${syn_dir}"

    mkdir -p "${upload_readyless_ip_dir}" "${hit_stack_readyless_ip_dir}"

    for path in "${ipx_path}" "${components_ipx_path}"; do
        if [[ -e "${path}" ]]; then
            chmod a+w "${path}"
        fi
    done

    ip-make-ipx \
        --source-directory="${repo_root}" \
        --output="${ipx_path}" \
        --thorough-descent \
        --relative-vars=PWD

    FULL8LANE_SYSTEM_DIR="${system_dir}" \
    FULL8LANE_SYN_DIR="${syn_dir}" \
    qsys-script --search-path="${search_path}" --script="build_full8lane_system.tcl"
)

for name in "${control_name}" "${supercore_name}" "${inner_name}" "${outer_name}"; do
    for path in \
        "${syn_dir}/${name}.qsys" \
        "${syn_dir}/${name}.sopcinfo" \
        "${syn_dir}/${name}/synthesis"; do
        if [[ -e "${path}" ]]; then
            chmod -R a-w "${path}"
        fi
    done
done
