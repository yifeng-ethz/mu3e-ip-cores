#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: regenerate_ipx_catalog.sh [--root <dir>] [--relative-var <name>] [--output <file>]...

Regenerate the Platform Designer catalogs for this repository.

Defaults:
  --root         repository root (defaults to parent of this script)
  --relative-var MU3E_IP_CORES_ROOT (emit portable file paths)
  --absolute     emit absolute file paths instead
  --output       components.ipx
  --output       mu3e_ip_cores.ipx

When --relative-var is used, Quartus must see that variable exported and
pointing at --root when it consumes the generated catalog.
EOF
}

script_dir=$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)
root_dir="${script_dir}/.."
relative_var="MU3E_IP_CORES_ROOT"
declare -a outputs=(
    "components.ipx"
    "mu3e_ip_cores.ipx"
)

while (($# > 0)); do
    case "$1" in
        --root)
            root_dir=$2
            shift 2
            ;;
        --relative-var)
            relative_var=$2
            shift 2
            ;;
        --absolute)
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
norm_ipx="${tmp_dir}/components.norm.ipx"

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

declare -a normalize_args=(
    "--input" "${tmp_ipx}"
    "--output" "${norm_ipx}"
    "--root" "${root_dir}"
)
if [[ -n "${relative_var}" ]]; then
    normalize_args+=("--relative-var" "${relative_var}")
fi

python3 "${script_dir}/normalize_ipx_catalog.py" "${normalize_args[@]}"

component_count=$(grep -c '^[[:space:]]*<component' "${norm_ipx}")
if ((component_count == 0)); then
    echo "ERROR: generated catalog contains no components: ${norm_ipx}" >&2
    exit 1
fi

for output_name in "${outputs[@]}"; do
    if [[ "${output_name}" = /* ]]; then
        output_path="${output_name}"
    else
        output_path="${script_dir}/${output_name}"
    fi
    install -m 0644 "${norm_ipx}" "${output_path}"
    echo "Wrote ${output_path}"
done

echo "Catalog root : ${root_dir}"
echo "Catalog dir  : ${script_dir}"
echo "Component cnt: ${component_count}"
if [[ -n "${relative_var}" ]]; then
    echo "Relative var : ${relative_var}=${root_dir}"
else
    echo "Path mode    : absolute"
fi
