#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: regenerate_ipx_catalog.sh [--root <dir>] [--relative-var <name>] [--output <file>]...

Regenerate the Platform Designer catalogs for this repository.

Defaults:
  --root         repository root (defaults to parent of this script)
  --relative     emit file paths relative to the catalog location (default)
  --relative-var MU3E_IP_CORES_ROOT (emit env-var-prefixed file paths instead)
  --absolute     emit absolute file paths instead
  --output       mu3e_ip_cores.ipx
  --output       components.ipx (compatibility wrapper that indexes the primary catalog)

When --relative-var is used, Quartus must see that variable exported and
pointing at --root when it consumes the generated catalog. Relative-path
mode keeps the catalog self-contained and suitable for import from a
project-local wrapper IPX.
EOF
}

script_dir=$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)
system_dir=$(
    cd -- "${script_dir}/.." && pwd
)
root_dir=$(
    cd -- "${script_dir}/../../../.." && pwd
)
path_mode="relative"
relative_var=""
declare -a outputs=(
    "../syn/components.ipx"
    "../syn/mu3e_ip_cores.ipx"
)

while (($# > 0)); do
    case "$1" in
        --root)
            root_dir=$2
            shift 2
            ;;
        --relative-var)
            path_mode="relative_var"
            relative_var=$2
            shift 2
            ;;
        --relative)
            path_mode="relative"
            relative_var=""
            shift
            ;;
        --absolute)
            path_mode="absolute"
            relative_var=""
            shift
            ;;
        --output)
            if ((${#outputs[@]} == 2)) && [[ ${outputs[0]} == "components.ipx" ]] && [[ ${outputs[1]} == "mu3e_ip_cores.ipx" ]]; then
                outputs=()
            fi
            outputs+=("$2")
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

root_dir=$(
    cd -- "${root_dir}" && pwd
)

if ! command -v ip-make-ipx >/dev/null 2>&1; then
    echo "ERROR: ip-make-ipx is not in PATH" >&2
    exit 1
fi

tmp_dir=$(mktemp -d)
cleanup() {
    rm -rf -- "${tmp_dir}"
}
trap cleanup EXIT

tmp_ipx="${tmp_dir}/components.ipx"

declare -a ip_make_args=(
    "--source-directory=${root_dir}"
    "--output=${tmp_ipx}"
    --thorough-descent
)

ip-make-ipx "${ip_make_args[@]}"

if [[ ! -s "${tmp_ipx}" ]]; then
    echo "ERROR: generated catalog is empty: ${tmp_ipx}" >&2
    exit 1
fi

component_count=""
declare -a resolved_outputs=()
declare -a wrapper_outputs=()
declare -a full_outputs=()

for output_name in "${outputs[@]}"; do
    if [[ "${output_name}" = /* ]]; then
        output_path="${output_name}"
    else
        output_path="${script_dir}/${output_name}"
    fi
    resolved_outputs+=("${output_path}")
    if [[ $(basename -- "${output_path}") == "components.ipx" ]]; then
        wrapper_outputs+=("${output_path}")
    else
        full_outputs+=("${output_path}")
    fi
done

if ((${#full_outputs[@]} == 0)); then
    full_outputs+=("${wrapper_outputs[0]}")
    wrapper_outputs=("${wrapper_outputs[@]:1}")
fi

primary_catalog_path="${full_outputs[0]}"

for output_path in "${full_outputs[@]}"; do

    norm_ipx="${tmp_dir}/$(basename -- "${output_path}").norm.ipx"
    declare -a normalize_args=(
        "--input" "${tmp_ipx}"
        "--output" "${norm_ipx}"
        "--root" "${root_dir}"
    )
    case "${path_mode}" in
        relative)
            normalize_args+=("--catalog-dir" "$(dirname -- "${output_path}")")
            ;;
        relative_var)
            normalize_args+=("--relative-var" "${relative_var}")
            ;;
        absolute)
            ;;
        *)
            echo "ERROR: unsupported path mode: ${path_mode}" >&2
            exit 1
            ;;
    esac

    python3 "${script_dir}/normalize_ipx_catalog.py" "${normalize_args[@]}"

    if [[ -z "${component_count}" ]]; then
        component_count=$(grep -c '^[[:space:]]*<component' "${norm_ipx}")
        if ((component_count == 0)); then
            echo "ERROR: generated catalog contains no components: ${norm_ipx}" >&2
            exit 1
        fi
    fi

    install -m 0644 "${norm_ipx}" "${output_path}"
    echo "Wrote ${output_path}"
done

for output_path in "${wrapper_outputs[@]}"; do
    wrapper_target_rel=$(python3 - <<'PY' "$(dirname -- "${output_path}")" "${primary_catalog_path}"
import os
import sys
print(os.path.relpath(sys.argv[2], sys.argv[1]))
PY
)
    cat >"${output_path}" <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<library>
 <index file="${wrapper_target_rel}"/>
</library>
EOF
    echo "Wrote ${output_path} (wrapper -> ${wrapper_target_rel})"
done

echo "Catalog root : ${root_dir}"
echo "Catalog dir  : ${script_dir}"
echo "Component cnt: ${component_count}"
if [[ "${path_mode}" == "relative_var" ]]; then
    echo "Relative var : ${relative_var}=${root_dir}"
elif [[ "${path_mode}" == "relative" ]]; then
    echo "Path mode    : relative"
else
    echo "Path mode    : absolute"
fi
