-- File name: pingpong_sram.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Mar 20, 2026
-- Revision: 1.1
--		Date: May 1, 2026
--		Change: Keep deferred host reads on the frozen bank in ping-pong mode.
-- =========
-- Description:	[Dual-bank histogram storage with interval freeze/readout]
--
--			Two dual-port RAM banks hold histogram bin counts. In ping-pong mode
--			the active write bank flips on each interval boundary, while the host
--			reads the frozen bank from the previous interval. The newly active
--			bank is cleared before new updates are accepted so the update path can
--			use a deterministic RAM read/modify/write pipeline.
--

-- ================ synthsizer configuration ===================
-- altera vhdl_input_version vhdl_2008
-- =============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.histogram_statistics_v2_pkg.all;

entity pingpong_sram is
    generic (
        N_BINS         : natural := 256;
        COUNT_WIDTH    : natural := HS_COUNT_W_CONST;
        UPDATE_WIDTH   : natural := HS_KICK_W_CONST
    );
    port (
        i_clk                : in  std_logic;
        i_rst                : in  std_logic;
        i_clear              : in  std_logic;
        i_enable_pingpong    : in  std_logic;
        i_interval_clocks    : in  unsigned(31 downto 0);
        i_upd_valid          : in  std_logic;
        i_upd_bin            : in  unsigned(clog2(N_BINS) - 1 downto 0);
        i_upd_count          : in  unsigned(UPDATE_WIDTH - 1 downto 0);
        o_upd_ready          : out std_logic;
        i_hist_read          : in  std_logic;
        i_hist_address       : in  unsigned(clog2(N_BINS) - 1 downto 0);
        i_hist_burstcount    : in  unsigned(clog2(N_BINS) downto 0);
        o_hist_readdata      : out std_logic_vector(31 downto 0);
        o_hist_readdatavalid : out std_logic;
        o_active_bank        : out std_logic;
        o_flushing           : out std_logic;
        o_flush_addr         : out unsigned(clog2(N_BINS) - 1 downto 0);
        o_interval_pulse     : out std_logic
    );
end entity pingpong_sram;

architecture rtl of pingpong_sram is

    constant ADDR_WIDTH_CONST : natural := clog2(N_BINS);
    constant RAM_DEPTH_CONST  : natural := 2 ** ADDR_WIDTH_CONST;

    subtype count_t     is unsigned(COUNT_WIDTH - 1 downto 0);
    subtype count_slv_t is std_logic_vector(COUNT_WIDTH - 1 downto 0);
    subtype addr_t      is unsigned(ADDR_WIDTH_CONST - 1 downto 0);

    signal bank_a_addr_a : natural range 0 to RAM_DEPTH_CONST - 1 := 0;
    signal bank_a_addr_b : natural range 0 to RAM_DEPTH_CONST - 1 := 0;
    signal bank_b_addr_a : natural range 0 to RAM_DEPTH_CONST - 1 := 0;
    signal bank_b_addr_b : natural range 0 to RAM_DEPTH_CONST - 1 := 0;
    signal bank_a_data_a : count_slv_t := (others => '0');
    signal bank_a_data_b : count_slv_t := (others => '0');
    signal bank_b_data_a : count_slv_t := (others => '0');
    signal bank_b_data_b : count_slv_t := (others => '0');
    signal bank_a_we_a   : std_logic := '0';
    signal bank_a_we_b   : std_logic := '0';
    signal bank_b_we_a   : std_logic := '0';
    signal bank_b_we_b   : std_logic := '0';
    signal bank_a_q_a    : count_slv_t;
    signal bank_a_q_b    : count_slv_t;
    signal bank_b_q_a    : count_slv_t;
    signal bank_b_q_b    : count_slv_t;

    signal active_bank        : std_logic := '0';
    signal clear_active       : std_logic := '1';
    signal clear_bank         : std_logic := '0';
    signal clear_both         : std_logic := '1';
    signal clear_addr         : addr_t := (others => '0');
    signal timer_count        : unsigned(31 downto 0) := (others => '0');
    signal interval_pulse     : std_logic := '0';

    signal upd_issue_valid    : std_logic := '0';
    signal upd_issue_bank     : std_logic := '0';
    signal upd_issue_bin      : addr_t := (others => '0');
    signal upd_issue_count    : count_t := (others => '0');
    signal upd_read_valid     : std_logic := '0';
    signal upd_read_bank      : std_logic := '0';
    signal upd_read_bin       : addr_t := (others => '0');
    signal upd_read_count     : count_t := (others => '0');
    signal upd_add_valid      : std_logic := '0';
    signal upd_add_bank       : std_logic := '0';
    signal upd_add_bin        : addr_t := (others => '0');
    signal upd_add_data       : count_t := (others => '0');
    signal upd_add_count      : count_t := (others => '0');
    signal upd_sum_valid      : std_logic := '0';
    signal upd_sum_bank       : std_logic := '0';
    signal upd_sum_bin        : addr_t := (others => '0');
    signal upd_sum_value      : count_t := (others => '0');
    signal upd_write_valid    : std_logic := '0';
    signal upd_write_bank     : std_logic := '0';
    signal upd_write_bin      : addr_t := (others => '0');
    signal upd_write_value    : count_t := (others => '0');
    signal upd_read_data      : count_t;
    signal upd_ready_int      : std_logic := '0';

    signal burst_active       : std_logic := '0';
    signal burst_addr         : addr_t := (others => '0');
    signal burst_remaining    : unsigned(ADDR_WIDTH_CONST downto 0) := (others => '0');
    signal read_bank_latched  : std_logic := '0';
    signal hist_issue_valid   : std_logic := '0';
    signal hist_issue_bank    : std_logic := '0';
    signal hist_issue_addr    : addr_t := (others => '0');
    signal hist_read_valid    : std_logic := '0';
    signal hist_read_bank     : std_logic := '0';
    signal hist_read_pending  : std_logic := '0';
    signal hist_pending_addr  : addr_t := (others => '0');
    signal hist_pending_count : unsigned(ADDR_WIDTH_CONST downto 0) := (others => '0');
    signal hist_readdata      : std_logic_vector(31 downto 0) := (others => '0');
    signal hist_readdatavalid : std_logic := '0';

