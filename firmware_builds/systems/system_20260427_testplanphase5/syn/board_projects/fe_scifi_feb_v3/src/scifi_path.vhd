library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;
use work.mudaq.all;


entity scifi_path is
generic (
    N_MODULES : positive;
    N_INPUTSRX : positive := 8;
    N_ASICS : positive;
    N_LINKS : positive;
    INPUT_SIGNFLIP : std_logic_vector := (31 downto 0 => '0');
    LVDS_PLL_FREQ : real;
    LVDS_DATA_RATE : real--;
);
port (
    -- read latency - 1
    i_reg_addr      : in    std_logic_vector(15 downto 0);
    i_reg_re        : in    std_logic;
    o_reg_rdata     : out   std_logic_vector(31 downto 0);
    i_reg_we        : in    std_logic;
    i_reg_wdata     : in    std_logic_vector(31 downto 0);

    -- to detector module
    o_chip_reset    : out   std_logic_vector(N_MODULES-1 downto 0);
    o_pll_test      : out   std_logic;
    i_data          : in    std_logic_vector(N_INPUTSRX-1 downto 0) := (others => '0');
    i_scifi_lvds_los_n	: in std_logic_vector(7 downto 0);
    o_pll_reset     : out   std_logic;

    -- data out to common firmware
    o_fifo_wdata    : out   std_logic_vector(36*N_LINKS-1 downto 0);
    o_fifo_write    : out   std_logic_vector(N_LINKS-1 downto 0);
    i_common_fifos_almost_full : in std_logic_vector(N_LINKS-1 downto 0);
    o_fifo_debug_data           : out std_logic_vector(36*N_LINKS-1 downto 0);
    o_fifo_debug_wr             : out std_logic_vector(N_LINKS-1 downto 0);
    i_debug_almost_full         : in  std_logic_vector(N_LINKS-1 downto 0);

    -- simulation inputs
    i_enablesim             : in  std_logic := '0';
    i_simdata               : in  std_logic_vector(8*N_MODULES * N_ASICS-1 downto 0) := (others => '0');
    i_simdatak              : in  std_logic_vector(N_MODULES * N_ASICS-1 downto 0) := (others => '0');

    -- reset system
    i_run_state             : in  run_state_t; --run state sync to i_clk_g125
    o_run_state_all_done    : out std_logic; -- all fifos empty, all data read

    o_MON_rxrdy             : out std_logic_vector(N_MODULES*N_ASICS-1 downto 0); -- receiver ready flags for monitoring, sync to lvds_userclocks(A/B depending on LVDS placement)
    i_scifi_temp_reading    : in std_logic_vector(31 downto 0);

    -- 125 MHz
    i_clk_ref_A             : in  std_logic; -- lvds reference only
    i_clk_ref_B             : in  std_logic; -- lvds reference only

    o_fast_pll_clk          : out std_logic;

    i_reset_156_n           : in  std_logic;
    i_clk_156               : in  std_logic;
    i_reset_125_n           : in  std_logic;
    i_clk_125               : in  std_logic--;
);
end entity;

architecture arch of scifi_path is

    -- MuTrig PLL test
    signal s_testpulse : std_logic;

    -- register signal
    signal i_SC_mutrig, o_SC_mutrig : work.mutrig_sc_types.t_sc_mutrig;
    signal iram : work.util.rw_t;
    signal scifi_regs : work.util.rw_t;
    signal mt_sorter_reg :work.util.rw32_array_t(1 downto 0);

    -- counters
    signal s_counters : slv32_array_t(10 * 2 * N_INPUTSRX - 1 downto 0);
    signal s_ch_rate : std_logic_vector(31 downto 0);

    -- reset synchronizers
    signal s_datapath_rst, s_datapath_rst_n : std_logic;
    signal s_lvds_rx_rst, s_lvds_rx_rst_n : std_logic;

    -- chip reset synchronization/shift
    signal s_chip_rst : std_logic;
    signal s_chip_rst_shifted : std_logic_vector(3 downto 0);
	
	signal doNotCompileAway : std_logic_vector(3 downto 0);

begin



--------------------------------------------------------------------
--- TODO: REMOVE THIS
--- do not compile away stuff for pinout test
--------------------------------------------------------------------

--    doNotCompileAway <= i_spi_miso & i_i2c_int & scl_in & sda_in;
--    dnca: entity work.doNotCompileAwayMux
--    generic map (
--        WIDTH_g   => 4--,
--    )
--    port map (
--        i_clk               => i_clk_156,
--        i_reset_n           => i_reset_156_n,
--        i_doNotCompileAway  => doNotCompileAway,
--        o_led               => o_test_led(0)--,
--    );
--
--    o_pll_reset <= not i_reset_156_n;
--    o_spi_scl   <= not i_reset_156_n;
--    o_spi_mosi  <= not i_reset_156_n;



