#!/usr/bin/env bash
set -euo pipefail

# Resume the ASIC0 real-MuTRiG rbCAM delay validation after the Quartus
# license daemon has recovered. This assumes the 20260504 fit completed and
# avoids rerunning the fitter unless the user does that explicitly elsewhere.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_DIR="$(cd "${SYSTEM_DIR}/../../.." && pwd)"
PROJECT_DIR="${SYSTEM_DIR}/syn/board_projects/fe_scifi_feb_v3"
REVISION="top_stp_pipe_phase6_injector_boundary"
OUTPUT_DIR="${PROJECT_DIR}/output_files_pipe_phase6_injector_boundary_stp"
FIT_SUMMARY="${OUTPUT_DIR}/${REVISION}.fit.summary"
SOF="${OUTPUT_DIR}/${REVISION}.sof"
JDI="${OUTPUT_DIR}/${REVISION}.jdi"
STA_SUMMARY="${OUTPUT_DIR}/${REVISION}.sta.summary"
LICENSE_SERVER="${LICENSE_SERVER:-8182@lic-altera.ethz.ch}"
QUARTUS_ROOT="${QUARTUS_ROOT:-/data1/intelFPGA/18.1/quartus}"
SYSTEM_CONSOLE="${QUARTUS_ROOT}/sopc_builder/bin/system-console"
QUARTUS_BIN="${QUARTUS_ROOT}/bin"
LMUTIL="${QUARTUS_ROOT}/linux64/lmutil"
BENCH_QUEUE="${BENCH_QUEUE:-/home/yifeng/packages/mu3e_ip_dev/.bench_queue/bench_ticket.py}"
BENCH_AGENT="${BENCH_AGENT:-codex_phase6_asic0_rbcam_goal}"
MUTRIG_CONFIG="${MUTRIG_CONFIG:-${REPO_DIR}/board_test_system/trash_bin/good_ribbon_0/config_smb3_tdc.txt}"
REPORT_DIR="${SYSTEM_DIR}/reports"
ASSET_DIR="${REPORT_DIR}/assets"

DATE_TAG="$(date +%Y%m%d_resume)"
RUN_BASE=79000
PROGRAM=0
SKIP_ASM=0
SKIP_STA=0
NO_BENCH=0
CABLE='USB-BlasterII [7-2]'

usage() {
  cat <<'EOF'
Usage: resume_phase6_asic0_rbcam_goal.sh [options]

Options:
  --date TAG        Report/plot date tag (default: YYYYMMDD_resume)
  --run-base N      Base run number for the sweeps (default: 79000)
  --program         Program the fresh SOF before MuTRiG reload/sweeps
  --cable NAME      quartus_pgm cable name (default: USB-BlasterII [7-2])
  --skip-asm        Skip quartus_asm; still require fresh SOF/JDI
  --skip-sta        Skip quartus_sta; still require fresh STA summary
  --no-bench        Do not claim/acquire/release the bench ticket
  -h, --help        Show this help

This script fails fast if the Quartus alterad daemon is unavailable or if the
SOF/JDI/STA artifacts are stale relative to the completed fit.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)
      DATE_TAG="$2"; shift 2 ;;
    --run-base)
      RUN_BASE="$2"; shift 2 ;;
    --program)
      PROGRAM=1; shift ;;
    --cable)
      CABLE="$2"; shift 2 ;;
    --skip-asm)
      SKIP_ASM=1; shift ;;
    --skip-sta)
      SKIP_STA=1; shift ;;
    --no-bench)
      NO_BENCH=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2 ;;
  esac
done

log() {
  printf '[%(%Y-%m-%dT%H:%M:%S%z)T] %s\n' -1 "$*"
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing required file: $1"
}

require_fresh() {
  local artifact="$1"
  local reference="$2"
  require_file "${artifact}"
  require_file "${reference}"
  [[ "${artifact}" -nt "${reference}" ]] || {
    stat -c '%y %n' "${reference}" "${artifact}" >&2 || true
    die "${artifact} is not newer than ${reference}"
  }
}

