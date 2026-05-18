#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
sim_case_dir="${project_dir}/tb/sim/cases/sc_mmio_full_path"
run_questa="${sim_case_dir}/run_questa.sh"
tb_src="${sim_case_dir}/tb_sc_mmio_full_path.vhd"

out_dir_default="${project_dir}/output_files/gtk_ab_burst_compare"
run_us_default="2000"

out_dir="${out_dir_default}"
run_us="${run_us_default}"
view="compare"
no_open="0"
regen="0"

usage() {
    cat <<EOF
Usage:
  open_gtk.sh [--view compare|a|b|both] [--out-dir PATH] [--run-us N] [--regen] [--no-open]

Behavior:
  - compare = one focused waveform with A(pass) and B(fail) groups
  - A/pass = current fixed full-path replay with the registered RX bridge
  - B/fail = reconstructed pre-fix replay with the same-edge RX bridge
  - DIFF signals at the top highlight the main divergence around the first >8-word region

Options:
  --view compare|a|b|both
                    Open the single grouped compare view, only A, only B, or both separate windows
                    (default: compare)
  --out-dir PATH    Where generated compare artifacts should be written
  --run-us N        VCD capture length in microseconds (default: ${run_us_default})
  --regen           Re-run both simulations even if artifacts already exist
  --no-open         Generate artifacts and print the summary, but do not launch GTKWave
  -h, --help        Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --view)
            view="$2"
            shift 2
            ;;
        --out-dir)
            out_dir="$2"
            shift 2
            ;;
        --run-us)
            run_us="$2"
            shift 2
            ;;
        --regen)
            regen="1"
            shift
            ;;
        --no-open)
            no_open="1"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument '$1'" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "${view}" in
    a|A|old|OLD)
        view="a"
        ;;
    b|B|new|NEW)
        view="b"
        ;;
    compare|COMPARE|ab|AB)
        view="compare"
        ;;
    both|BOTH)
        view="both"
        ;;
    *)
        echo "ERROR: --view must be one of: compare, a, b, both" >&2
        exit 2
        ;;
esac

if [[ ! "${run_us}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --run-us must be a positive integer" >&2
    exit 2
fi
if [[ ! -x "${run_questa}" ]]; then
    echo "ERROR: missing sim runner: ${run_questa}" >&2
    exit 2
fi
if [[ ! -f "${tb_src}" ]]; then
    echo "ERROR: missing testbench source: ${tb_src}" >&2
    exit 2
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is not installed or not in PATH" >&2
    exit 2
fi
if [[ "${no_open}" != "1" ]] && ! command -v gtkwave >/dev/null 2>&1; then
    echo "ERROR: gtkwave is not installed or not in PATH" >&2
    exit 2
fi

mkdir -p "${out_dir}"

generated_dir="${out_dir}/generated"
a_tb="${generated_dir}/tb_sc_mmio_full_path_A_fail.vhd"
b_tb="${generated_dir}/tb_sc_mmio_full_path_B_pass.vhd"
a_do="${generated_dir}/capture_A.do"
b_do="${generated_dir}/capture_B.do"
a_vcd="${out_dir}/burst_compare_A_fail.vcd"
b_vcd="${out_dir}/burst_compare_B_pass.vcd"
a_gtkw="${out_dir}/burst_compare_A_fail.gtkw"
b_gtkw="${out_dir}/burst_compare_B_pass.gtkw"
compare_vcd="${out_dir}/burst_compare_AB_focus.vcd"
compare_gtkw="${out_dir}/burst_compare_AB_focus.gtkw"
a_work="${out_dir}/a_work"
b_work="${out_dir}/b_work"
a_log="${a_work}/vsim.log"
b_log="${b_work}/vsim.log"
summary_json="${out_dir}/summary.json"

need_regen="0"
for required_path in \
    "${a_tb}" "${b_tb}" "${a_do}" "${b_do}" \
    "${a_vcd}" "${b_vcd}" "${a_log}" "${b_log}" \
    "${a_gtkw}" "${b_gtkw}" "${summary_json}"; do
    if [[ ! -f "${required_path}" ]]; then
        need_regen="1"
        break
    fi
done
if [[ "${regen}" = "1" ]]; then
    need_regen="1"
fi

prepare_variants() {
    mkdir -p "${generated_dir}"
    python3 - "${tb_src}" "${a_tb}" "${b_tb}" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1]).read_text(encoding="utf-8")
a_out = Path(sys.argv[2])
b_out = Path(sys.argv[3])

loop_old = """        for idx in sweep_lengths_c'range loop
            p_run_write_sweep_case(sweep_lengths_c(idx));
        end loop;
"""

loop_new = """        for idx in sweep_lengths_c'range loop
            p_run_write_sweep_case(sweep_lengths_c(idx));
            report "MARKER: sweep_len=" & integer'image(sweep_lengths_c(idx)) &
                   " reply_count=" & integer'image(reply_count) severity note;
        end loop;
"""

rx_old = """    rx_link_map_proc : process(tb_clk)
    begin
        if rising_edge(tb_clk) then
            if tb_reset_n = '0' then
                sc_rx_links <= (others => work.mu3e.LINK32_IDLE);
            else
                sc_rx_links <= (others => work.mu3e.LINK32_IDLE);
                if (hub_ul_filt_valid = '1') then
                    sc_rx_links(2).data  <= hub_ul_filt_data(31 downto 0);
                    sc_rx_links(2).datak <= hub_ul_filt_data(35 downto 32);
                    sc_rx_links(2).idle  <= '0';
                    sc_rx_links(2).sop   <= hub_ul_filt_sop;
                    sc_rx_links(2).eop   <= hub_ul_filt_eop;
                    sc_rx_links(2).err   <= hub_ul_filt_error(0);
                end if;
            end if;
        end if;
    end process;
"""

rx_new = """    rx_link_map_proc : process(all)
    begin
        sc_rx_links <= (others => work.mu3e.LINK32_IDLE);
        if tb_reset_n = '1' and hub_ul_filt_valid = '1' then
            sc_rx_links(2).data  <= hub_ul_filt_data(31 downto 0);
            sc_rx_links(2).datak <= hub_ul_filt_data(35 downto 32);
            sc_rx_links(2).idle  <= '0';
            sc_rx_links(2).sop   <= hub_ul_filt_sop;
            sc_rx_links(2).eop   <= hub_ul_filt_eop;
            sc_rx_links(2).err   <= hub_ul_filt_error(0);
        end if;
    end process;
"""

b_text = src.replace(loop_old, loop_new, 1)
if b_text == src:
    raise SystemExit("failed to inject sweep markers into B variant")

a_text = b_text.replace(rx_old, rx_new, 1)
if a_text == b_text:
    raise SystemExit("failed to convert A variant to the combinational RX bridge")

a_out.write_text(a_text, encoding="utf-8")
b_out.write_text(b_text, encoding="utf-8")
PY
}

