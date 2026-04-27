#!/usr/bin/env bash
# ============================================================================
# T002_RC-REG_20260416 -- Run-Control Hard-Reset Per-Register Characterisation
#
# Goal
# ----
# For each target register, execute the reference sequence:
#     (1) read   -> expect default   (R_DEF)
#     (2) write  -> arbitrary RW value
#     (3) read   -> expect written   (R_WR)
#     (4) CMD_RESET       via JTAG inject into runctl_mgmt_host_0.CSR_LOCAL_CMD
#     (5) CMD_STOP_RESET  via JTAG inject
#     (6) read   -> expect default   (R_REC)
# For RO/counter witnesses, (2) and (3) are replaced by "observe any change",
# and (6) is expect-zero-or-preserved depending on reset domain.
#
# Reset injection path
# --------------------
# CMD_RESET (0x30) / CMD_STOP_RESET (0x31) are injected via System Console into
# runctl_mgmt_host_0.CSR_LOCAL_CMD (CSR word 0x13 = byte 0xCC on the internal
# upload_system_jtag_master at base 0x0080). This is the only reachable path on
# the current firmware because the sc_hub -> upload_subsystem.csr link was
# intentionally omitted from feb_system_v2.qsys to save fabric area.
#
# Driver outputs (reports/)
# -------------------------
#   run_<ts>.log               raw log (all sc_tool + system-console output)
#   summary.rpt                pattern application summary
#   register_coverage.rpt      per-IP / per-register reset-domain verdict
#
# Usage
# -----
#   bash run_rc_reg.sh [link]           (default link = 2)
#
# Exit code = number of FAIL patterns.
# ============================================================================
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${HERE}/common.sh"
bt_setup_env

LINK="${1:-${BOARD_TEST_LINK}}"
SC="${BOARD_TEST_SC_TOOL}"
SYSCON="${BOARD_TEST_SYSCON}"
PROJECT_DIR="${BOARD_TEST_PROJECT_DIR}"
JDI="${BOARD_TEST_JDI}"
INJECT_TCL="${HERE}/inject_runcmd.tcl"

TS=$(date +%Y%m%d_%H%M%S)
LOGFILE="${BOARD_TEST_REPORT_DIR}/run_${TS}.log"
SUMMARY="${BOARD_TEST_REPORT_DIR}/summary.rpt"
COVERAGE="${BOARD_TEST_REPORT_DIR}/register_coverage.rpt"

PASS=0; FAIL=0; SKIP=0; TOTAL=0
declare -a PATTERN_RESULTS

