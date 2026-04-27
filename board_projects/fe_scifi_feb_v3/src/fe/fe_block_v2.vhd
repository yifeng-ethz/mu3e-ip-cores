--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

use work.feb_sc_registers.all;
use work.mudaq.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity fe_block_v2 is
generic (
    feb_mapping : integer_vector(3 downto 0) := (3,2,1,0);
    PHASE_WIDTH_g : positive := 16;
    NIOS_CLK_MHZ_g : real;
    N_LINKS : positive := 1;
    SC_READ_DELAY_g : positive := 7--;
);
port (	
	o_ffly_rx_data		: out std_logic_vector(31 downto 0);
	o_ffly_rx_datak		: out std_logic_vector(3 downto 0);
    i_fpga_id       : in    std_logic_vector(7 downto 0);
    -- frontend board type
    -- - 111010 : mupix
    -- - 111000 : mutrig
    -- - 000111 and 000000 : reserved (DO NOT USE)
    i_fpga_type     : in    std_logic_vector(5 downto 0);

    -- i2c firefly interface
--    io_i2c_ffly_scl     : inout std_logic;
--    io_i2c_ffly_sda     : inout std_logic;
--    o_i2c_ffly_ModSel_n : out   std_logic_vector(1 downto 0);
--    o_ffly_Rst_n        : out   std_logic_vector(1 downto 0);
--    i_ffly_Int_n        : in    std_logic_vector(1 downto 0);
--    i_ffly_ModPrs_n     : in    std_logic_vector(1 downto 0);

    -- si chip
    i_spi_si_miso       : in    std_logic_vector(1 downto 0) := (others => '0');
    o_spi_si_mosi       : out   std_logic_vector(1 downto 0);
    o_spi_si_sclk       : out   std_logic_vector(1 downto 0);
    o_spi_si_ss_n       : out   std_logic_vector(1 downto 0);

    o_si45_oe_n         : out   std_logic_vector(1 downto 0) := (others => '0');
    i_si45_intr_n       : in    std_logic_vector(1 downto 0) := (others => '1');
    i_si45_lol_n        : in    std_logic_vector(1 downto 0) := (others => '0');
    o_si45_rst_n        : out   std_logic_vector(1 downto 0);
    o_si45_fdec         : out   std_logic_vector(1 downto 0) := (others => '0');
    o_si45_finc         : out   std_logic_vector(1 downto 0) := (others => '0');
    i_si_gpio_out       : in    std_logic_vector(15 downto 0) := (others => '0');
    o_si_status_in      : out   std_logic_vector(7 downto 0);

    -- spi interface to asics
    i_spi_miso          : in    std_logic;
    o_spi_mosi          : out   std_logic;
    o_spi_sclk          : out   std_logic;
    o_spi_ss_n          : out   std_logic_vector(15 downto 0);
    -- i2c interface to detector modules
    i_i2c_scl           : in    std_logic := '1';
    o_i2c_scl_oe        : out   std_logic;
    i_i2c_sda           : in    std_logic := '1';
    o_i2c_sda_oe        : out   std_logic;

    -- Fireflies
    o_ffly1_tx          : out   std_logic_vector(3 downto 0);
    o_ffly2_tx          : out   std_logic_vector(3 downto 0);
    i_ffly1_rx          : in    std_logic;
    i_ffly2_rx          : in    std_logic_vector(2 downto 0);

    i_ffly1_lvds_rx     : in    std_logic;
    i_ffly2_lvds_rx     : in    std_logic;
    i_legacy_firefly_mon_address       : in  std_logic_vector(7 downto 0)  := (others => '0');
    i_legacy_firefly_mon_read          : in  std_logic                     := '0';
    i_legacy_firefly_mon_write         : in  std_logic                     := '0';
    i_legacy_firefly_mon_writedata     : in  std_logic_vector(31 downto 0) := (others => '0');
    o_legacy_firefly_mon_waitrequest   : out std_logic;
    o_legacy_firefly_mon_readdata      : out std_logic_vector(31 downto 0);
    o_legacy_firefly_mon_readdatavalid : out std_logic;
    o_legacy_firefly_mon_response      : out std_logic_vector(1 downto 0);
	
	i_resetlink_8bclock_rxclk	: in std_logic;
	i_resetlink_8bvalid_rxclk	: in std_logic;
	i_resetlink_8bdata_rxclk	: in std_logic_vector(8 downto 0);
	i_resetlink_8bdata_sysclk	: in std_logic_vector(8 downto 0);
    
    uplink_data          : in std_logic_vector(255 downto 0); -- 8 links, (0-3) is for ffly1 (4-7) is for ffly2. Use only link 0 and 1.
    uplink_datak         : in std_logic_vector(31 downto 0); -- 8 links, byte is k

    -- run control flags from detector-block
    i_can_terminate           : in std_logic:='0';
    i_ack_run_prep_permission : in std_logic:='1';

    --main fiber data fifo
    i_fifo_write        : in    std_logic_vector(N_LINKS-1 downto 0);
    i_fifo_wdata        : in    std_logic_vector(N_LINKS*36-1 downto 0);

    i_data_bypass       : in    std_logic_vector(31 downto 0) := x"000000BC";
    i_data_bypass_we    : in    std_logic := '0';

    o_fifos_almost_full : out   std_logic_vector(N_LINKS-1 downto 0);

    -- slow control fifo
    o_scfifo_write      : out   std_logic;
    o_scfifo_wdata      : out   std_logic_vector(35 downto 0) := (others => '-');

    -- MSCB interface
    i_mscb_data         : in    std_logic;
    o_mscb_data         : out   std_logic;
    o_mscb_oe           : out   std_logic;

    -- MAX10 IF
    o_max10_spi_sclk    : out   std_logic;
    io_max10_spi_mosi   : inout std_logic;
    io_max10_spi_miso   : inout std_logic;
    io_max10_spi_D1     : inout std_logic := 'Z';
    io_max10_spi_D2     : inout std_logic := 'Z';
    io_max10_spi_D3     : inout std_logic := 'Z';
    o_max10_spi_csn     : out   std_logic := '1';

    -- slow control registers
--    o_subdet_reg_addr   : out   std_logic_vector(15 downto 0);
--    o_subdet_reg_re     : out   std_logic;
--    i_subdet_reg_rdata  : in    std_logic_vector(31 downto 0) := X"CCCCCCCC";
--    o_subdet_reg_we     : out   std_logic;
--    o_subdet_reg_wdata  : out   std_logic_vector(31 downto 0);

    -- reset system
    o_run_state_125 : out   work.mudaq.run_state_t;
    o_run_state_156 : out   work.mudaq.run_state_t;

    -- nios clock (async)
    i_nios_clk      : in    std_logic;
    o_nios_clk_mon  : out   std_logic;
    -- 156.25 MHz (data)
    i_clk_156       : in    std_logic;
    o_clk_156_mon   : out   std_logic;
    -- 125 MHz (global clock)
    i_clk_125       : in    std_logic;
    o_clk_125_mon   : out   std_logic;
	-- 125 MHz (lvds pll refclk)
	i_clk_lvds_refclk	: in std_logic;

    i_areset_n      : in    std_logic;

    i_shutdown_max  : in    std_logic := '0';
    o_shutdown      : out   std_logic := '0';
    i_testout       : in    std_logic_vector(31 downto 0) :=(others =>'0');
    i_testin        : in    std_logic--;
);
end entity;