write_do() {
    local do_path="$1"
    local vcd_path="$2"
    cat > "${do_path}" <<EOF
vcd file ${vcd_path}
vcd add /tb_sc_mmio_full_path/tb_clk
vcd add /tb_sc_mmio_full_path/tb_reset_n
vcd add /tb_sc_mmio_full_path/sc_done
vcd add /tb_sc_mmio_full_path/sc_state
vcd add /tb_sc_mmio_full_path/avm_burstcount
vcd add /tb_sc_mmio_full_path/avm_write
vcd add /tb_sc_mmio_full_path/avm_wrvalid
vcd add /tb_sc_mmio_full_path/avm_addr
vcd add /tb_sc_mmio_full_path/avm_wdata
vcd add /tb_sc_mmio_full_path/hub_ul_valid
vcd add /tb_sc_mmio_full_path/hub_ul_sop
vcd add /tb_sc_mmio_full_path/hub_ul_eop
vcd add /tb_sc_mmio_full_path/hub_ul_filt_valid
vcd add /tb_sc_mmio_full_path/hub_ul_filt_sop
vcd add /tb_sc_mmio_full_path/hub_ul_filt_eop
vcd add /tb_sc_mmio_full_path/hub_ul_data
vcd add /tb_sc_mmio_full_path/hub_ul_filt_data
vcd add /tb_sc_mmio_full_path/reply_we
vcd add /tb_sc_mmio_full_path/reply_count
vcd add /tb_sc_mmio_full_path/reply_state
vcd add /tb_sc_mmio_full_path/reply_addr
vcd add /tb_sc_mmio_full_path/reply_finish
vcd add /tb_sc_mmio_full_path/reply_data
vcd add /tb_sc_mmio_full_path/tx_capture_cnt
vcd add /tb_sc_mmio_full_path/ul_capture_cnt
run ${run_us} us
quit -f
EOF
}

run_variant() {
    local label="$1"
    local tb_override="$2"
    local work_dir="$3"
    local do_file="$4"
    local rc="0"

    rm -rf -- "${work_dir}"
    TB_WORK_DIR="${work_dir}" \
    TB_FILE_OVERRIDE="${tb_override}" \
    TB_VSIM_DO_FILE="${do_file}" \
    TB_REQUIRE_PASS_MARKER="0" \
    "${run_questa}" || rc="$?"

    if [[ "${rc}" != "0" ]]; then
        echo "ERROR: ${label} run failed" >&2
        exit "${rc}"
    fi
}

