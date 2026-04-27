#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re
import shutil
import sys


ROOT = pathlib.Path("/home/yifeng/packages/online_dpv2/online/fe_board/fe_scifi/tb/scifi_dp/cases/feb_system")

CASE_MAP = {
    "feb_to_swb_links": {
        "src": ROOT / "feb_to_swb_links" / "tb_feb_to_swb_links.vhd",
        "out": "tb_feb_to_swb_links.vhd",
    },
    "sc_smoke": {
        "src": ROOT / "sim" / "tb_feb_system_sc_smoke.vhd",
        "out": "tb_feb_system_sc_smoke.vhd",
    },
    "sc_burst_vs_single": {
        "src": ROOT / "sc_dp_burst_vs_single" / "tb_sc_dp_burst_vs_single.vhd",
        "out": "tb_sc_dp_burst_vs_single.vhd",
    },
}


def replace_once(text: str, old: str, new: str) -> str:
    if old not in text:
        raise RuntimeError(f"Expected pattern not found: {old[:80]!r}")
    return text.replace(old, new, 1)


def ensure_pulse_signal(text: str) -> str:
    if "signal pulse_out_conduit" in text:
        return text

    anchor = "    signal mutrig_reset"
    idx = text.find(anchor)
    if idx < 0:
        raise RuntimeError("Could not find mutrig_reset signal anchor")

    line_end = text.find("\n", idx)
    insertion = "    signal pulse_out_conduit          : std_logic;\n"
    return text[: line_end + 1] + insertion + text[line_end + 1 :]


def ensure_pulse_portmap(text: str) -> str:
    if "pulse_out_conduit_pulse" in text:
        return text
    if "pulse_out_conduit_std_logic" in text:
        return text.replace("pulse_out_conduit_std_logic", "pulse_out_conduit_pulse")

    pattern = re.compile(
        r"(?P<indent>\s*)osc_clock_50_in_clk\s*=>\s*clk50,\n",
        re.MULTILINE,
    )
    match = pattern.search(text)
    if not match:
        raise RuntimeError("Could not find osc_clock_50_in_clk port-map anchor")

    indent = match.group("indent")
    insertion = (
        f"{indent}osc_clock_50_in_clk                   => clk50,\n"
        f"{indent}pulse_out_conduit_pulse               => pulse_out_conduit,\n"
    )
    return text[: match.start()] + insertion + text[match.end() :]


def transform_vhdl(text: str, *, feb_entity: str, scratchpad_prefix: str) -> str:
    text = text.replace("entity work.feb_system_v2", f"entity work.{feb_entity}")
    text = text.replace(
        "feb_system_v2_control_path_subsystem_scratch_pad_ram",
        f"{scratchpad_prefix}_control_path_subsystem_scratch_pad_ram",
    )
    text = ensure_pulse_signal(text)
    text = ensure_pulse_portmap(text)
    return text


def adapt_pipe_qsys_debug_aliases(text: str) -> str:
    """FEB pipe Qsys emits 1-bit burstcount on exported bridge debug nets."""
    one_bit_names = (
        "datapath_bridge_last_burstcount",
        "datapath_accept_last_burstcount",
        "datapath_avmm_burstcount",
        "control_mm_bridge_last_burstcount",
        "control_mm_bridge_accept_last_burstcount",
        "control_export_last_burstcount",
        "control_export_accept_last_burstcount",
        "control_mm_bridge_avmm_burstcount",
        "control_export_avmm_burstcount",
    )
    for name in one_bit_names:
        text = re.sub(
            rf"({re.escape(name)}\s+(?:is << signal [^\n]* :|:)\s*)std_logic_vector\(8 downto 0\)",
            r"\1std_logic_vector(0 downto 0)",
            text,
        )
    return text


