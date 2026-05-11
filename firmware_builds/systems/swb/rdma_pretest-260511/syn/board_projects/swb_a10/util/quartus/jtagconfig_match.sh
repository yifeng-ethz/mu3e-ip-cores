#/bin/bash
set -euf

script="$(readlink -f -- "$0")"
script="${script%.sh}.awk"

cable="${1:-}"
device="${2:-}"

jtagconfig | awk -f "$script" -v "cable=$cable" -v "device=$device"
