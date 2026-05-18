-- File name: tb_hist_bridge_switch_repro.vhd
-- Description:
--     Directed FEB histogram ingress bridge reproducer for the post-to-pre
--     source switch condition seen on board. The pre-rbCAM side is driven with
--     MTS-style run-level packet markers: SOP on the first run hit and EOP only
--     on the terminating empty marker.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;
use std.textio.all;

entity tb_hist_bridge_switch_repro is
    generic (
        REPORT_PREFIX : string := "hist_bridge_switch"
    );
end entity tb_hist_bridge_switch_repro;

architecture sim of tb_hist_bridge_switch_repro is

    constant CLK_PERIOD_CONST : time := 10 ns;

    type hist_source_t is (SRC_NONE, SRC_POST, SRC_PRE);

    signal clk                 : std_logic := '0';
    signal rst                 : std_logic := '1';
    signal csr_address         : std_logic_vector(1 downto 0) := (others => '0');
    signal csr_read            : std_logic := '0';
    signal csr_write           : std_logic := '0';
    signal csr_writedata       : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_readdata        : std_logic_vector(31 downto 0);
    signal csr_waitrequest     : std_logic;

    signal pre_data            : std_logic_vector(38 downto 0) := (others => '0');
    signal pre_valid           : std_logic := '0';
    signal pre_ready           : std_logic;
    signal pre_sop             : std_logic := '0';
    signal pre_eop             : std_logic := '0';
    signal pre_channel         : std_logic_vector(3 downto 0) := (others => '0');
    signal pre_empty           : std_logic := '0';
    signal pre_error           : std_logic := '0';
    signal pre_out_data        : std_logic_vector(38 downto 0);
    signal pre_out_valid       : std_logic;
    signal pre_out_ready       : std_logic := '1';
    signal pre_out_sop         : std_logic;
    signal pre_out_eop         : std_logic;
    signal pre_out_channel     : std_logic_vector(3 downto 0);
    signal pre_out_empty       : std_logic;
    signal pre_out_error       : std_logic;

    signal post_data           : std_logic_vector(35 downto 0) := (others => '0');
    signal post_valid          : std_logic := '0';
    signal post_ready          : std_logic;
    signal post_sop            : std_logic := '0';
    signal post_eop            : std_logic := '0';
    signal post_out_data       : std_logic_vector(35 downto 0);
    signal post_out_valid      : std_logic;
    signal post_out_ready      : std_logic := '1';
    signal post_out_sop        : std_logic;
    signal post_out_eop        : std_logic;

    signal hist_data           : std_logic_vector(38 downto 0);
    signal hist_valid          : std_logic;
    signal hist_ready          : std_logic := '1';
    signal hist_sop            : std_logic;
    signal hist_eop            : std_logic;
    signal hist_channel        : std_logic_vector(3 downto 0);

    signal expected_hist_source : hist_source_t := SRC_NONE;
    signal hist_post_count      : natural := 0;
    signal hist_pre_count       : natural := 0;
    signal cycle_count          : natural := 0;

    file events_file : text;
    file summary_file : text;

    function bit_int(value : std_logic) return integer is
    begin
        if value = '1' then
            return 1;
        end if;
        return 0;
    end function bit_int;

    function make_pre_hit(
        constant asic_id : natural;
        constant channel_id : natural;
        constant tag : natural
    ) return std_logic_vector is
        variable word_v : unsigned(38 downto 0) := (others => '0');
    begin
        word_v(37 downto 35) := to_unsigned(asic_id, 3);
        word_v(34 downto 30) := to_unsigned(channel_id, 5);
        word_v(15 downto 0) := to_unsigned(tag, 16);
        return std_logic_vector(word_v);
    end function make_pre_hit;

    procedure write_status_row(
        constant event_name : in string;
        constant status : in std_logic_vector(31 downto 0)
    ) is
        variable row : line;
    begin
        write(row, integer'image(cycle_count));
        write(row, string'(","));
        write(row, event_name);
        write(row, string'(",0x"));
        write(row, to_hstring(status));
        write(row, string'(","));
        write(row, bit_int(status(0)));
        write(row, string'(","));
        write(row, bit_int(status(1)));
        write(row, string'(","));
        write(row, bit_int(status(2)));
        write(row, string'(","));
        write(row, bit_int(status(8)));
        write(row, string'(","));
        write(row, bit_int(status(9)));
        write(row, string'(","));
        write(row, bit_int(status(10)));
        write(row, string'(","));
        write(row, bit_int(status(11)));
        write(row, string'(","));
        write(row, hist_post_count);
        write(row, string'(","));
        write(row, hist_pre_count);
        writeline(events_file, row);
    end procedure write_status_row;

    procedure write_summary_row(
        constant event_name : in string;
        constant status : in std_logic_vector(31 downto 0);
        constant note_text : in string
    ) is
        variable row : line;
    begin
        write(row, string'("| "));
        write(row, event_name);
        write(row, string'(" | `0x"));
        write(row, to_hstring(status));
        write(row, string'("` | "));
        write(row, bit_int(status(0)));
        write(row, string'(" | "));
        write(row, bit_int(status(1)));
        write(row, string'(" | "));
        write(row, bit_int(status(2)));
        write(row, string'(" | "));
        write(row, bit_int(status(8)));
        write(row, string'(" | "));
        write(row, bit_int(status(9)));
        write(row, string'(" | "));
        write(row, bit_int(status(10)));
        write(row, string'(" | "));
        write(row, bit_int(status(11)));
        write(row, string'(" | "));
        write(row, note_text);
        write(row, string'(" |"));
        writeline(summary_file, row);
    end procedure write_summary_row;

    procedure csr_write_word(
        signal address_s   : out std_logic_vector(1 downto 0);
        signal write_s     : out std_logic;
        signal writedata_s : out std_logic_vector(31 downto 0);
        constant addr      : in natural;
        constant data      : in std_logic_vector(31 downto 0)
    ) is
    begin
        wait until rising_edge(clk);
        address_s   <= std_logic_vector(to_unsigned(addr, address_s'length));
        writedata_s <= data;
        write_s     <= '1';
        wait until rising_edge(clk);
        write_s     <= '0';
        wait until rising_edge(clk);
    end procedure csr_write_word;

    procedure csr_read_word(
        signal address_s : out std_logic_vector(1 downto 0);
        signal read_s    : out std_logic;
        signal readdata_s : in std_logic_vector(31 downto 0);
        constant addr    : in natural;
        variable data    : out std_logic_vector(31 downto 0)
    ) is
    begin
        address_s <= std_logic_vector(to_unsigned(addr, address_s'length));
        read_s <= '1';
        wait for 1 ns;
        data := readdata_s;
        wait until rising_edge(clk);
        read_s <= '0';
        wait until rising_edge(clk);
    end procedure csr_read_word;

    procedure drive_pre_word(
        signal data_s    : out std_logic_vector(38 downto 0);
        signal valid_s   : out std_logic;
        signal sop_s     : out std_logic;
        signal eop_s     : out std_logic;
        signal empty_s   : out std_logic;
        signal channel_s : out std_logic_vector(3 downto 0);
        signal ready_s   : in std_logic;
        constant word    : in std_logic_vector(38 downto 0);
        constant channel : in std_logic_vector(3 downto 0);
        constant sop     : in std_logic := '0';
        constant eop     : in std_logic := '0';
        constant empty   : in std_logic := '0'
    ) is
    begin
        data_s    <= word;
        channel_s <= channel;
        sop_s     <= sop;
        eop_s     <= eop;
        empty_s   <= empty;
        valid_s   <= '1';
        loop
            wait until rising_edge(clk);
            exit when ready_s = '1';
        end loop;
        valid_s <= '0';
        sop_s   <= '0';
        eop_s   <= '0';
        empty_s <= '0';
        wait until rising_edge(clk);
    end procedure drive_pre_word;

    procedure drive_post_word(
        signal data_s  : out std_logic_vector(35 downto 0);
        signal valid_s : out std_logic;
        signal sop_s   : out std_logic;
        signal eop_s   : out std_logic;
        signal ready_s : in std_logic;
        constant word  : in std_logic_vector(35 downto 0);
        constant sop   : in std_logic := '0';
        constant eop   : in std_logic := '0'
    ) is
    begin
        data_s  <= word;
        sop_s   <= sop;
        eop_s   <= eop;
        valid_s <= '1';
        loop
            wait until rising_edge(clk);
            exit when ready_s = '1';
        end loop;
        valid_s <= '0';
        sop_s   <= '0';
        eop_s   <= '0';
        wait until rising_edge(clk);
    end procedure drive_post_word;

begin

    clk <= not clk after CLK_PERIOD_CONST / 2;

    dut : entity work.histogram_ingress_bridge
        generic map (
            DEFAULT_SELECT_POST    => 1,
            ENABLE_POST_FORWARD    => 0,
            FILTER_POST_HIT_WORDS  => 1
        )
        port map (
            avs_csr_address            => csr_address,
            avs_csr_read               => csr_read,
            avs_csr_write              => csr_write,
            avs_csr_writedata          => csr_writedata,
            avs_csr_readdata           => csr_readdata,
            avs_csr_waitrequest        => csr_waitrequest,
            asi_pre_data               => pre_data,
            asi_pre_valid              => pre_valid,
            asi_pre_ready              => pre_ready,
            asi_pre_startofpacket      => pre_sop,
            asi_pre_endofpacket        => pre_eop,
            asi_pre_channel            => pre_channel,
            asi_pre_empty              => pre_empty,
            asi_pre_error              => pre_error,
            aso_pre_data               => pre_out_data,
            aso_pre_valid              => pre_out_valid,
            aso_pre_ready              => pre_out_ready,
            aso_pre_startofpacket      => pre_out_sop,
            aso_pre_endofpacket        => pre_out_eop,
            aso_pre_channel            => pre_out_channel,
            aso_pre_empty              => pre_out_empty,
            aso_pre_error              => pre_out_error,
            asi_post_data              => post_data,
            asi_post_valid             => post_valid,
            asi_post_ready             => post_ready,
            asi_post_startofpacket     => post_sop,
            asi_post_endofpacket       => post_eop,
            aso_post_data              => post_out_data,
            aso_post_valid             => post_out_valid,
            aso_post_ready             => post_out_ready,
            aso_post_startofpacket     => post_out_sop,
            aso_post_endofpacket       => post_out_eop,
            aso_hist_data              => hist_data,
            aso_hist_valid             => hist_valid,
            aso_hist_ready             => hist_ready,
            aso_hist_startofpacket     => hist_sop,
            aso_hist_endofpacket       => hist_eop,
            aso_hist_channel           => hist_channel,
            rsi_reset_reset            => rst,
            csi_clock_clk              => clk
        );

    cycle_counter : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                cycle_count <= 0;
            else
                cycle_count <= cycle_count + 1;
            end if;
        end if;
    end process cycle_counter;

    hist_mon : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                hist_post_count <= 0;
                hist_pre_count <= 0;
            elsif hist_valid = '1' and hist_ready = '1' then
                case expected_hist_source is
                    when SRC_POST =>
                        assert hist_data(38 downto 36) = "000"
                            report "post histogram data was not zero-extended"
                            severity failure;
                        assert hist_sop = '0' and hist_eop = '0'
                            report "filtered post hit stream emitted packet markers"
                            severity failure;
                        hist_post_count <= hist_post_count + 1;
                    when SRC_PRE =>
                        assert hist_sop = pre_sop and hist_eop = pre_eop
                            report "pre histogram stream did not preserve packet markers"
                            severity failure;
                        hist_pre_count <= hist_pre_count + 1;
                    when SRC_NONE =>
                        assert false
                            report "unexpected histogram beat while no source was expected"
                            severity failure;
                end case;
            end if;
        end if;
    end process hist_mon;

    stim : process
        variable status_initial_v : std_logic_vector(31 downto 0);
        variable status_after_post_v : std_logic_vector(31 downto 0);
        variable status_pending_v : std_logic_vector(31 downto 0);
        variable status_after_eor_v : std_logic_vector(31 downto 0);
        variable status_after_pre_v : std_logic_vector(31 downto 0);
        variable status_pre_to_post_pending_v : std_logic_vector(31 downto 0);
        variable line_v : line;
    begin
        file_open(events_file, REPORT_PREFIX & "_events.csv", write_mode);
        file_open(summary_file, REPORT_PREFIX & "_summary.md", write_mode);

        write(line_v, string'("cycle,event,status_hex,live_post,requested_post,pending,pre_packet_active,post_packet_active,post_filter,post_hit_region,hist_post_count,hist_pre_count"));
        writeline(events_file, line_v);

        wait for 5 * CLK_PERIOD_CONST;
        rst <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        csr_read_word(csr_address, csr_read, csr_readdata, 3, status_initial_v);
        write_status_row("initial_post_selected", status_initial_v);
        assert status_initial_v(0) = '1' and status_initial_v(1) = '1' and status_initial_v(2) = '0'
            report "bridge did not reset with post selected for reproducer setup"
            severity failure;

        expected_hist_source <= SRC_POST;
        drive_post_word(post_data, post_valid, post_sop, post_eop, post_ready, x"1000000BC", '1', '0');
        drive_post_word(post_data, post_valid, post_sop, post_eop, post_ready, x"000000000");
        drive_post_word(post_data, post_valid, post_sop, post_eop, post_ready, x"000000001");
        drive_post_word(post_data, post_valid, post_sop, post_eop, post_ready, x"000000000");
        drive_post_word(post_data, post_valid, post_sop, post_eop, post_ready, x"000000000");
        drive_post_word(post_data, post_valid, post_sop, post_eop, post_ready, x"1000002F7");
        drive_post_word(post_data, post_valid, post_sop, post_eop, post_ready, x"001234567");
        drive_post_word(post_data, post_valid, post_sop, post_eop, post_ready, x"000000222");
        drive_post_word(post_data, post_valid, post_sop, post_eop, post_ready, x"10000009C", '0', '1');
        expected_hist_source <= SRC_NONE;
        wait for 3 * CLK_PERIOD_CONST;
        assert hist_post_count = 2
            report "post-rbCAM selected path did not forward exactly two hit words"
            severity failure;
        csr_read_word(csr_address, csr_read, csr_readdata, 3, status_after_post_v);
        write_status_row("post_hits_forwarded", status_after_post_v);

        drive_pre_word(
            pre_data,
            pre_valid,
            pre_sop,
            pre_eop,
            pre_empty,
            pre_channel,
            pre_ready,
            make_pre_hit(1, 3, 1),
            x"0",
            '1',
            '0',
            '0'
        );

        csr_write_word(csr_address, csr_write, csr_writedata, 2, x"00000000");
        wait for 3 * CLK_PERIOD_CONST;
        csr_read_word(csr_address, csr_read, csr_readdata, 3, status_pending_v);
        write_status_row("post_to_pre_request_while_pre_run_active", status_pending_v);
        assert status_pending_v(0) = '1'
            report "live source unexpectedly switched away from post during active pre run packet"
            severity failure;
        assert status_pending_v(1) = '0'
            report "requested source did not update to pre"
            severity failure;
        assert status_pending_v(2) = '1'
            report "switch was not reported pending while pre run packet was active"
            severity failure;
        assert status_pending_v(8) = '1'
            report "pre_packet_active was not set by MTS-style SOP-only first hit"
            severity failure;
        assert hist_pre_count = 0
            report "pre hit reached histogram while live source was still post"
            severity failure;

        drive_pre_word(
            pre_data,
            pre_valid,
            pre_sop,
            pre_eop,
            pre_empty,
            pre_channel,
            pre_ready,
            make_pre_hit(1, 3, 16#ffff#),
            x"0",
            '0',
            '1',
            '1'
        );

        wait for 3 * CLK_PERIOD_CONST;
        csr_read_word(csr_address, csr_read, csr_readdata, 3, status_after_eor_v);
        write_status_row("after_pre_eor_marker", status_after_eor_v);
        assert status_after_eor_v(0) = '0' and status_after_eor_v(1) = '0' and status_after_eor_v(2) = '0'
            report "post-to-pre request did not apply after pre EOR marker"
            severity failure;
        assert status_after_eor_v(8) = '0'
            report "pre_packet_active did not clear on terminating empty marker"
            severity failure;

        expected_hist_source <= SRC_PRE;
        drive_pre_word(
            pre_data,
            pre_valid,
            pre_sop,
            pre_eop,
            pre_empty,
            pre_channel,
            pre_ready,
            make_pre_hit(1, 4, 2),
            x"0",
            '1',
            '0',
            '0'
        );
        expected_hist_source <= SRC_NONE;
        wait for 3 * CLK_PERIOD_CONST;
        assert hist_pre_count = 1
            report "pre-rbCAM selected path did not forward the next run hit"
            severity failure;
        csr_read_word(csr_address, csr_read, csr_readdata, 3, status_after_pre_v);
        write_status_row("pre_hits_forwarded_after_eor_switch", status_after_pre_v);

        csr_write_word(csr_address, csr_write, csr_writedata, 2, x"00000001");
        wait for 3 * CLK_PERIOD_CONST;
        csr_read_word(csr_address, csr_read, csr_readdata, 3, status_pre_to_post_pending_v);
        write_status_row("pre_to_post_request_while_pre_run_active", status_pre_to_post_pending_v);
        assert status_pre_to_post_pending_v(0) = '0'
            report "live source unexpectedly switched to post during active pre run packet"
            severity failure;
        assert status_pre_to_post_pending_v(1) = '1'
            report "requested source did not update to post"
            severity failure;
        assert status_pre_to_post_pending_v(2) = '1'
            report "post request was not reported pending while pre run packet was active"
            severity failure;
        assert status_pre_to_post_pending_v(8) = '1'
            report "pre_packet_active was not still set after the second MTS-style SOP"
            severity failure;

        write(line_v, string'("# FEB Histogram Ingress Bridge Switch Reproducer"));
        writeline(summary_file, line_v);
        write(line_v, string'(""));
        writeline(summary_file, line_v);
        write(line_v, string'("This reproduces the board-visible status pattern when software requests pre-rbCAM after an MTS-style pre run packet has started."));
        writeline(summary_file, line_v);
        write(line_v, string'(""));
        writeline(summary_file, line_v);
        write(line_v, string'("| Event | Status | live_post | requested_post | pending | pre_active | post_active | post_filter | post_hit_region | Note |"));
        writeline(summary_file, line_v);
        write(line_v, string'("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |"));
        writeline(summary_file, line_v);
        write_summary_row("Initial post selection", status_initial_v, "default post-selected setup");
        write_summary_row("Post hits forwarded", status_after_post_v, "post-rbCAM path can fill histogram");
        write_summary_row("Post-to-pre requested during pre run", status_pending_v, "live stays post, request is pre, pending remains set, pre_active is high");
        write_summary_row("After pre EOR marker", status_after_eor_v, "pending clears only once run-level EOP arrives");
        write_summary_row("Pre hit after switch", status_after_pre_v, "pre-rbCAM path fills only after the delayed switch");
        write_summary_row("Pre-to-post requested during pre run", status_pre_to_post_pending_v, "live stays pre, request is post, pending remains set, pre_active is high");
        write(line_v, string'(""));
        writeline(summary_file, line_v);
        write(line_v, string'("- `hist_post_count=2` before the source switch request."));
        writeline(summary_file, line_v);
        write(line_v, string'("- `hist_pre_count=0` while status is pending with pre_packet_active set."));
        writeline(summary_file, line_v);
        write(line_v, string'("- `hist_pre_count=1` after an explicit pre EOR marker allows the switch to apply."));
        writeline(summary_file, line_v);
        write(line_v, string'("- Requests in both directions are gated by the same pre run-level packet-active state."));
        writeline(summary_file, line_v);

        file_close(events_file);
        file_close(summary_file);

        report "tb_hist_bridge_switch_repro PASS" severity note;
        finish;
        wait;
    end process stim;

end architecture sim;
