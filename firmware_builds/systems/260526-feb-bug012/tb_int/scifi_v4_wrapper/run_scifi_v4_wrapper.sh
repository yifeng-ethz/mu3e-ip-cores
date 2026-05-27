#!/usr/bin/env bash
#
# Wrapper-only integration TB driver for scifi_datapath_system_v4.
# Practices the "no driver inside the DUT" rule from
# firmware_builds/systems/260518-feb-ok/doc/LESSONS_LEARNT_BUG027.md
# and auto-memory feedback_tb_int_must_compile_qsys_wrapper.md.
#
# Pipeline:
#   1. scripts/qsys_generate_recursive.py
#      Walks scifi_datapath_system_v4.qsys hierarchy, runs
#      qsys-generate --simulation on every project subsystem in
#      parallel (~22s wall for the v4 design), and backfills any
#      missing modules from the synth tree. Quartus 18.1's CLI
#      qsys-generate is non-recursive; this tool reproduces the GUI's
#      Generate-Testbench-System recursive behaviour.
#   2. scripts/multipass_compile.py
#      Sources msim_setup.tcl to create per-IP library dirs + compile
#      stock altera_ver/lpm_ver/altera_mf_ver/arriav_ver, then drives
#      vcom/vlog multi-pass with retry-on-failure until all VHDL
#      dependency cycles converge. Replaces the previous per-IP awk
#      reorder patches.
#   3. Multipass also vlogs the TB sources into work and runs vsim with
#      the elab -L list taken verbatim from msim_setup.tcl's elab
#      alias (preserves the full per-IP library list - no hand-curated
#      list to drift out of sync).
#
# The vcom file list is entirely owned by qsys-generate + the recursive
# tool. This script hand-lists NO leaf IP source files; the only TB
# source it points at is tb_scifi_v4_wrapper.sv, which itself
# instantiates `scifi_datapath_system_v4 dut` and drives ONLY the
# wrapper's entity-port nets. JTAG hub is left idle per the
# 2026-05-19 direction.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$(realpath -m -- "${SCRIPT_DIR}/../..")"
SIM_ROOT="${BUILD_DIR}/generated/simulation/scifi_datapath_system_v4/simulation"
MSIM_SETUP="${SIM_ROOT}/mentor/msim_setup.tcl"
STAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="${SCRIPT_DIR}/REPORT"
RUN_DIR="${REPORT_DIR}/scifi_v4_wrapper_${STAMP}"

QUESTA_HOME="${QUESTA_HOME:-/data1/questaone_sim-2026.1_1/questasim}"
QUARTUS_HOME="${QUARTUS_HOME:-/data1/intelFPGA/18.1/quartus}"

export LM_LICENSE_FILE="8161@lic-mentor.ethz.ch"
export MGLS_LICENSE_FILE="${LM_LICENSE_FILE}"
export SALT_LICENSE_SERVER="${LM_LICENSE_FILE}"

mkdir -p "${RUN_DIR}"

# Step 1: ensure recursive qsys-generate has run and the sim tree is
# complete (will be a no-op when up-to-date).
if [[ ! -f "${MSIM_SETUP}" ]] || [[ -n "${FORCE_QSYS_GEN:-}" ]]; then
    echo "[run] running recursive qsys-generate (this is one-time per qsys edit)"
    # Unlock any read-only outputs from prior runs.
    find "${BUILD_DIR}/generated/simulation" -mindepth 1 -type f -exec chmod u+w {} + 2>/dev/null || true
    find "${BUILD_DIR}/generated/simulation" -mindepth 1 -type d -exec chmod u+w {} + 2>/dev/null || true
    python3 "${BUILD_DIR}/scripts/qsys_generate_recursive.py" \
        --top scifi_datapath_system_v4 --jobs 8
fi

if [[ ! -f "${MSIM_SETUP}" ]]; then
    echo "FATAL: ${MSIM_SETUP} not found after recursive qsys-generate" >&2
    exit 2
fi

# Step 1b: stage the MTS coarse-time decode ROM into the run dir.
# mts_processor.vhd's cc_lut (dual_port_rom.v) loads its contents with
#   $readmemb("dual_port_rom_init.txt", rom);
# a RELATIVE path. vsim runs with cwd = RUN_DIR, so without this file in
# the run dir the ROM stays all-X and the MuTRiG-LFSR -> linear-MTS-
# timestamp decode returns garbage. That makes the histogram delay key
# (gts_8n - hit_ts) scatter across the whole window (observed spread
# 6656 cyc) instead of the bounded buffering latency. This is a SIM
# harness gap, NOT an RTL bug: the file is generated correctly under
# generated/simulation/.../submodules/ but is not on vsim's search path.
# We only COPY from the generated tree (never modify it).
ROM_INIT_SRC="${SIM_ROOT}/submodules/dual_port_rom_init.txt"
if [[ -f "${ROM_INIT_SRC}" ]]; then
    cp -f "${ROM_INIT_SRC}" "${RUN_DIR}/dual_port_rom_init.txt"
    echo "[run] staged MTS decode ROM init -> ${RUN_DIR}/dual_port_rom_init.txt"
else
    echo "WARNING: ${ROM_INIT_SRC} not found; MTS delay decode will be garbage" >&2
fi

# Step 2: multi-pass compile + elab.
# tb_scifi_v4_wrapper.sv is the ONLY TB source; everything else comes
# from msim_setup.tcl (which qsys_generate_recursive.py has already
# augmented with the synth-backfilled files via --backfill).
LOG="${RUN_DIR}/sim.log"
python3 "${BUILD_DIR}/scripts/multipass_compile.py" \
    --msim-setup "${MSIM_SETUP}" \
    --run-dir "${RUN_DIR}" \
    --tb-sv "${SCRIPT_DIR}/tb_scifi_v4_wrapper.sv" \
    --tb-top tb_scifi_v4_wrapper \
    --questa-home "${QUESTA_HOME}" \
    --skip-file scifi_datapath_system_v4_run_control_mux.sv \
    2>&1 | tee "${LOG}"

# The wrapper-boundary scenario reports its own PASS/FAIL tally. A FAIL
# here is a *finding*, not a harness error: the monitors are designed to
# trip on a real RTL/contract defect (e.g. the histogram CONTROL.in_port
# EXT0/EXT1 select having no CSR write path). Surface the tally verbatim.
ELAB_LOG="${RUN_DIR}/elab.log"
if grep -q "SCIFI_V4_WRAPPER SCENARIO PASSED" "${ELAB_LOG}" 2>/dev/null; then
    echo "PASS: all wrapper-boundary checks held. ${ELAB_LOG}"
    exit 0
elif grep -q "SCIFI_V4_WRAPPER SCENARIO FAILED" "${ELAB_LOG}" 2>/dev/null; then
    echo "FINDING: wrapper-boundary monitor tripped (real defect) - see ${ELAB_LOG}" >&2
    grep -E "\[FAIL\]|SCENARIO FAILED" "${ELAB_LOG}" >&2 || true
    exit 3
fi
echo "ERROR: scenario did not run to completion. ${ELAB_LOG}" >&2
exit 1