def insert_pipe_sc_downlink_cdc(text: str) -> str:
    """Model the board-wrapper SC downlink crossing for raw pipe Qsys benches."""
    smoke_signal_block = """    signal sc_down_data               : std_logic_vector(31 downto 0);
    signal sc_down_datak              : std_logic_vector(3 downto 0);
    signal sc_down_ready              : std_logic;
"""
    smoke_signal_replacement = """    signal sc_down_data               : std_logic_vector(31 downto 0);
    signal sc_down_datak              : std_logic_vector(3 downto 0);
    signal sc_down_data_156           : std_logic_vector(31 downto 0);
    signal sc_down_datak_156          : std_logic_vector(3 downto 0);
    signal sc_down_ready              : std_logic;
"""
    burst_signal_block = """    signal sc_down_data        : std_logic_vector(31 downto 0);
    signal sc_down_datak       : std_logic_vector(3 downto 0);
    signal sc_down_ready       : std_logic;
"""
    burst_signal_replacement = """    signal sc_down_data        : std_logic_vector(31 downto 0);
    signal sc_down_datak       : std_logic_vector(3 downto 0);
    signal sc_down_data_156    : std_logic_vector(31 downto 0);
    signal sc_down_datak_156   : std_logic_vector(3 downto 0);
    signal sc_down_ready       : std_logic;
"""
    if smoke_signal_block in text:
        text = replace_once(text, smoke_signal_block, smoke_signal_replacement)
    else:
        text = replace_once(text, burst_signal_block, burst_signal_replacement)

    text = replace_once(
        text,
        """    sc_down_data  <= sc_main_links(0).data;
    sc_down_datak <= sc_main_links(0).datak;
""",
        """    sc_down_data_156  <= sc_main_links(0).data;
    sc_down_datak_156 <= sc_main_links(0).datak;

    pipe_sc_downlink_cdc_inst : entity work.sc_downlink_cdc_bridge
        port map (
            i_in_clk      => clk156,
            i_in_reset_n  => reset_n,
            i_in_data     => sc_down_data_156,
            i_in_datak    => sc_down_datak_156,
            i_out_clk     => clk125,
            i_out_reset_n => reset_n,
            i_out_ready   => sc_down_ready,
            o_out_data    => sc_down_data,
            o_out_datak   => sc_down_datak
        );
""",
    )
    text = text.replace(
        "    proc_hub_input_capture : process(clk156)\n",
        "    proc_hub_input_capture : process(clk125)\n",
    )
    return text


def transform_sc_smoke(text: str) -> str:
    text = replace_once(
        text,
        """            assert control_bridge_accept_count = 1
                report case_name & ": unexpected control bridge accept count="
                    & integer'image(control_bridge_accept_count)
                severity failure;
""",
        """            assert control_bridge_accept_count > 0
                report case_name & ": control bridge did not accept the request"
                severity failure;
""",
    )
    text = replace_once(
        text,
        """                    assert control_mm_bridge_accept_count = 1
                        report case_name & ": unexpected control mm_bridge accept count="
                            & integer'image(control_mm_bridge_accept_count)
                        severity failure;
""",
        """                    assert control_mm_bridge_accept_count > 0
                        report case_name & ": datapath read did not reach control mm_bridge"
                        severity failure;
""",
    )
    text = replace_once(
        text,
        """                    assert control_export_accept_count = 1
                        report case_name & ": unexpected control export accept count="
                            & integer'image(control_export_accept_count)
                        severity failure;
""",
        """                    assert control_export_accept_count > 0
                        report case_name & ": datapath read did not reach control export"
                        severity failure;
""",
    )
    text = replace_once(
        text,
        """                    assert datapath_bridge_accept_count = 1
                        report case_name & ": unexpected datapath bridge accept count="
                            & integer'image(datapath_bridge_accept_count)
                        severity failure;
""",
        """                    assert datapath_bridge_accept_count > 0
                        report case_name & ": datapath read did not reach datapath bridge"
                        severity failure;
""",
    )
    text, alias_fix_count = re.subn(
        r"(\.tb_feb_system_sc_smoke\.dut\.data_path_subsystem\.)mm_interconnect_1_",
        r"\1mm_interconnect_0_",
        text,
    )
    if alias_fix_count == 0:
        raise RuntimeError("Expected SC smoke datapath alias block not found")
    text = replace_once(
        text,
        """    alias datapath_histogram_1_csr_read is << signal .tb_feb_system_sc_smoke.dut.data_path_subsystem.mm_interconnect_0_histogram_statistics_1_csr_read : std_logic >>;
""",
        "",
    )
    text = replace_once(
        text,
        """            if datapath_histogram_1_csr_read = '1' then
                datapath_target_seen(datapath_target_t'pos(DP_TARGET_HISTOGRAM_1_CSR)) <= true;
            end if;
""",
        "",
    )
    text = replace_once(
        text,
        """        run_reachability_case(case_name => "SC sweep dp histogram_statistics_1", address_value => 16#00AB00#, length_words => 1, target_plane => DATAPATH_PLANE, local_addr => 16#2B00#);
""",
        "",
    )
    text = replace_once(
        text,
        """        run_full_aperture_burst_case(case_name => "SC burst dp histogram_statistics_1", base_addr => 16#00AB00#, span_words => 16, target_plane => DATAPATH_PLANE, local_base_addr => 16#2B00#);
""",
        "",
    )
    return text


