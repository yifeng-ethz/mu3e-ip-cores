#!/bin/bash
# Shared FEB v3 Platform Designer search-path builder.

set -u

_QSYS_SEARCH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${MU3E_IP_CORES_ROOT:=$(realpath -m -- "${_QSYS_SEARCH_SCRIPT_DIR}/../../../..")}"

SEARCH_PATHS="${SEARCH_PATHS:-}"
USER_COMPONENT_PATHS="${USER_COMPONENT_PATHS:-}"
QSYS_SEARCH_PATH_COUNT="${QSYS_SEARCH_PATH_COUNT:-0}"
QSYS_SEARCH_PATH_SEEN=":"

qsys_is_forbidden_path() {
    local candidate="$1"
    local resolved_root resolved_candidate resolved_system

    resolved_root="$(realpath -m -- "${MU3E_IP_CORES_ROOT}")"
    resolved_candidate="$(realpath -m -- "${candidate}")"
    resolved_system="${SYSTEM_DIR:+$(realpath -m -- "${SYSTEM_DIR}")}"

    # Tightened policy (per feedback_qsys_apr27_pollution memory + 2026-05-18
    # IP-version audit): EVERY firmware_builds/systems/ subtree is forbidden as
    # an IP _hw.tcl search path. Per-system ip/<X>/ copies are stale duplicates
    # of the canonical IP that lives in misc/<X>/ or in the submodule root.
    # Only the active system's qsys_tcl/ is allowed (and even that is for
    # parameter/composite Tcl, not standalone IP definitions).
    case "${resolved_candidate}" in
        "${resolved_root}/firmware_builds/systems/"*)
            if [ -n "${resolved_system}" ] && [ "${resolved_candidate}" = "${resolved_system}/qsys_tcl" -o -n "${resolved_candidate##${resolved_system}/qsys_tcl/*}" -a "${resolved_candidate#${resolved_system}/qsys_tcl/}" != "${resolved_candidate}" ]; then
                # allow active-system qsys_tcl/ only (the patcher Tcl, not IPs)
                :
            else
                return 0
            fi
            ;;
    esac

    case "${resolved_candidate}" in
        "${resolved_root}/.git"|\
        "${resolved_root}/.git/"*|\
        "${resolved_root}/.worktrees"|\
        "${resolved_root}/.worktrees/"*|\
        */trash_bin|\
        */trash_bin/*)
            return 0
            ;;
    esac

    return 1
}

qsys_append_search_path() {
    local candidate="$1"
    local resolved

    [ -d "${candidate}" ] || return 0
    qsys_is_forbidden_path "${candidate}" && return 0

    resolved="$(realpath -- "${candidate}")"
    case "${QSYS_SEARCH_PATH_SEEN}" in
        *":${resolved}:"*)
            return 0
            ;;
    esac

    if [ -n "${SEARCH_PATHS}" ]; then
        SEARCH_PATHS="${SEARCH_PATHS},${resolved}"
    else
        SEARCH_PATHS="${resolved}"
    fi

    USER_COMPONENT_PATHS="${USER_COMPONENT_PATHS}${resolved}"$'\n'
    QSYS_SEARCH_PATH_SEEN="${QSYS_SEARCH_PATH_SEEN}${resolved}:"
    QSYS_SEARCH_PATH_COUNT=$((QSYS_SEARCH_PATH_COUNT + 1))
}

qsys_append_ip_helpers() {
    local ip_dir="$1"

    qsys_append_search_path "${ip_dir}"
    qsys_append_search_path "${ip_dir}/script"
    qsys_append_search_path "${ip_dir}/legacy"
    qsys_append_search_path "${ip_dir}/reference"

    if [ -d "${ip_dir}/legacy" ]; then
        while IFS= read -r legacy_dir; do
            qsys_append_search_path "${legacy_dir}"
        done < <(find "${ip_dir}/legacy" -type f -name '*_hw.tcl' -printf '%h\n' | sort -u)
    fi

    if [ -d "${ip_dir}/reference" ]; then
        while IFS= read -r reference_dir; do
            qsys_append_search_path "${reference_dir}"
        done < <(find "${ip_dir}/reference" -type f \( -name '*_hw.tcl' -o -name '*.qsys' \) -printf '%h\n' | sort -u)
    fi
}

qsys_collect_active_search_paths() {
    local root="${1:-${MU3E_IP_CORES_ROOT}}"
    local hw_tcl hw_dir ip_dir qsys_dir

    root="$(realpath -- "${root}")"

    if [ -n "${SYSTEM_DIR:-}" ] && [ -d "${SYSTEM_DIR}/quartus_systems" ]; then
        while IFS= read -r qsys_dir; do
            qsys_append_search_path "${qsys_dir}"
        done < <(find "${SYSTEM_DIR}/quartus_systems" -type f -name '*.qsys' -printf '%h\n' | sort -u)
    fi

    if [ -d "${root}/quartus_systems" ]; then
        while IFS= read -r qsys_dir; do
            qsys_append_search_path "${qsys_dir}"
        done < <(find "${root}/quartus_systems" -type f -name '*.qsys' -printf '%h\n' | sort -u)
    fi

    while IFS= read -r hw_tcl; do
        hw_dir="$(dirname -- "${hw_tcl}")"
        ip_dir="${hw_dir}"

        case "${hw_dir}" in
            */script)
                ip_dir="${hw_dir%/script}"
                ;;
            */legacy)
                ip_dir="${hw_dir%/legacy}"
                ;;
            */legacy/*)
                ip_dir="${hw_dir%%/legacy/*}"
                ;;
        esac

        qsys_append_ip_helpers "${ip_dir}"
        qsys_append_search_path "${hw_dir}"
    done < <(
        find "${root}" \
            -path "${root}/.git" -prune -o \
            -path "${root}/.worktrees" -prune -o \
            -path "${root}/firmware_builds/systems/system_20260427_testplanphase5" -prune -o \
            -path "${root}/firmware_builds/systems/*/syn" -prune -o \
            -type f -name '*_hw.tcl' -print | sort
    )
}

qsys_create_isolated_user_catalog() {
    local qsys_user_root

    qsys_user_root="$(mktemp -d "${TMPDIR:-/tmp}/qsys_user_catalog.XXXXXX")"
    mkdir -p "${qsys_user_root}/ip/18.1/ip_search_path"
    {
        printf '%s\n' '<library>'
        printf '%s' "${USER_COMPONENT_PATHS}" | awk 'NF && !seen[$0]++ { printf " <path path=\"%s/**/*\" />\n", $0 }'
        printf '%s\n' '</library>'
    } > "${qsys_user_root}/ip/18.1/ip_search_path/user_components.ipx"

    export HOME="${qsys_user_root}"
    export IP_USERDIR="${qsys_user_root}/ip/18.1"
    export IP_GLOBALDIR="${qsys_user_root}/ip/18.1"
    export QSYS_USER_CATALOG_ROOT="${qsys_user_root}"
}
