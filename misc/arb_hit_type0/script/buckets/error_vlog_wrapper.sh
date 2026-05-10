#!/usr/bin/env bash
set -euo pipefail

real_vlog=$1
sim_dir=$2
uvm_dir=$3
shift 3

src=""
for arg in "$@"; do
  if [[ "$arg" == *.sv ]]; then
    src=$arg
  fi
done

if [[ "$src" =~ /tb/uvm/(sequence|test)/([^/]+)/[^/]+\.sv$ ]]; then
  exit 0
fi

if [[ "$src" == "${uvm_dir}/tb_top.sv" ]]; then
  prelude="${sim_dir}/bucket_error_tb_top_prelude.sv"
  cat > "$prelude" <<'PRELUDE'
import uvm_pkg::*;
import lcg_prng_pkg::*;
import arb_hit_type0_reg_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"
`define ARB_HIT_TYPE0_ERROR_IN_PKG
PRELUDE

  mapfile -t files < <(find "${uvm_dir}/sequence/error" "${uvm_dir}/test/error" -name '*.sv' -print 2>/dev/null | sort)
  args=()
  for arg in "$@"; do
    if [[ "$arg" != "$src" ]]; then
      args+=("$arg")
    fi
  done
  args+=("-mfcu" "-cuname" "error_tb_top_cu" "$prelude")
  args+=("${files[@]}")
  args+=("$src")
  "$real_vlog" "${args[@]}"
  exit 0
fi

"$real_vlog" "$@"
