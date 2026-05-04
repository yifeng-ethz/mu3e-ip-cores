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
qsys_path="${syn_dir}/focus_emulator_type0_system.qsys"
sopcinfo_path="${syn_dir}/focus_emulator_type0_system.sopcinfo"
synthesis_dir="${syn_dir}/focus_emulator_type0_system/synthesis"
ipx_path="${syn_dir}/mu3e_ip_cores.ipx"
search_path="${syn_dir},${system_dir}/ip,${syn_dir}/components.ipx,\$"

for path in "${qsys_path}" "${sopcinfo_path}" "${synthesis_dir}"; do
    if [[ -e "${path}" ]]; then
        chmod -R a+w "${path}"
    fi
done

(
    cd "${syn_dir}"
    if [[ -e "${ipx_path}" ]]; then
        chmod a+w "${ipx_path}"
    fi
    ip-make-ipx \
        --source-directory="${repo_root}" \
        --output="${ipx_path}" \
        --thorough-descent \
        --relative-vars=PWD

    FOCUS_SYSTEM_DIR="${system_dir}" \
    FOCUS_SYN_DIR="${syn_dir}" \
    qsys-script --search-path="${search_path}" --script="build_emulator_type0_system.tcl"
)

for path in "${qsys_path}" "${sopcinfo_path}" "${synthesis_dir}"; do
    if [[ -e "${path}" ]]; then
        chmod -R a-w "${path}"
    fi
done