begin

    o_upd_ready          <= upd_ready_int;
    o_hist_readdata      <= hist_readdata;
    o_hist_readdatavalid <= hist_readdatavalid;
    o_active_bank        <= active_bank;
    o_flushing           <= clear_active;
    o_flush_addr         <= clear_addr;
    o_interval_pulse     <= interval_pulse;

    upd_ready_int <= '1' when (clear_active = '0')
                           and not ((i_enable_pingpong = '0') and (burst_active = '1'))
                     else '0';
    upd_read_data   <= unsigned(bank_a_q_a) when upd_read_bank = '0' else unsigned(bank_b_q_a);

    bank_a_we_a   <= '0';
    bank_b_we_a   <= '0';
    bank_a_data_a <= (others => '0');
    bank_b_data_a <= (others => '0');

    bank_a_addr_a <= to_integer(hist_issue_addr) when (hist_issue_valid = '1') and (hist_issue_bank = '0')
                else to_integer(upd_issue_bin)   when (upd_issue_valid = '1') and (upd_issue_bank = '0')
                else 0;

    bank_b_addr_a <= to_integer(hist_issue_addr) when (hist_issue_valid = '1') and (hist_issue_bank = '1')
                else to_integer(upd_issue_bin)   when (upd_issue_valid = '1') and (upd_issue_bank = '1')
                else 0;

    bank_a_we_b   <= '1' when ((clear_active = '1') and (clear_bank = '0'))
                              or ((upd_write_valid = '1') and (upd_write_bank = '0'))
                     else '0';
    bank_b_we_b   <= '1' when ((clear_active = '1') and (clear_bank = '1'))
                              or ((upd_write_valid = '1') and (upd_write_bank = '1'))
                     else '0';

    bank_a_addr_b <= to_integer(clear_addr)     when (clear_active = '1') and (clear_bank = '0')
                else to_integer(upd_write_bin)  when (upd_write_valid = '1') and (upd_write_bank = '0')
                else 0;

    bank_b_addr_b <= to_integer(clear_addr)     when (clear_active = '1') and (clear_bank = '1')
                else to_integer(upd_write_bin)  when (upd_write_valid = '1') and (upd_write_bank = '1')
                else 0;

    bank_a_data_b <= (others => '0')              when (clear_active = '1') and (clear_bank = '0')
                else std_logic_vector(upd_write_value);

    bank_b_data_b <= (others => '0')              when (clear_active = '1') and (clear_bank = '1')
                else std_logic_vector(upd_write_value);

    bank_a_ram : entity work.true_dual_port_ram_single_clock
        generic map (
            DATA_WIDTH => COUNT_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH_CONST
        )
        port map (
            clk    => i_clk,
            addr_a => bank_a_addr_a,
            addr_b => bank_a_addr_b,
            data_a => bank_a_data_a,
            data_b => bank_a_data_b,
            we_a   => bank_a_we_a,
            we_b   => bank_a_we_b,
            q_a    => bank_a_q_a,
            q_b    => bank_a_q_b
        );

    bank_b_ram : entity work.true_dual_port_ram_single_clock
        generic map (
            DATA_WIDTH => COUNT_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH_CONST
        )
        port map (
            clk    => i_clk,
            addr_a => bank_b_addr_a,
            addr_b => bank_b_addr_b,
            data_a => bank_b_data_a,
            data_b => bank_b_data_b,
            we_a   => bank_b_we_a,
            we_b   => bank_b_we_b,
            q_a    => bank_b_q_a,
            q_b    => bank_b_q_b
        );

    ram_ctrl : process (i_clk)
        variable ram_v_switch_fire   : boolean;
        variable ram_v_next_bank     : std_logic;
        variable ram_v_hist_issue    : std_logic;
        variable ram_v_hist_bank     : std_logic;
        variable ram_v_hist_addr     : addr_t;
        variable ram_v_burst_count   : unsigned(burst_remaining'range);
        variable ram_v_read_data     : count_t;
        variable ram_v_accept_update : boolean;
        variable ram_v_clear_index   : natural;
        variable ram_v_upd_forward   : count_t;
    begin
        if rising_edge(i_clk) then
            hist_readdatavalid <= '0';
            interval_pulse     <= '0';

            if i_rst = '1' then
                active_bank       <= '0';
                clear_active      <= '1';
                clear_bank        <= '0';
                clear_both        <= '1';
                clear_addr        <= (others => '0');
                timer_count       <= (others => '0');
                interval_pulse    <= '0';
                upd_issue_valid   <= '0';
                upd_issue_bank    <= '0';
                upd_issue_bin     <= (others => '0');
                upd_issue_count   <= (others => '0');
                upd_read_valid    <= '0';
                upd_read_bank     <= '0';
                upd_read_bin      <= (others => '0');
                upd_read_count    <= (others => '0');
                upd_add_valid     <= '0';
                upd_add_bank      <= '0';
                upd_add_bin       <= (others => '0');
                upd_add_data      <= (others => '0');
                upd_add_count     <= (others => '0');
                upd_sum_valid     <= '0';
                upd_sum_bank      <= '0';
                upd_sum_bin       <= (others => '0');
                upd_sum_value     <= (others => '0');
                upd_write_valid   <= '0';
                upd_write_bank    <= '0';
                upd_write_bin     <= (others => '0');
                upd_write_value   <= (others => '0');
                burst_active      <= '0';
                burst_addr        <= (others => '0');
                burst_remaining   <= (others => '0');
                read_bank_latched <= '0';
                hist_issue_valid  <= '0';
                hist_issue_bank   <= '0';
                hist_issue_addr   <= (others => '0');
                hist_read_valid   <= '0';
                hist_read_bank    <= '0';
                hist_read_pending <= '0';
                hist_pending_addr <= (others => '0');
                hist_pending_count<= (others => '0');
                hist_readdata     <= (others => '0');
            elsif i_clear = '1' then
                active_bank       <= '0';
                clear_active      <= '1';
                clear_bank        <= '0';
                clear_both        <= '1';
                clear_addr        <= (others => '0');
                timer_count       <= (others => '0');
                interval_pulse    <= '0';
                upd_issue_valid   <= '0';
                upd_issue_bank    <= '0';
                upd_issue_bin     <= (others => '0');
                upd_issue_count   <= (others => '0');
                upd_read_valid    <= '0';
                upd_read_bank     <= '0';
                upd_read_bin      <= (others => '0');
                upd_read_count    <= (others => '0');
                upd_add_valid     <= '0';
                upd_add_bank      <= '0';
                upd_add_bin       <= (others => '0');
                upd_add_data      <= (others => '0');
                upd_add_count     <= (others => '0');
                upd_sum_valid     <= '0';
                upd_sum_bank      <= '0';
                upd_sum_bin       <= (others => '0');
                upd_sum_value     <= (others => '0');
                upd_write_valid   <= '0';
                upd_write_bank    <= '0';
                upd_write_bin     <= (others => '0');
                upd_write_value   <= (others => '0');
                burst_active      <= '0';
                burst_addr        <= (others => '0');
                burst_remaining   <= (others => '0');
                read_bank_latched <= '0';
                hist_issue_valid  <= '0';
                hist_issue_bank   <= '0';
                hist_issue_addr   <= (others => '0');
                hist_read_valid   <= '0';
                hist_read_bank    <= '0';
                hist_read_pending <= '0';
                hist_pending_addr <= (others => '0');
                hist_pending_count<= (others => '0');
                hist_readdata     <= (others => '0');
            else
                ram_v_next_bank     := active_bank;
                ram_v_switch_fire   := false;
                ram_v_hist_issue    := '0';
                ram_v_hist_bank     := read_bank_latched;
                ram_v_hist_addr     := (others => '0');
                ram_v_accept_update := false;

                if hist_read_valid = '1' then
                    if hist_read_bank = '0' then
                        ram_v_read_data := unsigned(bank_a_q_a);
                    else
                        ram_v_read_data := unsigned(bank_b_q_a);
                    end if;
                    hist_readdata      <= std_logic_vector(resize(ram_v_read_data, 32));
                    hist_readdatavalid <= '1';
                end if;

                if (i_enable_pingpong = '1') and (i_interval_clocks /= 0) then
                    if timer_count = (i_interval_clocks - 1) then
                        ram_v_switch_fire := true;
                        ram_v_next_bank   := not active_bank;
                        active_bank       <= not active_bank;
                        timer_count       <= (others => '0');
                        interval_pulse    <= '1';
                        clear_active      <= '1';
                        clear_bank        <= not active_bank;
                        clear_both        <= '0';
                        clear_addr        <= (others => '0');
                    else
                        timer_count <= timer_count + 1;
                    end if;
                else
                    timer_count <= (others => '0');
                end if;

                if clear_active = '1' then
                    ram_v_clear_index := to_integer(clear_addr);
                    if ram_v_clear_index = N_BINS - 1 then
                        if clear_both = '1' and clear_bank = '0' then
                            clear_bank <= '1';
                            clear_addr <= (others => '0');
                        else
                            clear_active <= '0';
                            clear_both   <= '0';
                            clear_addr   <= (others => '0');
                        end if;
                    else
                        clear_addr <= to_unsigned(ram_v_clear_index + 1, clear_addr'length);
                    end if;
                end if;

                if (i_hist_read = '1') and (burst_active = '0') then
                    ram_v_burst_count := resize(i_hist_burstcount, burst_remaining'length);
                    if ram_v_burst_count = 0 then
                        ram_v_burst_count := to_unsigned(1, ram_v_burst_count'length);
                    end if;

                    if ((i_enable_pingpong = '1')
                        and (upd_issue_valid = '0')
                        and (upd_read_valid = '0')
                        and (upd_add_valid = '0')
                        and (upd_sum_valid = '0')
                        and (upd_write_valid = '0'))
                       or ((i_enable_pingpong = '0')
                        and (upd_issue_valid = '0')
                        and (upd_read_valid = '0')
                        and (upd_add_valid = '0')
                        and (upd_sum_valid = '0')
                        and (upd_write_valid = '0')
                        and (i_upd_valid = '0')) then
                        burst_active    <= '1';
                        burst_addr      <= i_hist_address;
                        burst_remaining <= ram_v_burst_count;
                        if i_enable_pingpong = '1' then
                            read_bank_latched <= not ram_v_next_bank;
                        else
                            read_bank_latched <= ram_v_next_bank;
                        end if;
                    else
                        hist_read_pending <= '1';
                        hist_pending_addr <= i_hist_address;
                        hist_pending_count<= ram_v_burst_count;
                    end if;
                elsif (hist_read_pending = '1') and (burst_active = '0')
                   and (upd_issue_valid = '0')
                   and (upd_read_valid = '0')
                   and (upd_add_valid = '0')
                   and (upd_sum_valid = '0')
                   and (upd_write_valid = '0')
                   and (i_upd_valid = '0') then
                    burst_active      <= '1';
                    burst_addr        <= hist_pending_addr;
                    burst_remaining   <= hist_pending_count;
                    if i_enable_pingpong = '1' then
                        read_bank_latched <= not ram_v_next_bank;
                    else
                        read_bank_latched <= ram_v_next_bank;
                    end if;
                    hist_read_pending <= '0';
                elsif burst_active = '1' then
                    ram_v_hist_issue := '1';
                    ram_v_hist_bank  := read_bank_latched;
                    ram_v_hist_addr  := burst_addr;

                    if burst_remaining = 1 then
                        burst_active    <= '0';
                        burst_remaining <= (others => '0');
                    else
                        burst_addr      <= burst_addr + 1;
                        burst_remaining <= burst_remaining - 1;
                    end if;
                end if;

                if upd_ready_int = '1' and i_upd_valid = '1' and not ram_v_switch_fire then
                    ram_v_accept_update := true;
                end if;

                hist_issue_valid <= ram_v_hist_issue;
                hist_issue_bank  <= ram_v_hist_bank;
                hist_issue_addr  <= ram_v_hist_addr;
                hist_read_valid  <= hist_issue_valid;
                hist_read_bank   <= hist_issue_bank;
                upd_read_valid   <= upd_issue_valid;
                upd_read_bank    <= upd_issue_bank;
                upd_read_bin     <= upd_issue_bin;
                upd_read_count   <= upd_issue_count;
                if upd_read_valid = '1' then
                    ram_v_upd_forward := upd_read_data;

                    if (upd_add_valid = '1') and (upd_add_bank = upd_read_bank) and (upd_add_bin = upd_read_bin) then
                        ram_v_upd_forward := sat_add(upd_add_data, upd_add_count);
                    elsif (upd_sum_valid = '1') and (upd_sum_bank = upd_read_bank) and (upd_sum_bin = upd_read_bin) then
                        ram_v_upd_forward := upd_sum_value;
                    elsif (upd_write_valid = '1') and (upd_write_bank = upd_read_bank) and (upd_write_bin = upd_read_bin) then
                        ram_v_upd_forward := upd_write_value;
                    end if;

                    upd_add_valid  <= '1';
                    upd_add_bank   <= upd_read_bank;
                    upd_add_bin    <= upd_read_bin;
                    upd_add_data   <= ram_v_upd_forward;
                    upd_add_count  <= upd_read_count;
                else
                    upd_add_valid  <= '0';
                    upd_add_bank   <= '0';
                    upd_add_bin    <= (others => '0');
                    upd_add_data   <= (others => '0');
                    upd_add_count  <= (others => '0');
                end if;
                if upd_add_valid = '1' then
                    upd_sum_valid  <= '1';
                    upd_sum_bank   <= upd_add_bank;
                    upd_sum_bin    <= upd_add_bin;
                    upd_sum_value  <= sat_add(upd_add_data, upd_add_count);
                else
                    upd_sum_valid  <= '0';
                    upd_sum_bank   <= '0';
                    upd_sum_bin    <= (others => '0');
                    upd_sum_value  <= (others => '0');
                end if;
                upd_write_valid  <= upd_sum_valid;
                upd_write_bank   <= upd_sum_bank;
                upd_write_bin    <= upd_sum_bin;
                upd_write_value  <= upd_sum_value;

                if ram_v_accept_update then
                    upd_issue_valid <= '1';
                    upd_issue_bank  <= ram_v_next_bank;
                    upd_issue_bin   <= i_upd_bin;
                    upd_issue_count <= resize(i_upd_count, COUNT_WIDTH);
                else
                    upd_issue_valid <= '0';
                end if;
            end if;
        end if;
    end process ram_ctrl;

end architecture rtl;
