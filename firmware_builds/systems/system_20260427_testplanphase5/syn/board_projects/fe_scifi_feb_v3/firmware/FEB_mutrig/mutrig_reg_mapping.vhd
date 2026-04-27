-- M.Mueller, May 2021

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;
use work.mudaq.all;
use work.mutrig.all;
use work.mutrig_registers.all;

entity mutrig_reg_mapping is
generic (
    N_MODULES   : positive;
    N_INPUTSRX  : positive--;
);
port (

    i_reg_add       : in  std_logic_vector(15 downto 0);
    i_reg_re        : in  std_logic;
    o_reg_rdata     : out std_logic_vector(31 downto 0);
    i_reg_we        : in  std_logic;
    i_reg_wdata     : in  std_logic_vector(31 downto 0);

    -- inputs
    i_counters      : in  slv32_array_t(10 * 2 * N_INPUTSRX - 1 downto 0);
    i_SC_mutrig     : in  work.mutrig_sc_types.t_sc_mutrig;
    i_ch_rate       : in  std_logic_vector(31 downto 0);

    -- outputs
    o_SC_mutrig     : out work.mutrig_sc_types.t_sc_mutrig;

    -- clk / reset
    i_clk_125       : in  std_logic;
    i_reset_125_n   : in  std_logic;
    i_reset_n       : in  std_logic;
    i_clk           : in  std_logic--;
);
end entity;

architecture rtl of mutrig_reg_mapping is

    -- counters / rate
    signal counters156  : slv32_array_t(10 * 2 * N_INPUTSRX - 1 downto 0);
    signal counter156   : std_logic_vector(31 downto 0);
    signal ch_rate      : std_logic_vector(31 downto 0);

    -- slow control
    signal in_sc_mutrig_v, in_sc_mutrig_156_v, out_sc_mutrig_v, out_sc_mutrig_125_v : std_logic_vector(work.mutrig_sc_types.len_sc_mutrig-1 downto 0);
    signal in_SC_mutrig, out_SC_mutrig : work.mutrig_sc_types.t_sc_mutrig;