architecture arch of fe_block_v2 is

    -- former ports, now internal signals
    signal o_subdet_reg_addr   :    std_logic_vector(15 downto 0);
    signal o_subdet_reg_re     :    std_logic;
    signal i_subdet_reg_rdata  :    std_logic_vector(31 downto 0) := X"CCCCCCCC";
    signal o_subdet_reg_we     :    std_logic;
    signal o_subdet_reg_wdata  :    std_logic_vector(31 downto 0);

    signal nios_reset_n             : std_logic;
    signal reset_156_n              : std_logic;
    signal reset_125_n              : std_logic;
    signal reset_125_RRX_n          : std_logic;
    signal shutdown                 : std_logic := '0';
    signal shutdown_internal        : std_logic := '0';

    signal nios_irq                 : std_logic_vector(3 downto 0) := (others => '0');

    signal av_sc                    : work.util.avalon_t;

    signal sc_fifo_write            : std_logic;
    signal sc_fifo_wdata            : std_logic_vector(35 downto 0);

    signal sc_ram, sc_reg           : work.util.rw_t;
    signal fe_reg                   : work.util.rw_t;
    signal firefly_reg              : work.util.rw_t;

    signal reg_cmdlen               : std_logic_vector(31 downto 0);
    signal reg_offset               : std_logic_vector(31 downto 0);

    signal linktest_data            : std_logic_vector(31 downto 0);
    signal linktest_datak           : std_logic_vector(3 downto 0);
    signal linktest_granted         : std_logic_vector(N_LINKS-1 downto 0);

    signal av_mscb                  : work.util.avalon_t;

    signal reg_reset_bypass         : std_logic_vector(15 downto 0);
    signal reg_reset_bypass_payload : std_logic_vector(31 downto 0);

    signal run_state_125            : run_state_t;
    signal run_state_156            : run_state_t;
    signal run_state_156_resetsys   : run_state_t;

    signal terminated               : std_logic;
    signal reset_phase              : std_logic_vector(PHASE_WIDTH_g - 1 downto 0);

    signal run_number               : std_logic_vector(31 downto 0);
    signal merger_rate_count        : std_logic_vector(31 downto 0);

    signal ffly_rx_data             : std_logic_vector(127 downto 0);
    signal ffly_rx_datak            : std_logic_vector(15 downto 0);
    signal ffly_rx_data_ffly        : std_logic_vector(127 downto 0);
    signal ffly_rx_datak_ffly       : std_logic_vector(15 downto 0);

    signal fpga_id_reg              : std_logic_vector(15 downto 0);

    signal ffly_tx_data             : std_logic_vector(127 downto 0) :=
                                          X"000000" & work.util.K28_5
                                        & X"000000" & work.util.K28_5
                                        & X"000000" & work.util.K28_5
                                        & X"000000" & work.util.K28_5;
    signal ffly_tx_datak            : std_logic_vector(15 downto 0) :=
                                          "0001"
                                        & "0001"
                                        & "0001"
                                        & "0001";

    signal reset_link_rx            : std_logic_vector(7 downto 0);
    signal reset_link_rx_clk        : std_logic;
    signal reset_link_ready         : std_logic;

    signal arriaV_temperature       : std_logic_vector(7 downto 0);
    signal arriaV_temperature_clr   : std_logic;
    signal arriaV_temperature_ce    : std_logic;
    signal arriaV_temperature_tsdcaldone : std_logic;
    signal arriaV_temperature_temp  : std_logic_vector(7 downto 0);
    type temp_state_t               is (convert, clear);
    signal temp_state               :  temp_state_t;

    signal ffly_pwr                 : std_logic_vector(127 downto 0); -- RX optical power in mW
    signal ffly_temp                : std_logic_vector(15 downto 0);  -- temperature in °C
    signal ffly_alarm               : std_logic_vector(63 downto 0);  -- latched alarm bits
    signal ffly_vcc                 : std_logic_vector(31 downto 0);  -- operating voltagein units of 100 uV
    signal legacy_firefly_reg_rdata : std_logic_vector(31 downto 0) := (others => '0');
    signal legacy_firefly_mon_read_d : std_logic := '0';

    -- Max 10 SPI
    signal adc_reg                  : slv32_array_t(4 downto 0);
    signal max10_version            : reg32;
    signal max10_status             : reg32;

    signal programming_status       : reg32;
    signal programming_ctrl         : reg32;
    signal programming_data         : reg32;
    signal programming_data_ena     : std_logic;
    signal programming_addr         : reg32;
    signal programming_addr_ena     : std_logic;
    signal programming_addr_ena_reg : std_logic;

    signal nios_reboot_156          : std_logic;
    signal nios_reboot_156_prev     : std_logic;
    signal nios_reboot_50_delay     : std_logic_vector(5 downto 0);
    signal nios_reboot_50           : std_logic;

    signal run_start_denial_reason  : std_logic_vector(31 downto 0) := (others => '0');
	
	signal ram_sub_det_data,ram_sub_det_q				: std_logic_vector(31 downto 0);
	signal ram_sub_det_rdaddress,ram_sub_det_wraddress 	: std_logic_vector(15 downto 0);
	signal ram_sub_det_wren								: std_logic;
	
	signal issp_pulser_reg				: std_logic_vector(31 downto 0);
	

	
	component alt_issp_pulser is
		port (
			source     : out std_logic_vector(31 downto 0);        -- source
			source_clk : in  std_logic                     := 'X'  -- clk
		);
	end component alt_issp_pulser;
	
	component ram_sub_det
	PORT
	(
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		wraddress		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
	);
	end component;

	