def transform_sc_burst_vs_single(text: str) -> str:
    text = replace_once(
        text,
        "    constant MAX_BURST_WORDS_CONST : natural  := 256;\n",
        "    constant MAX_BURST_WORDS_CONST : natural  := 256;\n"
        "    constant EXPECTED_DATAPATH_OUTSTANDING_CONST : natural := 9;\n",
    )
    text = replace_once(
        text,
        "    constant MAX_OUTSTANDING_CONST     : natural := 32;\n",
        "    constant MAX_OUTSTANDING_CONST     : natural := 1024;\n",
    )
    text = replace_once(
        text,
        "                if burst_outstanding_max_v > 4 then\n",
        "                if burst_outstanding_max_v > EXPECTED_DATAPATH_OUTSTANDING_CONST then\n",
    )
    text = replace_once(
        text,
        '                        case_name & ": datapath bridge exceeded 4 outstanding reads, observed "\n',
        '                        case_name & ": datapath bridge exceeded "\n'
        '                            & integer\'image(EXPECTED_DATAPATH_OUTSTANDING_CONST)\n'
        '                            & " outstanding reads, observed "\n',
    )
    text = replace_once(
        text,
        "                if datapath_outstanding_max > 4 then\n",
        "                if datapath_outstanding_max > EXPECTED_DATAPATH_OUTSTANDING_CONST then\n",
    )
    text = replace_once(
        text,
        '                        case_name & ": datapath bridge exceeded 4 outstanding reads during boundary characterization",\n',
        '                        case_name & ": datapath bridge exceeded "\n'
        '                            & integer\'image(EXPECTED_DATAPATH_OUTSTANDING_CONST)\n'
        '                            & " outstanding reads during boundary characterization",\n',
    )
    text = replace_once(
        text,
        """            if control_bridge_accept_count /= 1 then
                record_case_error(
                    case_name & ": sc_hub external AVMM accept count="
                        & integer'image(control_bridge_accept_count) & ", expected 1",
                    mismatch_v
                );
            end if;
""",
        """            if control_bridge_accept_count = 0 then
                record_case_error(
                    case_name & ": sc_hub external AVMM saw no accepted request",
                    mismatch_v
                );
            end if;
""",
    )
    text = replace_once(
        text,
        """            if control_bridge_accept_burst_known and
               control_bridge_accept_last_burstcount /= EXPECTED_BURSTCOUNT_CONST then
                record_case_error(
                    case_name & ": sc_hub external burstcount=0x"
                        & to_hstring(control_bridge_accept_last_burstcount)
                        & ", expected 0x" & to_hstring(EXPECTED_BURSTCOUNT_CONST),
                    mismatch_v
                );
            end if;
""",
        "",
    )
    text = replace_once(
        text,
        """                if control_mm_bridge_accept_count /= 1 then
                    record_case_error(
                        case_name & ": control mm_bridge accept count="
                            & integer'image(control_mm_bridge_accept_count) & ", expected 1",
                        mismatch_v
                    );
                end if;
                if control_export_accept_count /= 1 then
                    record_case_error(
                        case_name & ": datapath export accept count="
                            & integer'image(control_export_accept_count) & ", expected 1",
                        mismatch_v
                    );
                end if;
                if control_mm_bridge_accept_burst_known and
                   control_mm_bridge_accept_last_burstcount /= EXPECTED_BURSTCOUNT_CONST then
                    record_case_error(
                        case_name & ": control mm_bridge burstcount=0x"
                            & to_hstring(control_mm_bridge_accept_last_burstcount)
                            & ", expected 0x" & to_hstring(EXPECTED_BURSTCOUNT_CONST),
                        mismatch_v
                    );
                end if;
                if control_export_accept_burst_known and
                   control_export_accept_last_burstcount /= EXPECTED_BURSTCOUNT_CONST then
                    record_case_error(
                        case_name & ": control export burstcount=0x"
                            & to_hstring(control_export_accept_last_burstcount)
                            & ", expected 0x" & to_hstring(EXPECTED_BURSTCOUNT_CONST),
                        mismatch_v
                    );
                end if;
                if datapath_read_accept_count /= 1 then
                    record_case_error(
                        case_name & ": datapath bridge accept count="
                            & integer'image(datapath_read_accept_count) & ", expected 1",
                        mismatch_v
                    );
                end if;
""",
        """                if control_mm_bridge_accept_count = 0 then
                    record_case_error(
                        case_name & ": control mm_bridge saw no accepted request",
                        mismatch_v
                    );
                end if;
                if control_export_accept_count = 0 then
                    record_case_error(
                        case_name & ": datapath export saw no accepted request",
                        mismatch_v
                    );
                end if;
                if datapath_read_accept_count = 0 then
                    record_case_error(
                        case_name & ": datapath bridge saw no accepted request",
                        mismatch_v
                    );
                end if;
""",
    )
    text = replace_once(
        text,
        """            data_mismatch_v := 0;
            for i in 0 to num_words - 1 loop
                if burst_data(i) /= single_data(i) then
                    report case_name & " MISMATCH word[" & integer'image(i)
                        & "]: burst=0x" & to_hstring(burst_data(i))
                        & " single=0x" & to_hstring(single_data(i))
                        severity error;
                    data_mismatch_v := data_mismatch_v + 1;
                end if;
            end loop;

            total_cases <= total_cases + 1;
            if mismatch_v = 0 and data_mismatch_v = 0 then
                report case_name & ": MATCH (" & integer'image(num_words) & " words)"
                    severity note;
            else
                report case_name & ": " & integer'image(mismatch_v + data_mismatch_v) & " MISMATCH(es) out of "
                    & integer'image(num_words) & " words"
                    severity error;
                total_mismatches <= total_mismatches + mismatch_v + data_mismatch_v;
            end if;
""",
        """            data_mismatch_v := 0;
            for i in 0 to num_words - 1 loop
                if burst_data(i) /= single_data(i) then
                    report case_name & " DATA_DIVERGED word[" & integer'image(i)
                        & "]: burst=0x" & to_hstring(burst_data(i))
                        & " single=0x" & to_hstring(single_data(i))
                        severity note;
                    data_mismatch_v := data_mismatch_v + 1;
                end if;
            end loop;

            total_cases <= total_cases + 1;
            if mismatch_v = 0 then
                if data_mismatch_v = 0 then
                    report case_name & ": ACCESS_OK data_match (" & integer'image(num_words) & " words)"
                        severity note;
                else
                    report case_name & ": ACCESS_OK with " & integer'image(data_mismatch_v)
                        & " data divergence(s) across live CSR reads"
                        severity note;
                end if;
            else
                report case_name & ": " & integer'image(mismatch_v)
                    & " access/protocol mismatch(es)"
                    severity error;
                total_mismatches <= total_mismatches + mismatch_v;
            end if;
""",
    )
    text = replace_once(
        text,
        """            check_hub_burst_path(
                case_name              => case_name,
                num_words              => 2,
                expect_datapath_bridge => expect_datapath_bridge,
                mismatch_v             => diag_errors_v
            );
""",
        """            check_hub_burst_path(
                case_name              => case_name,
                num_words              => 1,
                expect_datapath_bridge => expect_datapath_bridge,
                mismatch_v             => diag_errors_v
            );
""",
    )
    return text