build_summary_and_gtkw() {
    python3 - "${a_log}" "${b_log}" "${a_vcd}" "${b_vcd}" "${a_gtkw}" "${b_gtkw}" "${compare_vcd}" "${compare_gtkw}" "${summary_json}" <<'PY'
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path


def parse_log(path: Path) -> dict:
    data = {
        "write_cases": {},
        "sweep_markers": {},
        "aggregate": None,
        "pass": False,
        "fail": False,
    }
    pending_write = None
    pending_sweep = None
    pending_aggregate = None

    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = re.search(r"INFO: write_len(\d+) tx_words=(\d+) reply_words=(\d+)", line)
        if match:
            pending_write = {
                "len": int(match.group(1)),
                "tx_words": int(match.group(2)),
                "reply_words": int(match.group(3)),
            }
            continue

        match = re.search(r"MARKER: sweep_len=\s*(\d+)\s+reply_count=\s*(\d+)", line)
        if match:
            pending_sweep = {
                "len": int(match.group(1)),
                "reply_count": int(match.group(2)),
            }
            continue

        match = re.search(
            r"aggregate write tx_accept_cnt=(\d+) reply_count=(\d+) ul_capture_cnt=(\d+)",
            line,
        )
        if match:
            pending_aggregate = {
                "tx_accept_cnt": int(match.group(1)),
                "reply_count": int(match.group(2)),
                "ul_capture_cnt": int(match.group(3)),
            }
            continue

        match = re.search(r"Time:\s*(\d+)\s*ns", line)
        if match:
            time_ns = int(match.group(1))
            if pending_write is not None:
                pending_write["time_ns"] = time_ns
                data["write_cases"][str(pending_write["len"])] = pending_write
                pending_write = None
            elif pending_sweep is not None:
                pending_sweep["time_ns"] = time_ns
                data["sweep_markers"][str(pending_sweep["len"])] = pending_sweep
                pending_sweep = None
            elif pending_aggregate is not None:
                pending_aggregate["time_ns"] = time_ns
                data["aggregate"] = pending_aggregate
                pending_aggregate = None

        if "PASS: tb_sc_mmio_full_path" in line:
            data["pass"] = True
        if "SWB SC secondary still did not capture any write acknowledgement" in line:
            data["fail"] = True

    return data


def scalar(path: str, color: int, attr: str = "@28", label: str | None = None) -> list[str]:
    out = [attr, path, f"[color] {color}"]
    if label is not None:
        out.append(f"[label] {label}")
    return out


def vector(path: str, msb: int, lsb: int, color: int, attr: str = "@22", label: str | None = None) -> list[str]:
    bits = " ".join(f"{path}[{bit}]" for bit in range(msb, lsb - 1, -1))
    out = [attr, f"#{{{path}[{msb}:{lsb}]}} {bits}", f"[color] {color}"]
    if label is not None:
        out.append(f"[label] {label}")
    return out


def group_start(title: str) -> list[str]:
    return ["@200", f"-{title}"]


def group_end() -> list[str]:
    return ["@1401200", "-group_end"]


def write_raw_gtkw(vcd_path: Path, gtkw_path: Path, parsed: dict, title: str) -> None:
    marker_specs: list[tuple[str, int]] = []
    for key, name in [("1", "T0_LEN1_DONE"), ("2", "T1_LEN2_DONE"), ("4", "T2_LEN4_DONE")]:
        entry = parsed["write_cases"].get(key)
        if entry is not None:
            marker_specs.append((name, entry["time_ns"]))
    for key, name in [("8", "T3_SWEEP8_DONE"), ("16", "T4_SWEEP16_DONE")]:
        entry = parsed["sweep_markers"].get(key)
        if entry is not None:
            marker_specs.append((name, entry["time_ns"]))
    if parsed["aggregate"] is not None:
        marker_specs.append(("T5_AGGREGATE", parsed["aggregate"]["time_ns"]))

    cursor_ns = parsed["sweep_markers"].get("16", {}).get(
        "time_ns",
        parsed["sweep_markers"].get("8", {}).get(
            "time_ns",
            parsed["write_cases"].get("4", {}).get("time_ns", 0),
        ),
    )

    marker_positions_ps = [str(time_ns * 1000) for _, time_ns in marker_specs]
    marker_names = [name for name, _ in marker_specs]
    star_fields = [str(cursor_ns * 1000), *marker_positions_ps, "-1", "-1", "-1", "-1"]

    lines: list[str] = [
        "[*]",
        "[*] GTKWave Analyzer v3.3.79",
        "[*]",
        f'[dumpfile] "{vcd_path}"',
        f'[savefile] "{gtkw_path}"',
        "[timestart] 0",
        "[size] 1600 960",
        "[pos] -1 -1",
        "*" + " ".join(star_fields),
    ]

    for name in marker_names:
        lines.append(f"[markername_long] {name}")

    lines.extend(
        [
            "[sst_width] 260",
            "[signals_width] 420",
            "[sst_expanded] 1",
            "@200",
            "- " + title,
            scalar("tb_sc_mmio_full_path.tb_clk", 0)[0],
            scalar("tb_sc_mmio_full_path.tb_clk", 0)[1],
            scalar("tb_sc_mmio_full_path.tb_clk", 0)[2],
        ]
    )

    signal_lines: list[str] = []
    signal_lines.extend(scalar("tb_sc_mmio_full_path.tb_reset_n", 1))
    signal_lines.extend(scalar("tb_sc_mmio_full_path.sc_done", 3))
    signal_lines.extend(scalar("tb_sc_mmio_full_path.avm_write", 3))
    signal_lines.extend(scalar("tb_sc_mmio_full_path.avm_wrvalid", 3))
    signal_lines.extend(scalar("tb_sc_mmio_full_path.hub_ul_valid", 3))
    signal_lines.extend(scalar("tb_sc_mmio_full_path.hub_ul_sop", 3))
    signal_lines.extend(scalar("tb_sc_mmio_full_path.hub_ul_eop", 3))
    signal_lines.extend(scalar("tb_sc_mmio_full_path.hub_ul_filt_valid", 3))
    signal_lines.extend(scalar("tb_sc_mmio_full_path.hub_ul_filt_sop", 3))
    signal_lines.extend(scalar("tb_sc_mmio_full_path.hub_ul_filt_eop", 3))
    signal_lines.extend(scalar("tb_sc_mmio_full_path.reply_we", 3))
    signal_lines.extend(vector("tb_sc_mmio_full_path.avm_burstcount", 8, 0, 4, "@24"))
    signal_lines.extend(vector("tb_sc_mmio_full_path.avm_burstcount", 8, 0, 4, "@8024", "avm_burstcount (analog)"))
    signal_lines.extend(scalar("tb_sc_mmio_full_path.reply_count", 4, "@24"))
    signal_lines.extend(scalar("tb_sc_mmio_full_path.reply_count", 4, "@8024", "reply_count (analog)"))
    signal_lines.extend(scalar("tb_sc_mmio_full_path.tx_capture_cnt", 4, "@24"))
    signal_lines.extend(scalar("tb_sc_mmio_full_path.ul_capture_cnt", 4, "@24"))
    signal_lines.extend(vector("tb_sc_mmio_full_path.reply_state", 3, 0, 5))
    signal_lines.extend(vector("tb_sc_mmio_full_path.sc_state", 27, 0, 5))
    signal_lines.extend(vector("tb_sc_mmio_full_path.avm_addr", 15, 0, 5))
    signal_lines.extend(vector("tb_sc_mmio_full_path.avm_wdata", 31, 0, 5))
    signal_lines.extend(vector("tb_sc_mmio_full_path.reply_addr", 15, 0, 5))
    signal_lines.extend(vector("tb_sc_mmio_full_path.reply_finish", 15, 0, 5))
    signal_lines.extend(vector("tb_sc_mmio_full_path.reply_data", 31, 0, 5))
    signal_lines.extend(vector("tb_sc_mmio_full_path.hub_ul_data", 35, 0, 5))
    signal_lines.extend(vector("tb_sc_mmio_full_path.hub_ul_filt_data", 35, 0, 5))
    lines.extend(signal_lines)
    gtkw_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


SIGNAL_SPECS = {
    "tb_clk": {"kind": "scalar", "width": 1, "default": "x"},
    "tb_reset_n": {"kind": "scalar", "width": 1, "default": "x"},
    "avm_burstcount": {"kind": "bits", "width": 9, "default": "x" * 9},
    "hub_ul_valid": {"kind": "scalar", "width": 1, "default": "x"},
    "hub_ul_filt_valid": {"kind": "scalar", "width": 1, "default": "x"},
    "reply_we": {"kind": "scalar", "width": 1, "default": "x"},
    "reply_count": {"kind": "vector", "width": 32, "default": "x" * 32},
    "reply_state": {"kind": "bits", "width": 4, "default": "x" * 4},
}


def normalize_vector(value: str, width: int) -> str:
    bits = value.strip().lower()
    if not bits:
        return "x" * width
    pad = bits[0] if bits[0] in {"x", "z"} else "0"
    return bits.rjust(width, pad)[-width:]


def bitstring_to_int(value: str) -> int | None:
    if not value or any(ch not in {"0", "1"} for ch in value):
        return None
    return int(value, 2)


def int_to_bits(value: int, width: int) -> str:
    mask = (1 << width) - 1
    return format(value & mask, f"0{width}b")


def parse_selected_vcd(path: Path) -> dict[str, list[tuple[int, str]]]:
    scalar_codes: dict[str, str] = {}
    vector_codes: dict[str, str] = {}
    bit_codes: dict[str, tuple[str, int]] = {}
    state: dict[str, str] = {name: spec["default"] for name, spec in SIGNAL_SPECS.items()}
    bit_state = {
        name: {bit: "x" for bit in range(spec["width"])}
        for name, spec in SIGNAL_SPECS.items()
        if spec["kind"] == "bits"
    }
    timelines = {name: [] for name in SIGNAL_SPECS}
    current_time = 0
    pending: set[str] = set()
    header_done = False

    def render_bits(name: str) -> str:
        width = SIGNAL_SPECS[name]["width"]
        return "".join(bit_state[name][bit] for bit in range(width - 1, -1, -1))

    def snapshot(name: str) -> str:
        if SIGNAL_SPECS[name]["kind"] == "bits":
            return render_bits(name)
        return state[name]

    def flush() -> None:
        for name in sorted(pending):
            value = snapshot(name)
            if not timelines[name] or timelines[name][-1][1] != value:
                timelines[name].append((current_time, value))
        pending.clear()

    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line:
            continue

        if not header_done:
            if line.startswith("$var "):
                parts = line.split()
                size = int(parts[2])
                code = parts[3]
                ref = " ".join(parts[4:-1])
                match = re.fullmatch(r"(.+)\s\[(\d+)\]", ref)
                if match:
                    base = match.group(1)
                    index = int(match.group(2))
                    if base in SIGNAL_SPECS and SIGNAL_SPECS[base]["kind"] == "bits":
                        bit_codes[code] = (base, index)
                elif ref in SIGNAL_SPECS:
                    if SIGNAL_SPECS[ref]["kind"] == "scalar" and size == 1:
                        scalar_codes[code] = ref
                    else:
                        vector_codes[code] = ref
            elif line.startswith("$enddefinitions"):
                header_done = True
            continue

        if line.startswith("#"):
            flush()
            current_time = int(line[1:])
            continue
        if line.startswith("$"):
            continue

        prefix = line[0].lower()
        if prefix in {"0", "1", "x", "z"}:
            code = line[1:]
            if code in scalar_codes:
                name = scalar_codes[code]
                state[name] = prefix
                pending.add(name)
            elif code in bit_codes:
                name, index = bit_codes[code]
                bit_state[name][index] = prefix
                pending.add(name)
        elif prefix in {"b", "r"}:
            value, code = line.split()
            if code in vector_codes:
                name = vector_codes[code]
                state[name] = normalize_vector(value[1:], SIGNAL_SPECS[name]["width"])
                pending.add(name)

    flush()
    return timelines


def value_at(timeline: list[tuple[int, str]], time_ps: int, default: str) -> str:
    current = default
    for event_time, value in timeline:
        if event_time > time_ps:
            break
        current = value
    return current


def slice_timeline(
    timeline: list[tuple[int, str]],
    start_ps: int,
    end_ps: int,
    default: str,
) -> list[tuple[int, str]]:
    out = [(0, value_at(timeline, start_ps, default))]
    for event_time, value in timeline:
        if start_ps < event_time <= end_ps and out[-1][1] != value:
            out.append((event_time - start_ps, value))
    return out


def first_time_for_int(
    timeline: list[tuple[int, str]],
    target: int,
    after_ps: int,
    default: str,
) -> int | None:
    if bitstring_to_int(value_at(timeline, after_ps, default)) == target:
        return after_ps
    for event_time, value in timeline:
        if event_time < after_ps:
            continue
        if bitstring_to_int(value) == target:
            return event_time
    return None


def build_diff_timeline(
    times_ps: list[int],
    pass_timeline: list[tuple[int, str]],
    fail_timeline: list[tuple[int, str]],
    *,
    mode: str,
) -> list[tuple[int, str]]:
    default = "x" if mode == "scalar" else "x" * 32
    out: list[tuple[int, str]] = []
    last_value: str | None = None
    for time_ps in times_ps:
        pass_value = value_at(pass_timeline, time_ps, SIGNAL_SPECS["reply_count" if mode == "gap" else "reply_we"]["default"])
        fail_value = value_at(fail_timeline, time_ps, SIGNAL_SPECS["reply_count" if mode == "gap" else "reply_we"]["default"])
        if mode == "gap":
            pass_int = bitstring_to_int(pass_value)
            fail_int = bitstring_to_int(fail_value)
            value = "x" * 32 if pass_int is None or fail_int is None else int_to_bits(pass_int - fail_int, 32)
        else:
            value = "x" if "x" in {pass_value, fail_value} else ("1" if pass_value != fail_value else "0")
        if last_value != value:
            out.append((time_ps, value))
            last_value = value
    return out


def write_combined_vcd(
    vcd_path: Path,
    focus_start_ps: int,
    focus_end_ps: int,
    pass_timelines: dict[str, list[tuple[int, str]]],
    fail_timelines: dict[str, list[tuple[int, str]]],
) -> dict:
    pass_signal_names = [
        "avm_burstcount",
        "hub_ul_valid",
        "hub_ul_filt_valid",
        "reply_we",
        "reply_count",
        "reply_state",
    ]
    fail_signal_names = list(pass_signal_names)
    base_times = {focus_start_ps, focus_end_ps}
    for name in ["tb_clk", "tb_reset_n", *pass_signal_names]:
        base_times.update(
            event_time
            for event_time, _ in pass_timelines[name]
            if focus_start_ps <= event_time <= focus_end_ps
        )
    for name in fail_signal_names:
        base_times.update(
            event_time
            for event_time, _ in fail_timelines[name]
            if focus_start_ps <= event_time <= focus_end_ps
        )
    abs_times = sorted(base_times)

    diff_gap_abs = build_diff_timeline(abs_times, pass_timelines["reply_count"], fail_timelines["reply_count"], mode="gap")
    diff_we_abs = build_diff_timeline(abs_times, pass_timelines["reply_we"], fail_timelines["reply_we"], mode="scalar")
    diff_count_abs = build_diff_timeline(abs_times, pass_timelines["reply_count"], fail_timelines["reply_count"], mode="scalar")

    first_gap_step_abs = None
    if diff_gap_abs:
        initial_gap = diff_gap_abs[0][1]
        for event_time, value in diff_gap_abs[1:]:
            if value != initial_gap:
                first_gap_step_abs = event_time
                break

    output_defs = [
        ("REF", "tb_clk", 1),
        ("REF", "tb_reset_n", 1),
        ("DIFF", "reply_count_gap", 32),
        ("DIFF", "reply_count_mismatch", 1),
        ("DIFF", "reply_we_mismatch", 1),
        ("A_PASS", "avm_burstcount", 9),
        ("A_PASS", "hub_ul_valid", 1),
        ("A_PASS", "hub_ul_filt_valid", 1),
        ("A_PASS", "reply_we", 1),
        ("A_PASS", "reply_count", 32),
        ("A_PASS", "reply_state", 4),
        ("B_FAIL", "avm_burstcount", 9),
        ("B_FAIL", "hub_ul_valid", 1),
        ("B_FAIL", "hub_ul_filt_valid", 1),
        ("B_FAIL", "reply_we", 1),
        ("B_FAIL", "reply_count", 32),
        ("B_FAIL", "reply_state", 4),
    ]
    codes = {f"{scope}.{name}": f"s{index}" for index, (scope, name, _) in enumerate(output_defs)}

    event_map: dict[int, list[tuple[str, str]]] = defaultdict(list)

    def add_timeline(scope: str, name: str, timeline: list[tuple[int, str]]) -> None:
        key = f"{scope}.{name}"
        for rel_time_ps, value in timeline:
            event_map[rel_time_ps].append((key, value))

    add_timeline("REF", "tb_clk", slice_timeline(pass_timelines["tb_clk"], focus_start_ps, focus_end_ps, SIGNAL_SPECS["tb_clk"]["default"]))
    add_timeline("REF", "tb_reset_n", slice_timeline(pass_timelines["tb_reset_n"], focus_start_ps, focus_end_ps, SIGNAL_SPECS["tb_reset_n"]["default"]))
    add_timeline(
        "DIFF",
        "reply_count_gap",
        [(event_time - focus_start_ps, value) for event_time, value in diff_gap_abs],
    )
    add_timeline(
        "DIFF",
        "reply_count_mismatch",
        [(event_time - focus_start_ps, value) for event_time, value in diff_count_abs],
    )
    add_timeline(
        "DIFF",
        "reply_we_mismatch",
        [(event_time - focus_start_ps, value) for event_time, value in diff_we_abs],
    )
    for name in pass_signal_names:
        add_timeline(
            "A_PASS",
            name,
            slice_timeline(pass_timelines[name], focus_start_ps, focus_end_ps, SIGNAL_SPECS[name]["default"]),
        )
    for name in fail_signal_names:
        add_timeline(
            "B_FAIL",
            name,
            slice_timeline(fail_timelines[name], focus_start_ps, focus_end_ps, SIGNAL_SPECS[name]["default"]),
        )

    rel_end_ps = focus_end_ps - focus_start_ps
    lines = [
        "$date",
        "\tGenerated by open_gtk.sh",
        "$end",
        "$version",
        "\tA/B focus compare",
        "$end",
        "$timescale",
        "\t1ps",
        "$end",
        "$scope module ab_focus $end",
    ]
    current_scope = None
    for scope, name, width in output_defs:
        if current_scope != scope:
            if current_scope is not None:
                lines.append("$upscope $end")
            lines.append(f"$scope module {scope} $end")
            current_scope = scope
        lines.append(f"$var wire {width} {codes[f'{scope}.{name}']} {name} $end")
    if current_scope is not None:
        lines.append("$upscope $end")
    lines.extend(
        [
            "$upscope $end",
            "$enddefinitions $end",
            "$dumpvars",
        ]
    )

    def emit_value(width: int, code: str, value: str) -> str:
        return f"{value}{code}" if width == 1 else f"b{value} {code}"

    width_lookup = {f"{scope}.{name}": width for scope, name, width in output_defs}
    for key, value in sorted(event_map[0], key=lambda item: item[0]):
        lines.append(emit_value(width_lookup[key], codes[key], value))
    lines.append("$end")

    for rel_time_ps in sorted(time_ps for time_ps in event_map if time_ps != 0):
        lines.append(f"#{rel_time_ps}")
        for key, value in sorted(event_map[rel_time_ps], key=lambda item: item[0]):
            lines.append(emit_value(width_lookup[key], codes[key], value))
    if not any(line == f"#{rel_end_ps}" for line in lines):
        lines.append(f"#{rel_end_ps}")
    vcd_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    return {
        "window_start_ns": focus_start_ps // 1000,
        "window_end_ns": focus_end_ps // 1000,
        "first_gap_step_ns": None if first_gap_step_abs is None else first_gap_step_abs // 1000,
    }


def write_compare_gtkw(
    vcd_path: Path,
    gtkw_path: Path,
    focus_info: dict,
) -> None:
    marker_specs: list[tuple[str, int]] = [
        ("T0_LEN16_REQ", focus_info["len16_req_rel_ps"]),
        ("T1_REPLY_COUNT_GAP_STEP", focus_info["cursor_rel_ps"]),
        ("T2_LEN16_DONE", focus_info["len16_done_rel_ps"]),
    ]
    marker_positions_ps = [str(time_ps) for _, time_ps in marker_specs]
    marker_names = [name for name, _ in marker_specs]
    star_fields = [str(focus_info["cursor_rel_ps"]), *marker_positions_ps, "-1", "-1", "-1", "-1"]
    lines = [
        "[*]",
        "[*] GTKWave Analyzer v3.3.79",
        "[*]",
        f'[dumpfile] "{vcd_path}"',
        f'[savefile] "{gtkw_path}"',
        "[timestart] 0",
        "[size] 1700 980",
        "[pos] -1 -1",
        "*" + " ".join(star_fields),
    ]
    for name in marker_names:
        lines.append(f"[markername_long] {name}")
    lines.extend(
        [
            "[sst_width] 240",
            "[signals_width] 360",
            "[sst_expanded] 1",
            "@200",
            "-A/B focused compare: A=pass baseline, B=fail replay, DIFF at top",
        ]
    )
    lines.extend(group_start("REF"))
    lines.extend(scalar("ab_focus.REF.tb_clk", 0))
    lines.extend(scalar("ab_focus.REF.tb_reset_n", 1))
    lines.extend(group_end())
    lines.extend(group_start("DIFF"))
    lines.extend(vector("ab_focus.DIFF.reply_count_gap", 31, 0, 1, "@424", "reply_count_gap (A-B, main diff)"))
    lines.extend(scalar("ab_focus.DIFF.reply_count_mismatch", 1, label="reply_count_mismatch"))
    lines.extend(scalar("ab_focus.DIFF.reply_we_mismatch", 1, label="reply_we_mismatch"))
    lines.extend(group_end())
    lines.extend(group_start("A PASS"))
    lines.extend(vector("ab_focus.A_PASS.avm_burstcount", 8, 0, 4, "@24"))
    lines.extend(vector("ab_focus.A_PASS.avm_burstcount", 8, 0, 4, "@8024", "avm_burstcount (analog)"))
    lines.extend(scalar("ab_focus.A_PASS.hub_ul_valid", 3))
    lines.extend(scalar("ab_focus.A_PASS.hub_ul_filt_valid", 3))
    lines.extend(scalar("ab_focus.A_PASS.reply_we", 3))
    lines.extend(vector("ab_focus.A_PASS.reply_count", 31, 0, 4, "@24"))
    lines.extend(vector("ab_focus.A_PASS.reply_count", 31, 0, 4, "@8024", "reply_count (analog)"))
    lines.extend(vector("ab_focus.A_PASS.reply_state", 3, 0, 5))
    lines.extend(group_end())
    lines.extend(group_start("B FAIL"))
    lines.extend(vector("ab_focus.B_FAIL.avm_burstcount", 8, 0, 4, "@24"))
    lines.extend(vector("ab_focus.B_FAIL.avm_burstcount", 8, 0, 4, "@8024", "avm_burstcount (analog)"))
    lines.extend(scalar("ab_focus.B_FAIL.hub_ul_valid", 3))
    lines.extend(scalar("ab_focus.B_FAIL.hub_ul_filt_valid", 3))
    lines.extend(scalar("ab_focus.B_FAIL.reply_we", 3))
    lines.extend(vector("ab_focus.B_FAIL.reply_count", 31, 0, 4, "@24"))
    lines.extend(vector("ab_focus.B_FAIL.reply_count", 31, 0, 4, "@8024", "reply_count (analog)"))
    lines.extend(vector("ab_focus.B_FAIL.reply_state", 3, 0, 5))
    lines.extend(group_end())
    gtkw_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


a_log = Path(sys.argv[1])
b_log = Path(sys.argv[2])
a_vcd = Path(sys.argv[3])
b_vcd = Path(sys.argv[4])
a_gtkw = Path(sys.argv[5])
b_gtkw = Path(sys.argv[6])
compare_vcd = Path(sys.argv[7])
compare_gtkw = Path(sys.argv[8])
summary_json = Path(sys.argv[9])

summary = {
    "a": parse_log(a_log),
    "b": parse_log(b_log),
}

write_raw_gtkw(a_vcd, a_gtkw, summary["a"], "Raw A: reconstructed pre-fix same-edge RX bridge")
write_raw_gtkw(b_vcd, b_gtkw, summary["b"], "Raw B: current fixed registered RX bridge")

pass_timelines = parse_selected_vcd(b_vcd)
fail_timelines = parse_selected_vcd(a_vcd)
sweep8_done_ps = summary["b"]["sweep_markers"].get("8", {}).get("time_ns", 0) * 1000
len16_done_ps = summary["b"]["sweep_markers"].get("16", {}).get("time_ns", 0) * 1000
len16_req_ps = first_time_for_int(
    pass_timelines["avm_burstcount"],
    16,
    sweep8_done_ps,
    SIGNAL_SPECS["avm_burstcount"]["default"],
)
if len16_req_ps is None:
    len16_req_ps = max(0, len16_done_ps - 10_000_000)
focus_start_ps = max(0, len16_req_ps - 6_000_000)
focus_end_ps = max(len16_done_ps + 4_000_000, len16_req_ps + 1_000_000)
focus_window = write_combined_vcd(compare_vcd, focus_start_ps, focus_end_ps, pass_timelines, fail_timelines)
cursor_abs_ps = (focus_window["first_gap_step_ns"] or (len16_req_ps // 1000)) * 1000
focus_info = {
    "len16_req_rel_ps": len16_req_ps - focus_start_ps,
    "len16_done_rel_ps": len16_done_ps - focus_start_ps,
    "cursor_rel_ps": cursor_abs_ps - focus_start_ps,
}
write_compare_gtkw(compare_vcd, compare_gtkw, focus_info)

summary["compare"] = {
    "a_pass_source": "raw_b",
    "b_fail_source": "raw_a",
    "a_pass_len16_reply_count": summary["b"]["sweep_markers"].get("16", {}).get("reply_count"),
    "b_fail_len16_reply_count": summary["a"]["sweep_markers"].get("16", {}).get("reply_count"),
    "focus_window_ns": {
        "start": focus_window["window_start_ns"],
        "end": focus_window["window_end_ns"],
    },
    "markers_ns": {
        "len16_req": len16_req_ps // 1000,
        "reply_count_gap_step": focus_window["first_gap_step_ns"],
        "len16_done": len16_done_ps // 1000,
    },
}
summary_json.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
PY
}

print_summary() {
    python3 - "${summary_json}" "${compare_gtkw}" "${a_gtkw}" "${b_gtkw}" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))


def fmt_time(entry: dict | None) -> str:
    if not entry:
        return "n/a"
    return f"{entry['time_ns']} ns"


def describe(key: str, data: dict) -> None:
    sweep8 = data["sweep_markers"].get("8")
    sweep16 = data["sweep_markers"].get("16")
    aggregate = data["aggregate"]
    print(f"{key}: raw bounded capture")
    print(f"  sweep_len=8  reply_count={sweep8['reply_count'] if sweep8 else 'n/a'} at {fmt_time(sweep8)}")
    print(f"  sweep_len=16 reply_count={sweep16['reply_count'] if sweep16 else 'n/a'} at {fmt_time(sweep16)}")
    if aggregate is not None:
        print(
            f"  aggregate reply_count={aggregate['reply_count']} "
            f"ul_capture_cnt={aggregate['ul_capture_cnt']} at {aggregate['time_ns']} ns"
        )


print("A/B burst compare summary")
print(f"Focused compare savefile: {sys.argv[2]}")
print(f"Raw A(fail replay) savefile: {sys.argv[3]}")
print(f"Raw B(pass baseline) savefile: {sys.argv[4]}")
describe("Raw A / fail replay", summary["a"])
describe("Raw B / pass baseline", summary["b"])
compare = summary["compare"]
print(
    "Combined view mapping: "
    "A=pass baseline from raw B, "
    "B=fail replay from raw A."
)
print(
    "Focused len=16 window: "
    f"{compare['focus_window_ns']['start']} ns -> {compare['focus_window_ns']['end']} ns"
)
print(
    "Markers: "
    f"T0_LEN16_REQ={compare['markers_ns']['len16_req']} ns, "
    f"T1_REPLY_COUNT_GAP_STEP={compare['markers_ns']['reply_count_gap_step']} ns, "
    f"T2_LEN16_DONE={compare['markers_ns']['len16_done']} ns"
)
if compare["a_pass_len16_reply_count"] is not None and compare["b_fail_len16_reply_count"] is not None:
    print(
        "len=16 comparison: "
        f"A(pass) reply_count={compare['a_pass_len16_reply_count']} vs "
        f"B(fail) reply_count={compare['b_fail_len16_reply_count']}"
    )
print("Main difference at top of the focused view: DIFF.reply_count_gap and DIFF.reply_we_mismatch.")
PY
}

if [[ "${need_regen}" = "1" ]]; then
    prepare_variants
    write_do "${a_do}" "${a_vcd}"
    write_do "${b_do}" "${b_vcd}"
    run_variant "B" "${b_tb}" "${b_work}" "${b_do}"
    run_variant "A" "${a_tb}" "${a_work}" "${a_do}"
fi

build_summary_and_gtkw
print_summary

if [[ "${no_open}" = "1" ]]; then
    exit 0
fi

case "${view}" in
    compare)
        gtkwave "${compare_gtkw}" >/dev/null 2>&1 &
        ;;
    a)
        gtkwave "${a_gtkw}" >/dev/null 2>&1 &
        ;;
    b)
        gtkwave "${b_gtkw}" >/dev/null 2>&1 &
        ;;
    both)
        gtkwave "${a_gtkw}" >/dev/null 2>&1 &
        gtkwave "${b_gtkw}" >/dev/null 2>&1 &
        ;;
esac