begin

    -- The legacy MAX10 sidecar in fe_block_v2 is not used in the SciFi top. Keep
    -- the register-visible mirrors benign until this deprecated path is removed.
    adc_reg           <= (others => (others => '0'));
    max10_version     <= (others => '0');
    max10_status      <= (others => '0');
    programming_status<= (others => '0');
    o_max10_spi_csn   <= '1';
    o_max10_spi_sclk  <= '0';

    -- Preserve the historical hitsorter bypass only when it is explicitly
    -- enabled. Otherwise, do not overwrite the physical Firefly RX lane that
    -- carries the SciFi slow-control downlink.
    ffly_rx_data(95 downto 0)      <= ffly_rx_data_ffly(95 downto 0);
    ffly_rx_datak(11 downto 0)     <= ffly_rx_datak_ffly(11 downto 0);
    ffly_rx_data(127 downto 96)    <= i_data_bypass when i_data_bypass_we = '1' else ffly_rx_data_ffly(127 downto 96);
    ffly_rx_datak(15 downto 12)    <= "0000" when i_data_bypass_we = '1' else ffly_rx_datak_ffly(15 downto 12);

    shutdown <= shutdown_internal or i_shutdown_max;
    o_shutdown <= shutdown;
    o_si45_rst_n <= i_si_gpio_out(5 downto 4) when shutdown = '0' else (others => '0');
    o_spi_si_mosi <= (others => i_si_gpio_out(0));
    o_spi_si_sclk <= (others => i_si_gpio_out(1));
    o_spi_si_ss_n <= i_si_gpio_out(3 downto 2);
    o_si_status_in(1 downto 0) <= i_si45_intr_n;
    o_si_status_in(3 downto 2) <= i_si45_lol_n;
    o_si_status_in(5 downto 4) <= i_spi_si_miso;
    o_si_status_in(7 downto 6) <= (others => '0');
    o_i2c_scl_oe <= '0';
    o_i2c_sda_oe <= '0';
    o_spi_mosi <= '0';
    o_spi_sclk <= '0';
    o_spi_ss_n <= (others => '1');
    o_legacy_firefly_mon_waitrequest <= '0';
    o_legacy_firefly_mon_readdata <= legacy_firefly_reg_rdata;
    o_legacy_firefly_mon_readdatavalid <= legacy_firefly_mon_read_d;
    o_legacy_firefly_mon_response <= (others => '0');
    av_sc.address <= (others => '0');
    av_sc.read <= '0';
    av_sc.write <= '0';
    av_sc.writedata <= (others => '0');
    av_sc.readdatavalid <= '0';
    av_mscb.address <= (others => '0');
    av_mscb.read <= '0';
    av_mscb.write <= '0';
    av_mscb.writedata <= (others => '0');
    av_mscb.readdatavalid <= '0';

    process(i_clk_156)
    begin
    if rising_edge(i_clk_156) then
        o_run_state_156 <= run_state_156_resetsys;
        run_state_156   <= run_state_156_resetsys;
    end if;
    end process;

    process(i_nios_clk) -- i_clk_156 will be gone during reboot
    begin
    if rising_edge(i_nios_clk) then

        nios_reboot_156_prev    <= nios_reboot_156;
        nios_reboot_50_delay(5) <= '0';

        for I in 0 to 4 loop
            nios_reboot_50_delay(I) <= nios_reboot_50_delay(I+1);
        end loop;

        if(nios_reboot_156 = '1' and nios_reboot_156_prev = '0') then
            nios_reboot_50_delay <= (others => '1');
        end if;

        nios_reboot_50 <= nios_reboot_50_delay(0);
    end if;
    end process;

    -- generate resets
    e_nios_reset_n : entity work.reset_sync
    port map ( o_reset_n => nios_reset_n, i_reset_n => i_areset_n, i_clk => i_nios_clk );

    e_reset_156_n : entity work.reset_sync
    port map ( o_reset_n => reset_156_n, i_reset_n => i_areset_n, i_clk => i_clk_156 );

    e_reset_125_n : entity work.reset_sync
    port map ( o_reset_n => reset_125_n, i_reset_n => i_areset_n, i_clk => i_clk_125 );



    -- generate 1 Hz clock monitor signals

    -- NIOS_CLK_MHZ_g -> 1 Hz
    e_nios_clk_hz : entity work.clkdiv
    generic map ( g_N => integer(NIOS_CLK_MHZ_g * 1000000.0) )
    port map ( o_clk => o_nios_clk_mon, i_reset_n => nios_reset_n, i_clk => i_nios_clk );

    -- 156.25 MHz -> 1 Hz
    e_clk_156_hz : entity work.clkdiv
    generic map ( g_N => 156250000 )
    port map ( o_clk => o_clk_156_mon, i_reset_n => reset_156_n, i_clk => i_clk_156 );

    -- 125 MHz -> 1 Hz
    e_clk_125_hz : entity work.clkdiv
    generic map ( g_N => 125000000 )
    port map ( o_clk => o_clk_125_mon, i_reset_n => reset_125_n, i_clk => i_clk_125 );

    -- map slow control address space

    e_lvl0_sc_node: entity work.sc_node
    generic map (
        ADD_SLAVE1_DELAY_g  => SC_READ_DELAY_g-2,
        ADD_SLAVE2_DELAY_g  => SC_READ_DELAY_g-2,
        N_REPLY_CYCLES_g    => SC_READ_DELAY_g-1,
        SLAVE1_ADDR_MATCH_g => "11111111--------",
        SLAVE2_ADDR_MATCH_g => "111111----------"--,
    )
    port map (
        i_clk           => i_clk_156,
        i_reset_n       => reset_156_n,

        i_master_addr   => sc_reg.addr(15 downto 0),
        i_master_re     => sc_reg.re,
        o_master_rdata  => sc_reg.rdata,
        i_master_we     => sc_reg.we,
        i_master_wdata  => sc_reg.wdata,

        o_slave0_addr   => o_subdet_reg_addr(15 downto 0),
        o_slave0_re     => o_subdet_reg_re,
        i_slave0_rdata  => i_subdet_reg_rdata,
        o_slave0_we     => o_subdet_reg_we,
        o_slave0_wdata  => o_subdet_reg_wdata,

        o_slave1_addr   => firefly_reg.addr(15 downto 0),
        o_slave1_re     => firefly_reg.re,
        i_slave1_rdata  => firefly_reg.rdata,
        o_slave1_we     => firefly_reg.we,
        o_slave1_wdata  => firefly_reg.wdata,

        o_slave2_addr   => fe_reg.addr(15 downto 0),
        o_slave2_re     => fe_reg.re,
        i_slave2_rdata  => fe_reg.rdata,
        o_slave2_we     => fe_reg.we,
        o_slave2_wdata  => fe_reg.wdata--,
    );
	
	-- connection replaced for subdet_reg
	proc_subdet_reg_fab	: process(i_clk_156) 
	begin
		if rising_edge(i_clk_156) then
			if o_subdet_reg_re then
				ram_sub_det_wren		<= '0';
				ram_sub_det_rdaddress	<= o_subdet_reg_addr(15 downto 0);
				i_subdet_reg_rdata 		<= ram_sub_det_q;
			elsif o_subdet_reg_we then
				ram_sub_det_wren		<= '1';
				ram_sub_det_wraddress	<= o_subdet_reg_addr(15 downto 0);
				ram_sub_det_data		<= o_subdet_reg_wdata;
			else
				ram_sub_det_wren		<= '0';
			end if;
		end if;
	end process proc_subdet_reg_fab;
	
	e_ram_sub_det : ram_sub_det 
	PORT MAP (
		clock	 => i_clk_156,
		data	 => ram_sub_det_data,
		rdaddress	 => ram_sub_det_rdaddress(11 downto 0),
		wraddress	 => ram_sub_det_wraddress(11 downto 0),
		wren	 => ram_sub_det_wren,
		q	 => ram_sub_det_q
	);


    e_reg_mapping : entity work.feb_reg_mapping
    port map (
        i_reg_add                   => fe_reg.addr(15 downto 0),
        i_reg_re                    => fe_reg.re,
        o_reg_rdata                 => fe_reg.rdata,
        i_reg_we                    => fe_reg.we,
        i_reg_wdata                 => fe_reg.wdata,

        -- inputs  156--------------------------------------------
        -- ALL INPUTS DEFAULT TO (n*4-1 downto 0 => x"CCC..", others => '1')
        i_run_state_156             => run_state_156,
        i_merger_rate_count         => merger_rate_count,
        i_reset_phase               => reset_phase,
        i_arriaV_temperature        => arriaV_temperature,
        i_fpga_type                 => i_fpga_type,
        i_adc_reg                   => adc_reg,
        i_max10_version             => max10_version,
        i_max10_status              => max10_status,
        i_programming_status        => programming_status,
        i_run_start_denial_reason   => run_start_denial_reason,
        i_run_number                => run_number,

        i_ffly_pwr                  => ffly_pwr,
        i_ffly_temp                 => ffly_temp,
        i_ffly_alarm                => ffly_alarm,
        i_ffly_vcc                  => ffly_vcc,

        i_si45_intr_n               => i_si45_intr_n,
        i_si45_lol_n                => i_si45_lol_n,

        -- outputs 156--------------------------------------------
        o_reg_cmdlen                => reg_cmdlen,
        o_reg_offset                => reg_offset,
        o_reg_reset_bypass          => reg_reset_bypass,
        o_reg_reset_bypass_payload  => reg_reset_bypass_payload,
        o_arriaV_temperature_clr    => open, --arriaV_temperature_clr,
        o_arriaV_temperature_ce     => open, --arriaV_temperature_ce,
        o_fpga_id_reg               => fpga_id_reg,
        o_programming_ctrl          => programming_ctrl,
        o_programming_data          => programming_data,
        o_programming_data_ena      => programming_data_ena,
        o_programming_addr          => programming_addr,
        o_programming_addr_ena      => programming_addr_ena,

        o_nios_reboot               => nios_reboot_156,
        o_shutdown                  => shutdown_internal,
        i_testout                   => i_testout,

        i_reset_n                   => reset_156_n,
        i_clk                       => i_clk_156--,
    );

    -- legacy standalone Nios removed; SC decoding remains via sc_rx/sc_ram.
    nios_irq(0) <= '1' when ( reg_cmdlen(31 downto 16) /= (31 downto 16 => '0') ) else '0';


    e_sc_ram : entity work.sc_ram
    generic map (
        READ_DELAY_g => SC_READ_DELAY_g--,
    )
    port map (
        i_ram_addr              => sc_ram.addr(15 downto 0),
        i_ram_re                => sc_ram.re,
        o_ram_rvalid            => sc_ram.rvalid,
        o_ram_rdata             => sc_ram.rdata,
        i_ram_we                => sc_ram.we,
        i_ram_wdata             => sc_ram.wdata,

        i_avs_address           => av_sc.address(15 downto 0),
        i_avs_read              => av_sc.read,
        o_avs_readdata          => av_sc.readdata,
        i_avs_write             => av_sc.write,
        i_avs_writedata         => av_sc.writedata,
        o_avs_waitrequest       => av_sc.waitrequest,

        o_reg_addr              => sc_reg.addr(15 downto 0),
        o_reg_re                => sc_reg.re,
        i_reg_rdata             => sc_reg.rdata,
        o_reg_we                => sc_reg.we,
        o_reg_wdata             => sc_reg.wdata,

        i_reset_n               => reset_156_n,
        i_clk                   => i_clk_156--;
    );

    e_sc_rx : entity work.sc_rx
    port map (
        i_link_data     => ffly_rx_data(32*(feb_mapping(0)+1)-1 downto 32*feb_mapping(0)),
        i_link_datak    => ffly_rx_datak(4*(feb_mapping(0)+1)-1 downto 4*feb_mapping(0)),
        i_fpga_type     => i_fpga_type,

        o_fifo_we       => sc_fifo_write,
        o_fifo_wdata    => sc_fifo_wdata,

        o_ram_addr      => sc_ram.addr,
        o_ram_re        => sc_ram.re,
        i_ram_rvalid    => sc_ram.rvalid,
        i_ram_rdata     => sc_ram.rdata,
        o_ram_we        => sc_ram.we,
        o_ram_wdata     => sc_ram.wdata,

        i_reset_n       => reset_156_n,
        i_clk           => i_clk_156--,
    );
	
	
	
		
        -- Export the logical SC lane, not raw physical lane 0. The FE legacy
        -- slow-control path already consumes feb_mapping(0), and the SciFi top's
        -- qsys sc_hub must observe the same mapped lane.
		o_ffly_rx_data		<= ffly_rx_data(32*(feb_mapping(0)+1)-1 downto 32*feb_mapping(0));
		o_ffly_rx_datak		<= ffly_rx_datak(4*(feb_mapping(0)+1)-1 downto 4*feb_mapping(0));
		



    e_merger : entity work.data_merger
    generic map (
        N_LINKS                    => N_LINKS,
        feb_mapping                => feb_mapping--,
    )
    port map (
        fpga_ID_in                 => fpga_id_reg,
        FEB_type_in                => i_fpga_type,

        run_state                  => run_state_156,
        run_number                 => run_number,

        o_data_out(127 downto 96)  => open,
        o_data_out(95 downto 0)    => ffly_tx_data(95 downto 0),
        o_data_is_k(11 downto 0)   => ffly_tx_datak(11 downto 0),

        slowcontrol_write_req      => sc_fifo_write,
        i_data_in_slowcontrol      => sc_fifo_wdata,

        data_write_req             => i_fifo_write,
        i_data_in                  => i_fifo_wdata,
        o_fifos_almost_full        => o_fifos_almost_full,

        override_data_in           => linktest_data,
        override_data_is_k_in      => linktest_datak,
        override_req               => work.util.to_std_logic(run_state_156 = RUN_STATE_LINK_TEST),   --TODO test and find better way to connect this
        override_granted           => linktest_granted,

        can_terminate              => i_can_terminate,
        o_terminated               => terminated,
        i_ack_run_prep_permission  => i_ack_run_prep_permission,
        data_priority              => '0',
        o_rate_count               => merger_rate_count,

        reset                      => not reset_156_n,
        clk                        => i_clk_156--,
    );

    --TODO: do we need two independent link test modules for both fibers?
    e_link_test : entity work.linear_shift_link
    generic map (
        g_m => 32,
        g_poly => "10000000001000000000000000000110"--,
    )
    port map (
        i_sync_reset    => not work.util.and_reduce(linktest_granted),
        i_seed          => (others => '1'),
        i_en            => work.util.to_std_logic(run_state_156 = RUN_STATE_LINK_TEST),
        o_lsfr          => linktest_data,
        o_datak         => linktest_datak,
        i_reset_n       => reset_156_n,
        i_clk           => i_clk_156--,
    );



    e_reset_system : entity work.resetsys
    generic map (
         PHASE_WIDTH_g => PHASE_WIDTH_g--,
    )
    port map (
        i_data_125_rx           => i_resetlink_8bdata_rxclk(7 downto 0), --reset_link_rx(7 downto 0),
        i_data_ready            => i_resetlink_8bvalid_rxclk, --reset_link_ready,
        i_reset_125_rx_n        => '1', -- TODO: connect with reset_125 (rx_clk); reset_125_RRX_n,
        i_clk_125_rx            => i_resetlink_8bclock_rxclk,-- reset_link_rx_clk,

        o_state_125             => run_state_125,
        i_reset_125_n           => reset_125_n,
        i_clk_125               => i_clk_125,

        o_state_156             => run_state_156_resetsys,
        i_reset_156_n           => reset_156_n,
        i_clk_156               => i_clk_156,

        resets_out              => open,
        reset_bypass            => reg_reset_bypass(11 downto 0),
        reset_bypass_payload    => reg_reset_bypass_payload,
        run_number_out          => run_number,
        fpga_id                 => fpga_id_reg(15 downto 0),
        terminated              => terminated, --TODO: test with two datamergers
        testout                 => open,

        o_phase                 => reset_phase,
        i_reset_n               => nios_reset_n,
        i_clk                   => i_nios_clk--,
    );

    o_run_state_125 <= run_state_125;



    e_mscb : entity work.mscb
    generic map (
        g_CLK_MHZ => 156.25--,
    )
    port map (
        i_avs_address           => av_mscb.address(3 downto 0),
        i_avs_read              => av_mscb.read,
        o_avs_readdata          => av_mscb.readdata,
        i_avs_write             => av_mscb.write,
        i_avs_writedata         => av_mscb.writedata,
        o_avs_waitrequest       => av_mscb.waitrequest,

        i_rx_data               => i_mscb_data,
        o_tx_data               => o_mscb_data,
        o_tx_data_oe            => o_mscb_oe,

        o_irq                   => nios_irq(1),
        i_mscb_address          => X"ACA0",

        i_reset_n               => reset_156_n,
        i_clk                   => i_clk_156--,
    );
    

    firefly : entity work.firefly
    port map (
        i_shutdown                      => shutdown,

        -- rx
        i_data_fast_serial              => i_ffly2_rx & i_ffly1_rx,
        o_data_fast_parallel            => ffly_rx_data_ffly,
        o_datak                         => ffly_rx_datak_ffly,

        -- tx
        o_data_fast_serial(3 downto 0)  => o_ffly1_tx,
        o_data_fast_serial(7 downto 4)  => o_ffly2_tx,
        i_data_fast_parallel            => uplink_data, --ffly_tx_data & ffly_tx_data, -- 8 links (255)
        i_datak                         => uplink_datak, --ffly_tx_datak & ffly_tx_datak,

        -- I2C
--        i_i2c_enable                    => '1',
--        o_Mod_Sel_n                     => o_i2c_ffly_ModSel_n,
--        o_Rst_n                         => o_ffly_Rst_n,
--        io_scl                          => io_i2c_ffly_scl,
--        io_sda                          => io_i2c_ffly_sda,
--        i_int_n                         => i_ffly_Int_n,
--        i_modPrs_n                      => i_ffly_ModPrs_n,

        -- SC
        i_reg_add                       => firefly_reg.addr(15 downto 0),
        i_reg_re                        => firefly_reg.re,
        o_reg_rdata                     => firefly_reg.rdata,
        i_reg_we                        => firefly_reg.we,
        i_reg_wdata                     => firefly_reg.wdata,
        i_mon_reg_add                   => x"00" & i_legacy_firefly_mon_address,
        i_mon_reg_re                    => i_legacy_firefly_mon_read,
        o_mon_reg_rdata                 => legacy_firefly_reg_rdata,
        i_mon_reg_we                    => i_legacy_firefly_mon_write,
        i_mon_reg_wdata                 => i_legacy_firefly_mon_writedata,
        o_mon_reg_rvalid                => legacy_firefly_mon_read_d,

        o_pwr                           => ffly_pwr,
        o_temp                          => ffly_temp,
        o_vcc                           => ffly_vcc,
        o_alarm                         => ffly_alarm,

        i_clk_156                       => i_clk_156,
        i_reset_156_n                   => reset_156_n,

		

        -- lvds rx
        i_data_lvds_serial              => i_ffly2_lvds_rx & i_ffly1_lvds_rx, 
        o_data_lvds_parallel(7 downto 0) => reset_link_rx, -- [rx_coreclock] domain
        o_data_lvds_parallel(15 downto 8) => open,
        o_lvds_ready                    => reset_link_ready,
		
		i_resetlink_8bdata_sysclk		=> i_resetlink_8bdata_sysclk,

        -- lvds recovered clock
        o_lvds_rx_clk                   => reset_link_rx_clk, -- [rx_coreclock]
        o_lvds_rx_reset_n               => reset_125_RRX_n,

        -- lvds reference clock
        i_clk_125                       => i_clk_lvds_refclk,
        i_reset_125_n                   => reset_125_n,

        -- xcvr reconfig clock
        i_clk_50                        => i_nios_clk,
        i_reset_50_n                    => nios_reset_n--,
    );

    -- e_max10_interface is intentionally disabled in this deprecated path.

end architecture;