--    process(i_clk_156)
--    begin
--    if rising_edge(i_clk_156) then
--        --sda_ena <= '0';
--        --scl_ena <= '0';
--        if ( a ='0' and b = '0' ) then
--            a <= '1';
--            sda_out <= '0';
--            scl_out <= '0';
--            --sda_ena <= '1';
--            --scl_ena <= '1';
--        elsif ( a = '1' and b = '0' ) then
--            b <= '1';
--            sda_out <= '1';
--            scl_out <= '1';
--            --sda_ena <= '1';
--            --scl_ena <= '1';
--        else
--            a <= '0';
--            b <= '0';
--        end if;
--    end if;
--    end process;

--    process(i_clk_156, i_reset_156_n)
--    begin
--    if ( i_reset_156_n /= '1' ) then
--        miso_transition_count <= (others => '0');
--        miso_156 <= '0';
--        miso_156_last <= '0';
--    elsif rising_edge(i_clk_156) then
--        miso_156 <= i_spi_miso;
--        miso_156_last <= miso_156;
--        if ( miso_156 /= miso_156_last ) then
--            miso_transition_count <= miso_transition_count + '1';
--        end if;
--    end if;
--    end process;



--------------------------------------------------------------------
--------------------------------------------------------------------


    -- 100 kHz for PLL test
    e_test_pulse : entity work.clkdiv
    generic map ( g_N => 1250 )
    port map ( o_clk => s_testpulse, i_reset_n => i_reset_125_n, i_clk => i_clk_125 ); -- i_run_state(RUN_STATE_BITPOS_SYNC), i_clk => i_clk_125 );
    o_pll_test <= '0' when o_SC_mutrig.pll_test_mode(0) = '0' else s_testpulse;

    ---- Register mapping ----
    e_lvl1_sc_node : entity work.sc_node
      generic map (
        SLAVE1_ADDR_MATCH_g => "00--------------",
        SLAVE2_ADDR_MATCH_g => "01000000--------" ,
        SLAVE3_ADDR_MATCH_g => "01000001--------"--,
      )
      port map (
        i_master_addr  => i_reg_addr,
        i_master_re    => i_reg_re,
        o_master_rdata => o_reg_rdata,
        i_master_we    => i_reg_we,
        i_master_wdata => i_reg_wdata,

        o_slave0_addr  => scifi_regs.addr(15 downto 0),
        o_slave0_re    => scifi_regs.re,
        i_slave0_rdata => scifi_regs.rdata,
        o_slave0_we    => scifi_regs.we,
        o_slave0_wdata => scifi_regs.wdata,

        o_slave1_addr  => iram.addr(15 downto 0),
        o_slave1_re    => open,
        i_slave1_rdata => iram.rdata,
        o_slave1_we    => iram.we,
        o_slave1_wdata => iram.wdata,

        o_slave2_addr  => mt_sorter_reg(0).addr(15 downto 0),
        o_slave2_re    => mt_sorter_reg(0).re,
        i_slave2_rdata => mt_sorter_reg(0).rdata,
        o_slave2_we    => mt_sorter_reg(0).we,
        o_slave2_wdata => mt_sorter_reg(0).wdata,

        o_slave3_addr  => mt_sorter_reg(1).addr(15 downto 0),
        o_slave3_re    => mt_sorter_reg(1).re,
        i_slave3_rdata => mt_sorter_reg(1).rdata,
        o_slave3_we    => mt_sorter_reg(1).we,
        o_slave3_wdata => mt_sorter_reg(1).wdata,
        
        i_reset_n       => i_reset_156_n,
        i_clk           => i_clk_156--,
    );

    e_scifi_reg_mapping : entity work.mutrig_reg_mapping
    generic map (
        N_MODULES   => N_MODULES,
        N_INPUTSRX  => N_INPUTSRX--,
    )
    port map (

        i_reg_add    => scifi_regs.addr(15 downto 0),
        i_reg_re     => scifi_regs.re,
        o_reg_rdata  => scifi_regs.rdata,
        i_reg_we     => scifi_regs.we,
        i_reg_wdata  => scifi_regs.wdata,

        -- inputs
        i_counters   => s_counters,
        i_SC_mutrig  => i_SC_mutrig,
        i_ch_rate    => s_ch_rate,

        -- outputs
        o_SC_mutrig  => o_SC_mutrig,

        i_clk_125     => i_clk_125,
        i_reset_125_n => i_reset_125_n,
        i_reset_n     => i_reset_156_n,
        i_clk         => i_clk_156--,
    );

    e_iram : entity work.ram_1r1w
    generic map (
        g_DATA_WIDTH => 32,
        g_ADDR_WIDTH => 14--,
    )
    port map (
        i_raddr => iram.addr(13 downto 0),
        o_rdata => iram.rdata,
        i_rclk  => i_clk_156,

        i_waddr => iram.addr(13 downto 0),
        i_wdata => iram.wdata,
        i_we    => iram.we,
        i_wclk  => i_clk_156--,
    );

    ---- Reset ----
    s_chip_rst      <= (not i_reset_125_n) or o_SC_mutrig.subdet_reset(0) or i_run_state(RUN_STATE_BITPOS_SYNC);
    s_datapath_rst  <= (not i_reset_125_n) or o_SC_mutrig.subdet_reset(1) or i_run_state(RUN_STATE_BITPOS_PREP);
    s_lvds_rx_rst   <= (not i_reset_125_n) or o_SC_mutrig.subdet_reset(2) or i_run_state(RUN_STATE_BITPOS_RESET);

    rst_sync_dprst : entity work.reset_sync
    port map ( i_reset_n => not s_datapath_rst, o_reset_n => s_datapath_rst_n, i_clk => i_clk_125);

    rst_sync_lvdsrst : entity work.reset_sync
    port map ( i_reset_n => not s_lvds_rx_rst, o_reset_n => s_lvds_rx_rst_n, i_clk => i_clk_125);

    --u_resetshift: entity work.clockalign_block
    --generic map ( CLKDIV => 2 )
    --port map (
    --    i_clk_config    => i_clk_156,
    --    i_rst           => not i_reset_156_n,
    --    i_pll_clk       => i_clk_125,
    --    i_pll_arst      => not i_reset_125_n,
    --    i_flag          => o_SC_mutrig.s_subdet_resetdly_reg_written,
    --    i_data          => o_SC_mutrig.s_subdet_resetdly_reg,
    --    i_sig           => s_chip_rst,
    --    o_sig           => s_chip_rst_shifted,
    --    o_pll_clk(0)    => o_fast_pll_clk
    --);
    o_chip_reset <= (others => s_chip_rst);--; (others =>s_chip_rst_shifted(0)); --s_chip_rst_shifted(N_MODULES-1 downto 0);TODO: fix this !!

    ---- Scifi Datapath ----
    e_mutrig_datapath : entity work.scifi_datapath
    generic map (
        N_INPUTSRX      => N_INPUTSRX,
        LVDS_PLL_FREQ   => LVDS_PLL_FREQ,
        LVDS_DATA_RATE  => LVDS_DATA_RATE,
        INPUT_SIGNFLIP  => INPUT_SIGNFLIP,
        C_ASICNO_PREFIX => x"CBA9876543210"--,
    )
    port map (

        -- RX part
        i_rst_rx                    => not s_lvds_rx_rst_n,
        i_data                      => i_data,
        i_refclk_125_A              => i_clk_ref_A,
        i_refclk_125_B              => i_clk_ref_B,
		i_scifi_lvds_los_n	    	=> i_scifi_lvds_los_n,

        -- interface to asic fifos
        o_fifo_data                 => o_fifo_wdata,
        o_fifo_wr                   => o_fifo_write,
        i_common_fifos_almost_full  => i_common_fifos_almost_full,
        o_fifo_debug_data           => o_fifo_debug_data,
        o_fifo_debug_wr             => o_fifo_debug_wr,
        i_debug_almost_full         => i_debug_almost_full,

        -- slow control / monitoring
        i_SC_mutrig                 => o_SC_mutrig,
        o_SC_mutrig                 => i_SC_mutrig,
        o_counters                  => s_counters,
        o_ch_rate                   => s_ch_rate,

        -- slow control node for the sorter
        mt_sorter_regs                   => mt_sorter_reg,

        i_simdata                   => i_simdata,
        i_simdatak                  => i_simdatak,

        -- run control
        i_RC_may_generate           => i_run_state(RUN_STATE_BITPOS_RUNNING),
        o_RC_all_done               => o_run_state_all_done,
        i_run_state_125             => i_run_state,

        -- reset / clk
        i_reset_156_n               => i_reset_156_n,
        i_clk_156                   => i_clk_156,
        i_ts_rst                    => i_run_state(RUN_STATE_BITPOS_SYNC),
        i_reset_125_n               => i_reset_125_n,
        i_clk_125                   => i_clk_125--,

    );

    o_MON_rxrdy <= i_SC_mutrig.receivers_ready(N_MODULES*N_ASICS-1 downto 0);
end architecture;