begin

    ----------------------------------------------------------------------------
    -- sync from 125 clock to 156
    ----------------------------------------------------------------------------
    -- sync counters
    gen_counters : for i in 10 * N_INPUTSRX - 1 downto 0 generate
        e_counters : entity work.ff_sync
        generic map ( W => counters156(i)'length )
        port map (
            i_d => i_counters(i), o_q => counters156(i),
            i_reset_n => i_reset_n, i_clk => i_clk--,
        );
    end generate;

    -- sync sc mutrig in
    in_sc_mutrig_v <= work.mutrig_sc_types.sc_mutrig_to_vector(i_SC_mutrig); -- convert rec to vector
    e_in_sc_mutrig : entity work.ff_sync
    generic map ( W => in_sc_mutrig_v'length )
    port map (
        i_d => in_sc_mutrig_v, o_q => in_sc_mutrig_156_v,
        i_reset_n => i_reset_n, i_clk => i_clk--,
    );
    in_SC_mutrig <= work.mutrig_sc_types.vector_to_sc_mutrig(in_sc_mutrig_156_v); -- convert vector to rec

    -- sync channel rate
    e_ch_rate : entity work.ff_sync
    generic map ( W => ch_rate'length )
    port map (
        i_d => i_ch_rate, o_q => ch_rate,
        i_reset_n => i_reset_n, i_clk => i_clk--,
    );


    ----------------------------------------------------------------------------
    -- sync from 156 to 125 clock
    ----------------------------------------------------------------------------
    -- sync sc mutrig out
    out_sc_mutrig_v <= work.mutrig_sc_types.sc_mutrig_to_vector(out_SC_mutrig); -- convert rec to vector
    e_out_sc_mutrig : entity work.ff_sync
    generic map ( W => out_sc_mutrig_v'length )
    port map (
        i_d => out_sc_mutrig_v, o_q => out_sc_mutrig_125_v,
        i_reset_n => i_reset_125_n, i_clk => i_clk_125--,
    );
    o_SC_mutrig <= work.mutrig_sc_types.vector_to_sc_mutrig(out_sc_mutrig_125_v); -- convert vector to rec


    process(i_clk, i_reset_n)
        variable regaddr : integer;
    begin
    if ( i_reset_n /= '1' ) then
            counter156      <= (others=>'0');
            out_SC_mutrig   <= work.mutrig_sc_types.t_sc_mutrig_zero;
    elsif rising_edge(i_clk) then
            o_reg_rdata <= X"CCCCCCCC";
            regaddr := to_integer(unsigned(i_reg_add));
            out_SC_mutrig.subdet_resetdly_written <= '0';

            -- remove latches for status register since out_SC_mutrig holds only control registers
            -- TODO: maybe later we should have one record type for ctrl and one for status
            out_SC_mutrig.frame_desync <= (others => '0');
            out_SC_mutrig.receivers_ready <= (others => '0');
            out_SC_mutrig.receivers_dpa_lock <= (others => '0');
            out_SC_mutrig.rx_state <= (others => '0');
            out_SC_mutrig.debug_path <= (others => '0');
            out_SC_mutrig.receivers_pll_lock <= '0';

            -- counters
            if ( i_reg_we = '1' and regaddr = MUTRIG_CNT_ADDR_REGISTER_W ) then
                counter156 <= counters156(to_integer(unsigned(i_reg_wdata)));
            end if;
            if ( i_reg_re = '1' and regaddr = MUTRIG_CNT_VALUE_REGISTER_R ) then
                o_reg_rdata <= counter156;
            end if;

            -- channel rate
            if ( i_reg_re = '1' and regaddr = MUTRIG_CH_RATE_REGISTER_R ) then
                o_reg_rdata <= ch_rate;
            end if;

            if ( i_reg_we = '1' and regaddr = MUTRIG_CH_CTRL_REGISTER_R ) then
                out_SC_mutrig.asic_select <= i_reg_wdata(3 downto 0);
                out_SC_mutrig.ch_select <= i_reg_wdata(8 downto 4);
            end if;

            -- pll test mode
            if ( i_reg_we = '1' and regaddr = MUTRIG_CNT_CTRL_REGISTER_W ) then
                out_SC_mutrig.pll_test_mode(7 downto 0) <= i_reg_wdata(7 downto 0);
            end if;
            if ( i_reg_re = '1' and regaddr = MUTRIG_CNT_CTRL_REGISTER_W ) then
                o_reg_rdata <= (others => '0');
                o_reg_rdata(7 downto 0) <= out_SC_mutrig.pll_test_mode(7 downto 0);
            end if;

            -- rx status
            if ( i_reg_re = '1' and regaddr = MUTRIG_RX_STATUS_REGISTER_R ) then
                o_reg_rdata <= (others => '0');
                o_reg_rdata(0) <= in_SC_mutrig.receivers_pll_lock;
                o_reg_rdata(5 downto 4) <= in_SC_mutrig.frame_desync;
                o_reg_rdata(18 downto 6) <= in_SC_mutrig.receivers_dpa_lock;
                o_reg_rdata(31 downto 19) <= in_SC_mutrig.receivers_ready;
            end if;

            -- dummy data generator
            if ( i_reg_we = '1' and regaddr = MUTRIG_CTRL_DUMMY_REGISTER_W ) then
                out_SC_mutrig.datagen_enable <= i_reg_wdata(0);
                out_SC_mutrig.datagen_shortmode <= i_reg_wdata(1);
                out_SC_mutrig.datagen_count <= i_reg_wdata(11 downto 2);
            end if;
            if ( i_reg_re = '1' and regaddr = MUTRIG_CTRL_DUMMY_REGISTER_W ) then
                o_reg_rdata <= (others => '0');
                o_reg_rdata(0) <= out_SC_mutrig.datagen_enable;
                o_reg_rdata(1) <= out_SC_mutrig.datagen_shortmode;
                o_reg_rdata(11 downto 2) <= out_SC_mutrig.datagen_count;
            end if;

            -- data path control register
            if ( i_reg_we = '1' and regaddr = MUTRIG_CTRL_DP_REGISTER_W ) then
                out_SC_mutrig.disable_dec <= i_reg_wdata(31);
                out_SC_mutrig.rx_wait_for_all <= i_reg_wdata(30);
                out_SC_mutrig.rx_wait_for_all_sticky <= i_reg_wdata(29);
                out_SC_mutrig.mask <= i_reg_wdata(25 downto 13);
                out_SC_mutrig.mask_rx <= i_reg_wdata(12 downto 0);
            end if;
            if ( i_reg_re = '1' and regaddr = MUTRIG_CTRL_DP_REGISTER_W ) then
                o_reg_rdata <= (others => '0');
                o_reg_rdata(31) <= out_SC_mutrig.disable_dec;
                o_reg_rdata(30) <= out_SC_mutrig.rx_wait_for_all;
                o_reg_rdata(29) <= out_SC_mutrig.rx_wait_for_all_sticky;
                o_reg_rdata(25 downto 13) <= out_SC_mutrig.mask;
                o_reg_rdata(12 downto 0) <= out_SC_mutrig.mask_rx;
            end if;

            -- reset registers
            if ( i_reg_we = '1' and regaddr = MUTRIG_CTRL_RESET_REGISTER_W ) then
                o_reg_rdata <= (others => '0');
                out_SC_mutrig.subdet_reset <= i_reg_wdata(2 downto 0);
                out_SC_mutrig.reset_counters <= i_reg_wdata(3);
            end if;
            if ( i_reg_re = '1' and regaddr = MUTRIG_CTRL_RESET_REGISTER_W ) then
                o_reg_rdata(2 downto 0) <= out_SC_mutrig.subdet_reset;
                o_reg_rdata(3) <= out_SC_mutrig.reset_counters;
            end if;

            -- reset delay
            if ( i_reg_we = '1' and regaddr = MUTRIG_CTRL_RESETDELAY_REGISTER_W ) then
                out_SC_mutrig.subdet_resetdly <= i_reg_wdata;
                out_SC_mutrig.subdet_resetdly_written <= '1';
            end if;
            if ( i_reg_re = '1' and regaddr = MUTRIG_CTRL_RESETDELAY_REGISTER_W ) then
                o_reg_rdata <= out_SC_mutrig.subdet_resetdly;
            end if;

            -- lapse correction
            if ( i_reg_we = '1' and regaddr = MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W ) then
                out_SC_mutrig.en_lapse_counter <= i_reg_wdata(31);
                out_SC_mutrig.upper_bnd <= i_reg_wdata(29 downto 15);
                out_SC_mutrig.lower_bnd <= i_reg_wdata(14 downto 0);
            end if;
            if ( i_reg_re = '1' and regaddr = MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W ) then
                o_reg_rdata <= (others => '0');
                o_reg_rdata(31) <= out_SC_mutrig.en_lapse_counter;
                o_reg_rdata(29 downto 15) <= out_SC_mutrig.upper_bnd;
                o_reg_rdata(14 downto 0) <= out_SC_mutrig.lower_bnd;
            end if;

    end if;
    end process;

end architecture;