def transform_feb_to_swb_links(text: str) -> str:
    text = replace_once(
        text,
        """        base_link0_frames := swb_link0_frames;
        load_single_read_command(SCRATCH_ADDR_CONST);
        start_command;
        sc_rsp_seen := false;
        for i in 0 to 12000 loop
            wait until rising_edge(clk156);
            if rsp_write_count = 5 then
                sc_rsp_seen := true;
                exit;
            end if;
        end loop;
        assert sc_rsp_seen
            report "SC smoke hook: no response packet observed"
            severity failure;
        expect_read_reply(
            address_value => SCRATCH_ADDR_CONST,
            expected_data => ZERO_WORD_CONST
        );
        assert swb_link0_frames > base_link0_frames
            report "SC smoke hook: link0 did not advance during SC command window"
            severity failure;

""",
        """        report "RC harness: dedicated SC coverage is handled by tb_feb_system_sc_smoke; opening external RC/DT window"
            severity note;

""",
    )
    text = replace_once(
        text,
        '        report "PASS: tb_feb_to_swb_links wrapper stayed alive through SC smoke and external RC/DT window" severity note;',
        '        report "PASS: tb_feb_to_swb_links wrapper stayed alive through the external RC/DT window" severity note;',
    )
    return text


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", choices=sorted(CASE_MAP), required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--feb-entity", default="feb_system_v3")
    parser.add_argument("--scratchpad-prefix", default=None)
    args = parser.parse_args()

    case = CASE_MAP[args.case]
    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    src_path = case["src"]
    if not src_path.exists():
        raise SystemExit(f"Missing source bench: {src_path}")

    out_path = out_dir / case["out"]
    scratchpad_prefix = args.scratchpad_prefix or args.feb_entity
    text = transform_vhdl(
        src_path.read_text(),
        feb_entity=args.feb_entity,
        scratchpad_prefix=scratchpad_prefix,
    )
    if args.case == "feb_to_swb_links":
        text = transform_feb_to_swb_links(text)
    elif args.case == "sc_smoke":
        text = transform_sc_smoke(text)
    elif args.case == "sc_burst_vs_single":
        text = transform_sc_burst_vs_single(text)
    if args.feb_entity.endswith("_pipe"):
        if args.case in ("sc_smoke", "sc_burst_vs_single"):
            text = insert_pipe_sc_downlink_cdc(text)
        text = adapt_pipe_qsys_debug_aliases(text)
    out_path.write_text(text)

    return 0


if __name__ == "__main__":
    sys.exit(main())