require_license() {
  require_file "${LMUTIL}"
  local lmstat
  lmstat="$("${LMUTIL}" lmstat -a -c "${LICENSE_SERVER}" 2>&1 || true)"
  printf '%s\n' "${lmstat}"
  grep -q 'alterad: UP' <<<"${lmstat}" || die "Quartus alterad daemon is not UP on ${LICENSE_SERVER}"
}

bench_claim() {
  [[ "${NO_BENCH}" == 0 ]] || return 0
  [[ -f "${BENCH_QUEUE}" ]] || die "bench queue tool not found: ${BENCH_QUEUE}"
  python3 "${BENCH_QUEUE}" claim --agent "${BENCH_AGENT}" --minutes 60 --reason phase6_asic0_rbcam_resume || true
  python3 "${BENCH_QUEUE}" acquire --agent "${BENCH_AGENT}"
}

bench_release() {
  [[ "${NO_BENCH}" == 0 ]] || return 0
  [[ -f "${BENCH_QUEUE}" ]] || return 0
  python3 "${BENCH_QUEUE}" release --agent "${BENCH_AGENT}" || true
}

run_quartus_asm() {
  [[ "${SKIP_ASM}" == 0 ]] || return 0
  log "Running quartus_asm for ${REVISION}"
  (
    cd "${PROJECT_DIR}"
    export PATH="${QUARTUS_BIN}:${QUARTUS_ROOT}/sopc_builder/bin:${PATH}"
    export LM_LICENSE_FILE="${LICENSE_SERVER}"
    export ALTERAD_LICENSE_FILE="${LICENSE_SERVER}"
    quartus_asm top -c "${REVISION}" 2>&1 \
      | tee "quartus_asm_${REVISION}_${DATE_TAG}.console.log"
  )
}

run_quartus_sta() {
  [[ "${SKIP_STA}" == 0 ]] || return 0
  log "Running quartus_sta for ${REVISION}"
  (
    cd "${PROJECT_DIR}"
    export PATH="${QUARTUS_BIN}:${QUARTUS_ROOT}/sopc_builder/bin:${PATH}"
    export LM_LICENSE_FILE="${LICENSE_SERVER}"
    export ALTERAD_LICENSE_FILE="${LICENSE_SERVER}"
    quartus_sta top -c "${REVISION}" 2>&1 \
      | tee "quartus_sta_${REVISION}_${DATE_TAG}.console.log"
  )
}

program_feb() {
  [[ "${PROGRAM}" == 1 ]] || return 0
  log "Programming FEB with ${SOF}"
  (
    cd "${REPO_DIR}"
    export PATH="${QUARTUS_BIN}:${PATH}"
    quartus_pgm -c "${CABLE}" -m JTAG -o "p;${SOF}"
  )
}

load_asic0_cml_toggle() {
  log "Reloading ASIC0 with CML on"
  python3 "${SCRIPT_DIR}/configure_mutrig_jtag.py" \
    --config "${MUTRIG_CONFIG}" \
    --xml-index 0 --asic 0 \
    --tdc-override vncnt=48 \
    --tdc-override vnvcodelay=20 \
    --tdc-override vnhitlogic=40 \
    --tdc-override recv_all=1 \
    --tdc-override cml=1 \
    --tdc-override cml_sc=1 \
    --channel-enable-mask 0xffffffff \
    --tdctest-channel-mask 0xffffffff \
    --json-out "${REPORT_DIR}/phase6_resume_asic0_cml1_${DATE_TAG}.json" \
    --readback

  log "Reloading ASIC0 with final tuned CML off"
  python3 "${SCRIPT_DIR}/configure_mutrig_jtag.py" \
    --config "${MUTRIG_CONFIG}" \
    --xml-index 0 --asic 0 \
    --tdc-override vncnt=48 \
    --tdc-override vnvcodelay=20 \
    --tdc-override vnhitlogic=40 \
    --tdc-override recv_all=1 \
    --tdc-override cml=0 \
    --tdc-override cml_sc=0 \
    --channel-enable-mask 0xffffffff \
    --tdctest-channel-mask 0xffffffff \
    --json-out "${REPORT_DIR}/phase6_resume_asic0_cml0_${DATE_TAG}.json" \
    --readback
}