log()  { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOGFILE"; }
pass() { ((PASS+=1)); ((TOTAL+=1)); PATTERN_RESULTS+=("PASS  $1"); log "  PASS: $1"; }
fail() {
    local name="$1"
    local detail="${2:-no detail}"
    ((FAIL+=1))
    ((TOTAL+=1))
    PATTERN_RESULTS+=("FAIL  ${name}")
    log "  FAIL: ${name} -- ${detail}"
}
skip() {
    local name="$1"
    local detail="${2:-no detail}"
    ((SKIP+=1))
    ((TOTAL+=1))
    PATTERN_RESULTS+=("SKIP  ${name}")
    log "  SKIP: ${name} -- ${detail}"
}

# --- sc_tool wrappers -------------------------------------------------------

# sc_read <word_addr> <len>   -> emit payload words, one hex per line
sc_read() {
    local out
    out=$($SC "$LINK" read "$1" "$2" --quiet 2>&1) || {
        echo "$out" >> "$LOGFILE"
        return 1
    }
    echo "$out" | tee -a "$LOGFILE" | grep -oP 'payload\[\d+\]\s*=\s*\K0x[0-9A-Fa-f]+' || true
}

sc_read1() {
    sc_read "$1" 1 | head -n1
}

sc_write() {
    local addr="$1"; shift
    local out
    out=$($SC "$LINK" write "$addr" "$@" --quiet 2>&1) || {
        echo "$out" >> "$LOGFILE"
        return 1
    }
    echo "$out" >> "$LOGFILE"
    if echo "$out" | grep -qE 'rsp[^A-Za-z]+(DECERR|SLVERR)'; then
        return 1
    fi
    return 0
}

# --- JTAG inject wrapper ----------------------------------------------------

# jtag_inject <cmd_hex>  -- runs system-console inject_runcmd.tcl
jtag_inject() {
    local cmd_hex="$1"
    log "  inject via JTAG: cmd=$cmd_hex"
    local out
    out=$("$SYSCON" -cli -disable_readline -disable_timeout \
            --project_dir="$PROJECT_DIR" \
            --jdi="$JDI" \
            --script="$INJECT_TCL" \
            "$cmd_hex" 80 2>&1) || true
    echo "$out" >> "$LOGFILE"
    if echo "$out" | grep -q "INJECT_RESULT status=OK"; then
        echo "$out" | grep -E "^(SELECTED|PRE |POST|INJECT_RESULT)"
        return 0
    else
        echo "$out" | tail -n 30
        return 1
    fi
}

# --- equality helpers -------------------------------------------------------

hex_eq() {
    # normalise both sides to lowercase-hex, no prefix, leading zeros stripped
    local a="${1#0x}"; a="${a#0X}"; a=$(printf "%x" "0x$a" 2>/dev/null || echo "$a")
    local b="${2#0x}"; b="${b#0X}"; b=$(printf "%x" "0x$b" 2>/dev/null || echo "$b")
    [ "$a" = "$b" ]
}

# ============================================================================
# P001 -- JTAG CSR audit: prove we can read runctl_mgmt_host_0 via JTAG
# ============================================================================
log "============================================================================"
log "P001  jtag_csr_audit  -- prove inject path is live"
log "============================================================================"

# "Dry" injection: cmd=0x31 (CMD_STOP_RESET) is safe to issue when the system
# is not currently in reset; the host just re-asserts "not in reset".
if jtag_inject 0x31; then
    pass "P001_001 jtag_inject_stop_reset_roundtrip"
else
    fail "P001_001 jtag_inject_stop_reset_roundtrip" "inject script failed"
fi

# ============================================================================
# P002 -- max10_prog_avmm_0.XFER_BYTES full cycle (datapath neighbour)
# ============================================================================
XFER_ADDR=0x04808
XFER_DEFAULT=0x00000100
XFER_WRITE=0x000000AB

log "============================================================================"
log "P002  xfer_bytes_reset_cycle  @ $XFER_ADDR  default=$XFER_DEFAULT"
log "============================================================================"

v=$(sc_read1 $XFER_ADDR)
log "  P002 step1 read=$v expect=$XFER_DEFAULT"
if hex_eq "$v" "$XFER_DEFAULT"; then
    pass "P002_001 read=default"
else
    fail "P002_001 read=default" "got $v"
fi

if sc_write $XFER_ADDR $XFER_WRITE; then
    pass "P002_002 write"
else
    fail "P002_002 write" "sc_write failed"
fi

v=$(sc_read1 $XFER_ADDR)
log "  P002 step3 read=$v expect=$XFER_WRITE"
if hex_eq "$v" "$XFER_WRITE"; then
    pass "P002_003 read=written"
else
    fail "P002_003 read=written" "got $v"
fi

if jtag_inject 0x30; then
    pass "P002_004 CMD_RESET"
else
    fail "P002_004 CMD_RESET" "inject failed"
fi

if jtag_inject 0x31; then
    pass "P002_005 CMD_STOP_RESET"
else
    fail "P002_005 CMD_STOP_RESET" "inject failed"
fi

v=$(sc_read1 $XFER_ADDR)
log "  P002 step6 read=$v expect=$XFER_DEFAULT (recovered default after hard reset)"
if hex_eq "$v" "$XFER_DEFAULT"; then
    pass "P002_006 recovered=default (register IS in reset domain)"
else
    fail "P002_006 recovered=default" "got $v -- register NOT reset by CMD_RESET"
fi

# ============================================================================
# P003 -- sc_hub counter witness (control path, expected NOT to reset)
# ============================================================================
HUB_UID=0x0FE80
HUB_ERRFLG=0x0FE81
HUB_ERRCNT=0x0FE85
HUB_PKTRD=0x0FE8F
HUB_PKTWR=0x0FE90
HUB_WORDRD=0x0FE91
HUB_WORDWR=0x0FE92

log "============================================================================"
log "P003  sc_hub_counter_witness  -- counters before/after CMD_RESET"
log "============================================================================"

uid=$(sc_read1 $HUB_UID)
log "  P003 sc_hub UID=$uid"
if hex_eq "$uid" "0x53434842"; then
    pass "P003_001 sc_hub UID=SCHB"
else
    fail "P003_001 sc_hub UID=SCHB" "got $uid"
fi

pre_pktrd=$(sc_read1 $HUB_PKTRD)
pre_pktwr=$(sc_read1 $HUB_PKTWR)
pre_wordrd=$(sc_read1 $HUB_WORDRD)
pre_wordwr=$(sc_read1 $HUB_WORDWR)
log "  P003 pre  EXT_PKT_RD=$pre_pktrd EXT_PKT_WR=$pre_pktwr EXT_WORD_RD=$pre_wordrd EXT_WORD_WR=$pre_wordwr"

jtag_inject 0x30 >/dev/null
jtag_inject 0x31 >/dev/null

post_pktrd=$(sc_read1 $HUB_PKTRD)
post_pktwr=$(sc_read1 $HUB_PKTWR)
post_wordrd=$(sc_read1 $HUB_WORDRD)
post_wordwr=$(sc_read1 $HUB_WORDWR)
log "  P003 post EXT_PKT_RD=$post_pktrd EXT_PKT_WR=$post_pktwr EXT_WORD_RD=$post_wordrd EXT_WORD_WR=$post_wordwr"

# Counters must strictly increase (the reset cycle itself drove traffic).
# If they snap to zero it means sc_hub IS in the reset domain (unexpected).
pre_val=$(printf '%d' "$pre_pktrd" 2>/dev/null || echo 0)
post_val=$(printf '%d' "$post_pktrd" 2>/dev/null || echo 0)
if [ "$post_val" -gt "$pre_val" ]; then
    pass "P003_002 EXT_PKT_RD monotonic (sc_hub NOT in reset domain)"
elif [ "$post_val" = "0" ]; then
    fail "P003_002 EXT_PKT_RD monotonic" "snapped to 0 -- sc_hub reset by CMD_RESET"
else
    fail "P003_002 EXT_PKT_RD monotonic" "pre=$pre_pktrd post=$post_pktrd not increasing"
fi

# ============================================================================
# P004 -- scratch_pad_ram persistence (pure RAM, reset must NOT clear content)
# ============================================================================
log "============================================================================"
log "P004  scratch_pad_ram_persistence  -- RAM must persist through reset cycle"
log "============================================================================"

SPR_ADDR=0x00010
SPR_VAL=0xDEADBEEF

sc_write $SPR_ADDR $SPR_VAL >/dev/null 2>&1
v=$(sc_read1 $SPR_ADDR)
if hex_eq "$v" "$SPR_VAL"; then
    pass "P004_001 scratch_pad_ram write+read"
else
    fail "P004_001 scratch_pad_ram write+read" "got $v"
fi

jtag_inject 0x30 >/dev/null
jtag_inject 0x31 >/dev/null

v=$(sc_read1 $SPR_ADDR)
log "  P004 post-reset read=$v expect=$SPR_VAL (RAM must persist)"
if hex_eq "$v" "$SPR_VAL"; then
    pass "P004_002 RAM persists through CMD_RESET (control path not reset)"
else
    fail "P004_002 RAM persists through CMD_RESET" "got $v -- scratch_pad_ram IS in reset domain"
fi

# ============================================================================
# P005 -- link lock witness: LINK_LOCKED must stay asserted through cycle
# ============================================================================
# (This is a sc_hub-external check via sc_tool's link-diag path. Skipped for
#  T002 -- covered by SWB-side LINK_LOCKED_HIGH_REGISTER_R reads if needed.)

# ============================================================================
# Reports
# ============================================================================
{
    echo "================================================================================"
    echo " T002 RC-REG PATTERN APPLICATION SUMMARY"
    echo "================================================================================"
    echo " Test ID          : T002_RC-REG_20260416"
    echo " DUT              : FEB SciFi   runctl_mgmt_host_0 + datapath/control-path IPs"
    echo " Transport        : SC ring on SWB link $LINK (reads/writes);"
    echo "                    System Console JTAG (CMD_RESET / CMD_STOP_RESET inject)"
    echo " Date             : $(date -Iseconds)"
    echo " Raw log          : reports/run_${TS}.log"
    echo "================================================================================"
    echo
    echo "PATTERN RESULTS"
    echo "---------------"
    for line in "${PATTERN_RESULTS[@]}"; do
        echo "  $line"
    done
    echo
    echo "---------------"
    echo "  TOTAL : $TOTAL"
    echo "  PASS  : $PASS"
    echo "  FAIL  : $FAIL"
    echo "  SKIP  : $SKIP"
    echo
    if [ "$FAIL" -eq 0 ]; then
        echo "OVERALL RESULT : ALL TESTS PASSED"
    else
        echo "OVERALL RESULT : $FAIL PATTERN(S) FAILED"
    fi
    echo "================================================================================"
} > "$SUMMARY"

{
    echo "================================================================================"
    echo " T002 REGISTER RESET-DOMAIN COVERAGE"
    echo "================================================================================"
    echo
    echo "Per-register verdict after full read/write/reset/stop_reset/read cycle."
    echo
    printf "  %-40s %-14s %-18s %s\n" "Register" "Addr (word)" "Expected domain" "Observed"
    echo "  ----------------------------------------------------------------------------------------------"
    # Programmatically assemble observed verdicts from the log.
    obs_xfer="(see log)"
    for r in "${PATTERN_RESULTS[@]}"; do
        case "$r" in
          "PASS  P002_006"*) obs_xfer="RESET  (default recovered)";;
          "FAIL  P002_006"*) obs_xfer="NOT_RESET (value kept)";;
        esac
    done
    obs_hub="(see log)"
    for r in "${PATTERN_RESULTS[@]}"; do
        case "$r" in
          "PASS  P003_002"*) obs_hub="NOT_RESET (counters monotonic)";;
          "FAIL  P003_002"*) obs_hub="RESET  (counters snapped)";;
        esac
    done
    obs_spr="(see log)"
    for r in "${PATTERN_RESULTS[@]}"; do
        case "$r" in
          "PASS  P004_002"*) obs_spr="NOT_RESET (content persisted)";;
          "FAIL  P004_002"*) obs_spr="RESET  (content lost)";;
        esac
    done
    printf "  %-40s %-14s %-18s %s\n" "max10_prog_avmm_0.XFER_BYTES"      "0x04808" "RESET  (datapath)"   "$obs_xfer"
    printf "  %-40s %-14s %-18s %s\n" "sc_hub.EXT_PKT_RD"                  "0x0FE8F" "NOT_RESET (ctrl)"    "$obs_hub"
    printf "  %-40s %-14s %-18s %s\n" "scratch_pad_ram[0x10]"              "0x00010" "NOT_RESET (ctrl)"    "$obs_spr"
    echo
    echo "Notes"
    echo "-----"
    echo "  - CMD_RESET (0x30) and CMD_STOP_RESET (0x31) are injected via System"
    echo "    Console JTAG into runctl_mgmt_host_0.CSR_LOCAL_CMD (word 0x13 /"
    echo "    byte 0xCC on upload_system_jtag_master @ base 0x80), because"
    echo "    sc_hub -> upload_subsystem.csr is intentionally unconnected in"
    echo "    feb_system_v2.qsys to save fabric area (board at ~90% util)."
    echo "  - RESET-domain expectation was derived from the upload_system output"
    echo "    wiring: dp_hard_reset -> data_path_subsystem.avmm_rst,"
    echo "    ext_hard_reset merge -> control_path_subsystem.clk156_in_rst,"
    echo "    data_path_subsystem.avmm_rst, and xcvr_reset."
    echo "    Per-register observed column is the empirical answer on THIS"
    echo "    build -- diverging from 'Expected domain' is a real finding."
    echo "================================================================================"
} > "$COVERAGE"

log "======== DONE ========"
log "TOTAL=$TOTAL PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
log "reports: $SUMMARY, $COVERAGE, $LOGFILE"
exit "$FAIL"
