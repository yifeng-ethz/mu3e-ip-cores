-- Build-local dual-port histogram topology simulation.
--
-- This testbench exercises the generated topology contract directly:
-- two histogram_ingress_bridge instances feed histogram_statistics_v2
-- ports 0 and 1, matching the Qsys wiring for the two MTS ASIC banks.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

library modelsim_lib;
use modelsim_lib.util.all;

entity tb_hist_dualport is
    generic (
        TEST_NAME            : string  := "smoke";
        REPORT_PREFIX        : string  := "tb_int/REPORT/hist_dualport";
        TEST_HITS_TOTAL      : natural := 1000;
        TEST_INTERVAL_CYCLES : natural := 2000;
        TEST_INTERVAL_COUNT  : natural := 1;
        HIT_PERIOD_CYCLES    : natural := 2;
        LIVE_BIN_READBACK    : natural := 1
    );
end entity tb_hist_dualport;

architecture sim of tb_hist_dualport is
    constant CLK_PERIOD : time := 8 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal bridge0_csr_addr      : std_logic_vector(1 downto 0) := (others => '0');
    signal bridge0_csr_read      : std_logic := '0';
    signal bridge0_csr_write     : std_logic := '0';
    signal bridge0_csr_writedata : std_logic_vector(31 downto 0) := (others => '0');
    signal bridge0_csr_readdata  : std_logic_vector(31 downto 0);
    signal bridge0_csr_wait      : std_logic;
    signal bridge1_csr_addr      : std_logic_vector(1 downto 0) := (others => '0');
    signal bridge1_csr_read      : std_logic := '0';
    signal bridge1_csr_write     : std_logic := '0';
    signal bridge1_csr_writedata : std_logic_vector(31 downto 0) := (others => '0');
    signal bridge1_csr_readdata  : std_logic_vector(31 downto 0);
    signal bridge1_csr_wait      : std_logic;

    signal pre0_data    : std_logic_vector(38 downto 0) := (others => '0');
    signal pre0_valid   : std_logic := '0';
    signal pre0_ready   : std_logic;
    signal pre0_sop     : std_logic := '0';
    signal pre0_eop     : std_logic := '0';
    signal pre0_channel : std_logic_vector(3 downto 0) := (others => '0');
    signal pre1_data    : std_logic_vector(38 downto 0) := (others => '0');
    signal pre1_valid   : std_logic := '0';
    signal pre1_ready   : std_logic;
    signal pre1_sop     : std_logic := '0';
    signal pre1_eop     : std_logic := '0';
    signal pre1_channel : std_logic_vector(3 downto 0) := (others => '0');

    signal pre0_out_data    : std_logic_vector(38 downto 0);
    signal pre0_out_valid   : std_logic;
    signal pre0_out_channel : std_logic_vector(3 downto 0);
    signal pre0_out_sop     : std_logic;
    signal pre0_out_eop     : std_logic;
    signal pre0_out_empty   : std_logic;
    signal pre0_out_error   : std_logic;
    signal pre1_out_data    : std_logic_vector(38 downto 0);
    signal pre1_out_valid   : std_logic;
    signal pre1_out_channel : std_logic_vector(3 downto 0);
    signal pre1_out_sop     : std_logic;
    signal pre1_out_eop     : std_logic;
    signal pre1_out_empty   : std_logic;
    signal pre1_out_error   : std_logic;

    signal hist0_data    : std_logic_vector(38 downto 0);
    signal hist0_valid   : std_logic;
    signal hist0_ready   : std_logic;
    signal hist0_sop     : std_logic;
    signal hist0_eop     : std_logic;
    signal hist0_channel : std_logic_vector(3 downto 0);
    signal hist1_data    : std_logic_vector(38 downto 0);
    signal hist1_valid   : std_logic;
    signal hist1_ready   : std_logic;
    signal hist1_sop     : std_logic;
    signal hist1_eop     : std_logic;
    signal hist1_channel : std_logic_vector(3 downto 0);

    signal post_ready_unused0 : std_logic;
    signal post_ready_unused1 : std_logic;

    signal hist_bin_readdata      : std_logic_vector(31 downto 0);
    signal hist_bin_read          : std_logic := '0';
    signal hist_bin_address       : std_logic_vector(7 downto 0) := (others => '0');
    signal hist_bin_waitrequest   : std_logic;
    signal hist_bin_write         : std_logic := '0';
    signal hist_bin_writedata     : std_logic_vector(31 downto 0) := (others => '0');
    signal hist_bin_burstcount    : std_logic_vector(8 downto 0) := (0 => '1', others => '0');
    signal hist_bin_readdatavalid : std_logic;
    signal hist_bin_writeresp     : std_logic;
    signal hist_bin_response      : std_logic_vector(1 downto 0);

    signal csr_readdata    : std_logic_vector(31 downto 0);
    signal csr_read        : std_logic := '0';
    signal csr_address     : std_logic_vector(4 downto 0) := (others => '0');
    signal csr_waitrequest : std_logic;
    signal csr_write       : std_logic := '0';
    signal csr_writedata   : std_logic_vector(31 downto 0) := (others => '0');

    signal interval_reset : std_logic := '0';

    signal run_start   : std_logic := '0';
    signal drive_done  : std_logic := '0';
    signal reader_done : std_logic := '0';

    signal driver_total_hits : natural := 0;
    signal driver_port0_hits : natural := 0;
    signal driver_port1_hits : natural := 0;
    signal monitor_port0_valid : natural := 0;
    signal monitor_port1_valid : natural := 0;
    signal monitor_port0_hs : natural := 0;
    signal monitor_port1_hs : natural := 0;
    signal monitor_write_count : natural := 0;
    signal monitor_max_total_hits : natural := 0;
    signal monitor_interval_pulses : natural := 0;
    signal reader_interval_count : natural := 0;
    signal reader_interval_sum_total : natural := 0;

    signal spy_write_valid  : std_logic := '0';
    signal spy_write_bank   : std_logic := '0';
    signal spy_write_bin    : std_logic_vector(7 downto 0) := (others => '0');
    signal spy_write_value  : std_logic_vector(31 downto 0) := (others => '0');
    signal spy_active_bank  : std_logic := '0';
    signal spy_interval     : std_logic := '0';
    signal spy_total_hits   : std_logic_vector(31 downto 0) := (others => '0');

    function hit_word(key : natural) return std_logic_vector is
        variable word_v : std_logic_vector(38 downto 0) := (others => '0');
    begin
        word_v(29 downto 17) := std_logic_vector(to_unsigned(key, 13));
        return word_v;
    end function hit_word;

    procedure wait_cycles(signal clk_s : in std_logic; cycles : natural) is
    begin
        for idx in 1 to cycles loop
            wait until rising_edge(clk_s);
        end loop;
    end procedure wait_cycles;

    procedure wait_interval(signal clk_s : in std_logic; signal pulse_s : in std_logic) is
    begin
        loop
            wait until rising_edge(clk_s);
            exit when pulse_s = '1';
        end loop;
    end procedure wait_interval;

    procedure csr_write_word(
        signal clk_s       : in std_logic;
        signal addr_s      : out std_logic_vector(4 downto 0);
        signal write_s     : out std_logic;
        signal writedata_s : out std_logic_vector(31 downto 0);
        constant addr_c    : natural;
        constant data_c    : std_logic_vector(31 downto 0)
    ) is
    begin
        wait until rising_edge(clk_s);
        addr_s      <= std_logic_vector(to_unsigned(addr_c, addr_s'length));
        writedata_s <= data_c;
        write_s     <= '1';
        wait until rising_edge(clk_s);
        write_s     <= '0';
        addr_s      <= (others => '0');
        writedata_s <= (others => '0');
    end procedure csr_write_word;

begin
    clk <= not clk after CLK_PERIOD / 2;

    spy_setup : process
    begin
        init_signal_spy("/tb_hist_dualport/dut_hist/pingpong_inst/upd_write_valid",
                        "/tb_hist_dualport/spy_write_valid", 0);
        init_signal_spy("/tb_hist_dualport/dut_hist/pingpong_inst/upd_write_bank",
                        "/tb_hist_dualport/spy_write_bank", 0);
        init_signal_spy("/tb_hist_dualport/dut_hist/pingpong_inst/upd_write_bin",
                        "/tb_hist_dualport/spy_write_bin", 0);
        init_signal_spy("/tb_hist_dualport/dut_hist/pingpong_inst/upd_write_value",
                        "/tb_hist_dualport/spy_write_value", 0);
        init_signal_spy("/tb_hist_dualport/dut_hist/pingpong_inst/active_bank",
                        "/tb_hist_dualport/spy_active_bank", 0);
        init_signal_spy("/tb_hist_dualport/dut_hist/pingpong_inst/interval_pulse",
                        "/tb_hist_dualport/spy_interval", 0);
        init_signal_spy("/tb_hist_dualport/dut_hist/csr_total_hits",
                        "/tb_hist_dualport/spy_total_hits", 0);
        wait;
    end process spy_setup;

    bridge0 : entity work.histogram_ingress_bridge
        generic map (
            BUILD                 => 512,
            VERSION_DATE          => 20260512,
            INSTANCE_ID           => 0,
            DEFAULT_SELECT_POST   => 0,
            ENABLE_POST_FORWARD   => 0,
            FILTER_POST_HIT_WORDS => 1
        )
        port map (
            avs_csr_address => bridge0_csr_addr,
            avs_csr_read => bridge0_csr_read,
            avs_csr_write => bridge0_csr_write,
            avs_csr_writedata => bridge0_csr_writedata,
            avs_csr_readdata => bridge0_csr_readdata,
            avs_csr_waitrequest => bridge0_csr_wait,
            asi_pre_data => pre0_data,
            asi_pre_valid => pre0_valid,
            asi_pre_ready => pre0_ready,
            asi_pre_startofpacket => pre0_sop,
            asi_pre_endofpacket => pre0_eop,
            asi_pre_channel => pre0_channel,
            asi_pre_empty => '0',
            asi_pre_error => '0',
            aso_pre_data => pre0_out_data,
            aso_pre_valid => pre0_out_valid,
            aso_pre_ready => '1',
            aso_pre_startofpacket => pre0_out_sop,
            aso_pre_endofpacket => pre0_out_eop,
            aso_pre_channel => pre0_out_channel,
            aso_pre_empty => pre0_out_empty,
            aso_pre_error => pre0_out_error,
            asi_post_data => (others => '0'),
            asi_post_valid => '0',
            asi_post_ready => post_ready_unused0,
            asi_post_startofpacket => '0',
            asi_post_endofpacket => '0',
            aso_post_data => open,
            aso_post_valid => open,
            aso_post_ready => '1',
            aso_post_startofpacket => open,
            aso_post_endofpacket => open,
            aso_hist_data => hist0_data,
            aso_hist_valid => hist0_valid,
            aso_hist_ready => hist0_ready,
            aso_hist_startofpacket => hist0_sop,
            aso_hist_endofpacket => hist0_eop,
            aso_hist_channel => hist0_channel,
            rsi_reset_reset => rst,
            csi_clock_clk => clk
        );

    bridge1 : entity work.histogram_ingress_bridge
        generic map (
            BUILD                 => 512,
            VERSION_DATE          => 20260512,
            INSTANCE_ID           => 1,
            DEFAULT_SELECT_POST   => 0,
            ENABLE_POST_FORWARD   => 0,
            FILTER_POST_HIT_WORDS => 1
        )
        port map (
            avs_csr_address => bridge1_csr_addr,
            avs_csr_read => bridge1_csr_read,
            avs_csr_write => bridge1_csr_write,
            avs_csr_writedata => bridge1_csr_writedata,
            avs_csr_readdata => bridge1_csr_readdata,
            avs_csr_waitrequest => bridge1_csr_wait,
            asi_pre_data => pre1_data,
            asi_pre_valid => pre1_valid,
            asi_pre_ready => pre1_ready,
            asi_pre_startofpacket => pre1_sop,
            asi_pre_endofpacket => pre1_eop,
            asi_pre_channel => pre1_channel,
            asi_pre_empty => '0',
            asi_pre_error => '0',
            aso_pre_data => pre1_out_data,
            aso_pre_valid => pre1_out_valid,
            aso_pre_ready => '1',
            aso_pre_startofpacket => pre1_out_sop,
            aso_pre_endofpacket => pre1_out_eop,
            aso_pre_channel => pre1_out_channel,
            aso_pre_empty => pre1_out_empty,
            aso_pre_error => pre1_out_error,
            asi_post_data => (others => '0'),
            asi_post_valid => '0',
            asi_post_ready => post_ready_unused1,
            asi_post_startofpacket => '0',
            asi_post_endofpacket => '0',
            aso_post_data => open,
            aso_post_valid => open,
            aso_post_ready => '1',
            aso_post_startofpacket => open,
            aso_post_endofpacket => open,
            aso_hist_data => hist1_data,
            aso_hist_valid => hist1_valid,
            aso_hist_ready => hist1_ready,
            aso_hist_startofpacket => hist1_sop,
            aso_hist_endofpacket => hist1_eop,
            aso_hist_channel => hist1_channel,
            rsi_reset_reset => rst,
            csi_clock_clk => clk
        );

    dut_hist : entity work.histogram_statistics_v2
        generic map (
            N_PORTS             => 2,
            FIFO_ADDR_WIDTH     => 8,
            CHANNELS_PER_PORT   => 32,
            COAL_QUEUE_DEPTH    => 256,
            DEF_INTERVAL_CLOCKS => TEST_INTERVAL_CYCLES,
            BUILD               => 512,
            VERSION_DATE        => 20260512,
            SNOOP_EN            => true,
            ENABLE_PACKET       => true
        )
        port map (
            avs_hist_bin_readdata => hist_bin_readdata,
            avs_hist_bin_read => hist_bin_read,
            avs_hist_bin_address => hist_bin_address,
            avs_hist_bin_waitrequest => hist_bin_waitrequest,
            avs_hist_bin_write => hist_bin_write,
            avs_hist_bin_writedata => hist_bin_writedata,
            avs_hist_bin_burstcount => hist_bin_burstcount,
            avs_hist_bin_readdatavalid => hist_bin_readdatavalid,
            avs_hist_bin_writeresponsevalid => hist_bin_writeresp,
            avs_hist_bin_response => hist_bin_response,
            avs_csr_readdata => csr_readdata,
            avs_csr_read => csr_read,
            avs_csr_address => csr_address,
            avs_csr_waitrequest => csr_waitrequest,
            avs_csr_write => csr_write,
            avs_csr_writedata => csr_writedata,
            asi_hist_fill_in_ready => hist0_ready,
            asi_hist_fill_in_valid => hist0_valid,
            asi_hist_fill_in_data => hist0_data,
            asi_hist_fill_in_startofpacket => hist0_sop,
            asi_hist_fill_in_endofpacket => hist0_eop,
            asi_hist_fill_in_channel => hist0_channel,
            asi_fill_in_1_ready => hist1_ready,
            asi_fill_in_1_valid => hist1_valid,
            asi_fill_in_1_data => hist1_data,
            asi_fill_in_1_startofpacket => hist1_sop,
            asi_fill_in_1_endofpacket => hist1_eop,
            asi_fill_in_1_channel => hist1_channel,
            asi_fill_in_2_ready => open,
            asi_fill_in_2_valid => '0',
            asi_fill_in_2_data => (others => '0'),
            asi_fill_in_2_startofpacket => '0',
            asi_fill_in_2_endofpacket => '0',
            asi_fill_in_2_channel => (others => '0'),
            asi_fill_in_3_ready => open,
            asi_fill_in_3_valid => '0',
            asi_fill_in_3_data => (others => '0'),
            asi_fill_in_3_startofpacket => '0',
            asi_fill_in_3_endofpacket => '0',
            asi_fill_in_3_channel => (others => '0'),
            asi_fill_in_4_ready => open,
            asi_fill_in_4_valid => '0',
            asi_fill_in_4_data => (others => '0'),
            asi_fill_in_4_startofpacket => '0',
            asi_fill_in_4_endofpacket => '0',
            asi_fill_in_4_channel => (others => '0'),
            asi_fill_in_5_ready => open,
            asi_fill_in_5_valid => '0',
            asi_fill_in_5_data => (others => '0'),
            asi_fill_in_5_startofpacket => '0',
            asi_fill_in_5_endofpacket => '0',
            asi_fill_in_5_channel => (others => '0'),
            asi_fill_in_6_ready => open,
            asi_fill_in_6_valid => '0',
            asi_fill_in_6_data => (others => '0'),
            asi_fill_in_6_startofpacket => '0',
            asi_fill_in_6_endofpacket => '0',
            asi_fill_in_6_channel => (others => '0'),
            asi_fill_in_7_ready => open,
            asi_fill_in_7_valid => '0',
            asi_fill_in_7_data => (others => '0'),
            asi_fill_in_7_startofpacket => '0',
            asi_fill_in_7_endofpacket => '0',
            asi_fill_in_7_channel => (others => '0'),
            aso_hist_fill_out_ready => '1',
            aso_hist_fill_out_valid => open,
            aso_hist_fill_out_data => open,
            aso_hist_fill_out_startofpacket => open,
            aso_hist_fill_out_endofpacket => open,
            aso_hist_fill_out_channel => open,
            asi_ctrl_data => (others => '0'),
            asi_ctrl_valid => '0',
            asi_debug_1_valid => '0',
            asi_debug_1_data => (others => '0'),
            asi_debug_2_valid => '0',
            asi_debug_2_data => (others => '0'),
            asi_debug_3_valid => '0',
            asi_debug_3_data => (others => '0'),
            asi_debug_4_valid => '0',
            asi_debug_4_data => (others => '0'),
            asi_debug_5_valid => '0',
            asi_debug_5_data => (others => '0'),
            asi_debug_6_valid => '0',
            asi_debug_6_data => (others => '0'),
            i_interval_reset => interval_reset,
            i_rst => rst,
            i_clk => clk
        );

    driver : process
        variable remaining_v : natural;
        variable total_v : natural := 0;
        variable port0_v : natural := 0;
        variable port1_v : natural := 0;
    begin
        wait until run_start = '1';
        remaining_v := TEST_HITS_TOTAL;
        total_v := 0;
        port0_v := 0;
        port1_v := 0;
        pre0_data <= hit_word(0);
        pre1_data <= hit_word(0);
        pre0_channel <= x"0";
        pre1_channel <= x"0";

        while remaining_v > 0 loop
            wait until rising_edge(clk);
            while not ((pre0_ready = '1') and ((remaining_v = 1) or (pre1_ready = '1'))) loop
                wait until rising_edge(clk);
            end loop;

            pre0_valid <= '1';
            pre0_sop   <= '1';
            pre0_eop   <= '1';
            if remaining_v > 1 then
                pre1_valid <= '1';
                pre1_sop   <= '1';
                pre1_eop   <= '1';
            else
                pre1_valid <= '0';
                pre1_sop   <= '0';
                pre1_eop   <= '0';
            end if;

            wait until rising_edge(clk);
            if pre0_ready = '1' then
                total_v := total_v + 1;
                port0_v := port0_v + 1;
                remaining_v := remaining_v - 1;
            end if;
            if (pre1_valid = '1') and (pre1_ready = '1') then
                total_v := total_v + 1;
                port1_v := port1_v + 1;
                remaining_v := remaining_v - 1;
            end if;
            driver_total_hits <= total_v;
            driver_port0_hits <= port0_v;
            driver_port1_hits <= port1_v;
            pre0_valid <= '0';
            pre0_sop   <= '0';
            pre0_eop   <= '0';
            pre1_valid <= '0';
            pre1_sop   <= '0';
            pre1_eop   <= '0';

            if HIT_PERIOD_CYCLES > 1 then
                wait_cycles(clk, HIT_PERIOD_CYCLES - 1);
            end if;
        end loop;

        drive_done <= '1';
        wait;
    end process driver;

    monitor : process
        file event_f : text open write_mode is REPORT_PREFIX & "_events.csv";
        variable line_v : line;
        variable cycle_v : natural := 0;
        variable max_total_v : natural := 0;
        variable write_count_v : natural := 0;
        variable port0_valid_v : natural := 0;
        variable port1_valid_v : natural := 0;
        variable port0_hs_v : natural := 0;
        variable port1_hs_v : natural := 0;
        variable interval_v : natural := 0;
        variable total_v : natural := 0;
    begin
        write(line_v, string'("cycle,event,port,valid,ready,data,bin,bank,value,csr_total"));
        writeline(event_f, line_v);
        loop
            wait until rising_edge(clk);
            cycle_v := cycle_v + 1;

            if rst = '0' then
                total_v := to_integer(unsigned(spy_total_hits));
                if total_v > max_total_v then
                    max_total_v := total_v;
                    monitor_max_total_hits <= max_total_v;
                end if;

                if spy_interval = '1' then
                    interval_v := interval_v + 1;
                    monitor_interval_pulses <= interval_v;
                    write(line_v, cycle_v);
                    write(line_v, string'(",interval,-,1,1,0x0,0,"));
                    write(line_v, spy_active_bank);
                    write(line_v, string'(",0x0,"));
                    write(line_v, total_v);
                    writeline(event_f, line_v);
                end if;

                if hist0_valid = '1' then
                    port0_valid_v := port0_valid_v + 1;
                    monitor_port0_valid <= port0_valid_v;
                    if hist0_ready = '1' then
                        port0_hs_v := port0_hs_v + 1;
                        monitor_port0_hs <= port0_hs_v;
                    end if;
                    write(line_v, cycle_v);
                    write(line_v, string'(",hist_fill_in,0,"));
                    write(line_v, hist0_valid);
                    write(line_v, string'(","));
                    write(line_v, hist0_ready);
                    write(line_v, string'(",0x"));
                    write(line_v, to_hstring(hist0_data));
                    write(line_v, string'(",-,-,-,"));
                    write(line_v, total_v);
                    writeline(event_f, line_v);
                end if;

                if hist1_valid = '1' then
                    port1_valid_v := port1_valid_v + 1;
                    monitor_port1_valid <= port1_valid_v;
                    if hist1_ready = '1' then
                        port1_hs_v := port1_hs_v + 1;
                        monitor_port1_hs <= port1_hs_v;
                    end if;
                    write(line_v, cycle_v);
                    write(line_v, string'(",fill_in_1,1,"));
                    write(line_v, hist1_valid);
                    write(line_v, string'(","));
                    write(line_v, hist1_ready);
                    write(line_v, string'(",0x"));
                    write(line_v, to_hstring(hist1_data));
                    write(line_v, string'(",-,-,-,"));
                    write(line_v, total_v);
                    writeline(event_f, line_v);
                end if;

                if spy_write_valid = '1' then
                    write_count_v := write_count_v + 1;
                    monitor_write_count <= write_count_v;
                    write(line_v, cycle_v);
                    write(line_v, string'(",hist_bin_write,-,1,1,0x0,"));
                    write(line_v, to_integer(unsigned(spy_write_bin)));
                    write(line_v, string'(","));
                    write(line_v, spy_write_bank);
                    write(line_v, string'(",0x"));
                    write(line_v, to_hstring(spy_write_value));
                    write(line_v, string'(","));
                    write(line_v, total_v);
                    writeline(event_f, line_v);
                end if;
            end if;
        end loop;
    end process monitor;

    interval_reader : process
        file interval_f : text open write_mode is REPORT_PREFIX & "_interval_bins.csv";
        variable line_v : line;
        variable interval_idx_v : natural := 0;
        variable interval_sum_v : natural := 0;
        variable total_sum_v : natural := 0;
        variable word_v : natural := 0;
    begin
        write(line_v, string'("interval,bin,count,active_bank_after_boundary"));
        writeline(interval_f, line_v);
        wait until run_start = '1';

        for interval_idx in 1 to TEST_INTERVAL_COUNT loop
            wait_interval(clk, spy_interval);
            if LIVE_BIN_READBACK = 0 then
                reader_interval_count <= interval_idx;
                next;
            end if;

            wait_cycles(clk, 20);
            interval_idx_v := interval_idx;
            interval_sum_v := 0;

            for bin_idx in 0 to 255 loop
                wait until rising_edge(clk);
                hist_bin_address <= std_logic_vector(to_unsigned(bin_idx, hist_bin_address'length));
                hist_bin_burstcount <= (0 => '1', others => '0');
                hist_bin_read <= '1';
                wait until rising_edge(clk);
                hist_bin_read <= '0';

                while hist_bin_readdatavalid /= '1' loop
                    wait until rising_edge(clk);
                end loop;
                word_v := to_integer(unsigned(hist_bin_readdata));
                interval_sum_v := interval_sum_v + word_v;
                write(line_v, interval_idx_v);
                write(line_v, string'(","));
                write(line_v, bin_idx);
                write(line_v, string'(","));
                write(line_v, word_v);
                write(line_v, string'(","));
                write(line_v, spy_active_bank);
                writeline(interval_f, line_v);
            end loop;

            total_sum_v := total_sum_v + interval_sum_v;
            reader_interval_count <= interval_idx_v;
            reader_interval_sum_total <= total_sum_v;
        end loop;

        reader_done <= '1';
        wait;
    end process interval_reader;

    sequencer : process
        file summary_f : text open write_mode is REPORT_PREFIX & "_summary.csv";
        variable line_v : line;
        variable pass_v : boolean;
    begin
        rst <= '1';
        wait_cycles(clk, 20);
        rst <= '0';
        wait_cycles(clk, 600);

        csr_write_word(clk, csr_address, csr_write, csr_writedata, 10,
                       std_logic_vector(to_unsigned(TEST_INTERVAL_CYCLES, 32)));
        csr_write_word(clk, csr_address, csr_write, csr_writedata, 2, x"00000101");
        wait_cycles(clk, 16);

        interval_reset <= '1';
        wait until rising_edge(clk);
        interval_reset <= '0';
        wait_cycles(clk, 600);

        -- Align the directed stimulus to a real ping-pong boundary. The first
        -- empty interval is deliberately discarded; readers start on run_start.
        wait_interval(clk, spy_interval);
        run_start <= '1';

        wait until drive_done = '1';
        if LIVE_BIN_READBACK /= 0 then
            wait until reader_done = '1';
        else
            -- In trace-derived mode, the event monitor owns interval evidence.
            -- Wait for the next boundary after the driver drains so the final
            -- frozen bank is present in the trace, then let the reporter
            -- reconstruct all 256 bins from the M10K write probes.
            wait_interval(clk, spy_interval);
        end if;
        wait_cycles(clk, 2000);

        pass_v := (driver_total_hits = TEST_HITS_TOTAL)
                  and (monitor_port0_hs > 0)
                  and (monitor_port1_hs > 0)
                  and (monitor_write_count > 0);
        if LIVE_BIN_READBACK /= 0 then
            pass_v := pass_v
                      and (reader_interval_count = TEST_INTERVAL_COUNT)
                      and (reader_interval_sum_total >= TEST_HITS_TOTAL - 8)
                      and (reader_interval_sum_total <= TEST_HITS_TOTAL + 8);
        end if;

        write(line_v, string'("key,value"));
        writeline(summary_f, line_v);
        write(line_v, string'("test_name,"));
        write(line_v, TEST_NAME);
        writeline(summary_f, line_v);
        write(line_v, string'("expected_hits,"));
        write(line_v, TEST_HITS_TOTAL);
        writeline(summary_f, line_v);
        write(line_v, string'("driver_total_hits,"));
        write(line_v, driver_total_hits);
        writeline(summary_f, line_v);
        write(line_v, string'("driver_port0_hits,"));
        write(line_v, driver_port0_hits);
        writeline(summary_f, line_v);
        write(line_v, string'("driver_port1_hits,"));
        write(line_v, driver_port1_hits);
        writeline(summary_f, line_v);
        write(line_v, string'("hist_fill_in_valid_cycles,"));
        write(line_v, monitor_port0_valid);
        writeline(summary_f, line_v);
        write(line_v, string'("fill_in_1_valid_cycles,"));
        write(line_v, monitor_port1_valid);
        writeline(summary_f, line_v);
        write(line_v, string'("hist_fill_in_handshakes,"));
        write(line_v, monitor_port0_hs);
        writeline(summary_f, line_v);
        write(line_v, string'("fill_in_1_handshakes,"));
        write(line_v, monitor_port1_hs);
        writeline(summary_f, line_v);
        write(line_v, string'("hist_bin_write_pulses,"));
        write(line_v, monitor_write_count);
        writeline(summary_f, line_v);
        write(line_v, string'("max_csr_total_hits,"));
        write(line_v, monitor_max_total_hits);
        writeline(summary_f, line_v);
        write(line_v, string'("interval_pulses_seen,"));
        write(line_v, monitor_interval_pulses);
        writeline(summary_f, line_v);
        write(line_v, string'("intervals_read,"));
        write(line_v, reader_interval_count);
        writeline(summary_f, line_v);
        write(line_v, string'("interval_bin_sum_total,"));
        write(line_v, reader_interval_sum_total);
        writeline(summary_f, line_v);
        write(line_v, string'("pass,"));
        if pass_v then
            write(line_v, string'("1"));
        else
            write(line_v, string'("0"));
        end if;
        writeline(summary_f, line_v);

        if pass_v then
            report "TB_PASS " & TEST_NAME severity note;
        else
            report "TB_FAIL " & TEST_NAME severity failure;
        end if;
        finish;
    end process sequencer;

end architecture sim;