collect_and_plot() {
  local pre_stem="phase6_goal_final_asic0_pre_rbcam"
  local post_stem="phase6_goal_final_asic0_post_rbcam"

  log "Collecting pre-rbCAM ASIC0 real-MuTRiG sweeps"
  python3 "${SCRIPT_DIR}/run_phase6_emulator_post_rbcam_groups.py" \
    --control-transport jtag \
    --system-console "${SYSTEM_CONSOLE}" \
    --jdi "${JDI}" \
    --source-mode real \
    --source-label "Real MuTRiG ASIC0" \
    --stem-prefix "${pre_stem}" \
    --date "${DATE_TAG}" \
    --run-number-base "${RUN_BASE}" \
    --active-lane 0 \
    --lvds-lane-go-mask 0x00000001 \
    --hist-snoop-source pre \
    --hist-profile-override delay-hit-t-pre \
    --skip-source-mux \
    --skip-emulator-config \
    --jtag-timeout-s 240

  log "Collecting post-rbCAM ASIC0 real-MuTRiG sweeps"
  python3 "${SCRIPT_DIR}/run_phase6_emulator_post_rbcam_groups.py" \
    --control-transport jtag \
    --system-console "${SYSTEM_CONSOLE}" \
    --jdi "${JDI}" \
    --source-mode real \
    --source-label "Real MuTRiG ASIC0" \
    --stem-prefix "${post_stem}" \
    --date "${DATE_TAG}" \
    --run-number-base "$((RUN_BASE + 1000))" \
    --active-lane 0 \
    --lvds-lane-go-mask 0x00000001 \
    --hist-snoop-source post \
    --hist-profile-override delay-debug3 \
    --skip-source-mux \
    --skip-emulator-config \
    --jtag-timeout-s 240

  log "Rendering reference-style pre-rbCAM plots"
  python3 "${SCRIPT_DIR}/plot_phase6_emulator_asic0_post_rbcam_delay_groups.py" \
    --date "${DATE_TAG}" \
    --stem-prefix "${pre_stem}" \
    --title-label "Real MuTRiG ASIC0" \
    --hist-snoop-source pre \
    --out-dir "${ASSET_DIR}/${pre_stem}_${DATE_TAG}" \
    --reference-style

  log "Rendering reference-style post-rbCAM plots"
  python3 "${SCRIPT_DIR}/plot_phase6_emulator_asic0_post_rbcam_delay_groups.py" \
    --date "${DATE_TAG}" \
    --stem-prefix "${post_stem}" \
    --title-label "Real MuTRiG ASIC0" \
    --hist-snoop-source post \
    --out-dir "${ASSET_DIR}/${post_stem}_${DATE_TAG}" \
    --reference-style
}

main() {
  log "Checking Quartus license daemon"
  require_license
  require_file "${FIT_SUMMARY}"

  bench_claim
  trap bench_release EXIT

  run_quartus_asm
  require_fresh "${SOF}" "${FIT_SUMMARY}"
  require_fresh "${JDI}" "${FIT_SUMMARY}"

  run_quartus_sta
  require_fresh "${STA_SUMMARY}" "${FIT_SUMMARY}"

  program_feb
  load_asic0_cml_toggle
  collect_and_plot

  log "Done. Inspect ${REPORT_DIR} and ${ASSET_DIR} for ${DATE_TAG}."
}

main "$@"
