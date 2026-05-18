-----------------------------------------------------------------------------
-- Handling of the DDR3/DDR4 buffer for the farm pcs
--
-- Niklaus Berger, JGU Mainz
-- niberger@uni-mainz.de
--
-- Marius Koeppel, JGU Mainz
-- mkoeppel@uni-mainz.de
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.a10_pcie_registers.all;


entity ddr_block is
generic (
    g_simulation            : boolean   := false;
    g_DDR4                  : boolean   := false--;
);
port (
    -- Control and status registers
    i_ddr_control           : in    std_logic_vector(31 downto 0);
    o_ddr_status            : out   std_logic_vector(31 downto 0);

    -- A interface
    o_A_ddr_calibrated      : out   std_logic;
    o_A_ddr_ready           : out   std_logic;
    i_A_ddr_addr            : in    std_logic_vector(25 downto 0);
    i_A_ddr_datain          : in    std_logic_vector(511 downto 0);
    o_A_ddr_dataout         : out   std_logic_vector(511 downto 0);
    i_A_ddr_write           : in    std_logic;
    i_A_ddr_read            : in    std_logic;
    o_A_ddr_read_valid      : out   std_logic;

    -- B interface
    o_B_ddr_calibrated      : out   std_logic;
    o_B_ddr_ready           : out   std_logic;
    i_B_ddr_addr            : in    std_logic_vector(25 downto 0);
    i_B_ddr_datain          : in    std_logic_vector(511 downto 0);
    o_B_ddr_dataout         : out   std_logic_vector(511 downto 0);
    i_B_ddr_write           : in    std_logic;
    i_B_ddr_read            : in    std_logic;
    o_B_ddr_read_valid      : out   std_logic;

    -- Error counters
    o_error                 : out   std_logic_vector(31 downto 0);

    -- Interface to memory bank A
    o_A_mem_ck              : out   std_logic_vector(0 downto 0);                      -- mem_ck
    o_A_mem_ck_n            : out   std_logic_vector(0 downto 0);                      -- mem_ck_n
    o_A_mem_a               : out   std_logic_vector(16 downto 0);                     -- mem_a
    o_A_mem_act_n           : out   std_logic_vector(0 downto 0);                      -- mem_act_n
    o_A_mem_ba              : out   std_logic_vector(2 downto 0);                      -- mem_ba
    o_A_mem_bg              : out   std_logic_vector(1 downto 0);                      -- mem_bg
    o_A_mem_cke             : out   std_logic_vector(0 downto 0);                      -- mem_cke
    o_A_mem_cs_n            : out   std_logic_vector(0 downto 0);                      -- mem_cs_n
    o_A_mem_odt             : out   std_logic_vector(0 downto 0);                      -- mem_odt
    o_A_mem_reset_n         : out   std_logic_vector(0 downto 0);                      -- mem_reset_n
    i_A_mem_alert_n         : in    std_logic_vector(0 downto 0);                      -- mem_alert_n
    o_A_mem_we_n            : out   std_logic_vector(0 downto 0);                      -- mem_we_n
    o_A_mem_ras_n           : out   std_logic_vector(0 downto 0);                      -- mem_ras_n
    o_A_mem_cas_n           : out   std_logic_vector(0 downto 0);                      -- mem_cas_n
    io_A_mem_dqs            : inout std_logic_vector(7 downto 0)   := (others => 'X'); -- mem_dqs
    io_A_mem_dqs_n          : inout std_logic_vector(7 downto 0)   := (others => 'X'); -- mem_dqs_n
    io_A_mem_dq             : inout std_logic_vector(63 downto 0)  := (others => 'X'); -- mem_dq
    o_A_mem_dm              : out   std_logic_vector(7 downto 0);                      -- mem_dm
    io_A_mem_dbi_n          : inout std_logic_vector(7 downto 0)   := (others => 'X'); -- mem_dbi_n
    i_A_oct_rzqin           : in    std_logic                      := 'X';             -- oct_rzqin
    i_A_pll_ref_clk         : in    std_logic                      := 'X';             -- clk

    -- Interface to memory bank B
    o_B_mem_ck              : out   std_logic_vector(0 downto 0);                      -- mem_ck
    o_B_mem_ck_n            : out   std_logic_vector(0 downto 0);                      -- mem_ck_n
    o_B_mem_a               : out   std_logic_vector(16 downto 0);                     -- mem_a
    o_B_mem_act_n           : out   std_logic_vector(0 downto 0);                      -- mem_act_n
    o_B_mem_ba              : out   std_logic_vector(2 downto 0);                      -- mem_ba
    o_B_mem_bg              : out   std_logic_vector(1 downto 0);                      -- mem_bg
    o_B_mem_cke             : out   std_logic_vector(0 downto 0);                      -- mem_cke
    o_B_mem_cs_n            : out   std_logic_vector(0 downto 0);                      -- mem_cs_n
    o_B_mem_odt             : out   std_logic_vector(0 downto 0);                      -- mem_odt
    o_B_mem_reset_n         : out   std_logic_vector(0 downto 0);                      -- mem_reset_n
    i_B_mem_alert_n         : in    std_logic_vector(0 downto 0);                      -- mem_alert_n
    o_B_mem_we_n            : out   std_logic_vector(0 downto 0);                      -- mem_we_n
    o_B_mem_ras_n           : out   std_logic_vector(0 downto 0);                      -- mem_ras_n
    o_B_mem_cas_n           : out   std_logic_vector(0 downto 0);                      -- mem_cas_n
    io_B_mem_dqs            : inout std_logic_vector(7 downto 0)   := (others => 'X'); -- mem_dqs
    io_B_mem_dqs_n          : inout std_logic_vector(7 downto 0)   := (others => 'X'); -- mem_dqs_n
    io_B_mem_dq             : inout std_logic_vector(63 downto 0)  := (others => 'X'); -- mem_dq
    o_B_mem_dm              : out   std_logic_vector(7 downto 0);                      -- mem_dm
    io_B_mem_dbi_n          : inout std_logic_vector(7 downto 0)   := (others => 'X'); -- mem_dbi_n
    i_B_oct_rzqin           : in    std_logic                      := 'X';             -- oct_rzqin
    i_B_pll_ref_clk         : in    std_logic                      := 'X';             -- clk

    i_reset_n               : in    std_logic;
    i_clk                   : in    std_logic--;
);
end entity;

architecture arch of ddr_block is

    signal A_cal_success    : std_logic;
    signal A_cal_fail       : std_logic;

    signal A_reset_n        : std_logic;

    signal A_ready          : std_logic;
    signal A_read, A_read_del1, A_read_del2, A_read_del3, A_read_del4 : std_logic;
    signal A_write          : std_logic;
    signal A_address, A_addr, A_addr_del1, A_addr_del2, A_addr_del3, A_addr_del4 : std_logic_vector(25 downto 0);
    signal A_readdata       : std_logic_vector(511 downto 0);
    signal A_writedata      : std_logic_vector(511 downto 0);
    signal A_burstcount     : std_logic_vector(6 downto 0);
    signal A_readdatavalid  : std_logic;

    signal B_cal_success    : std_logic;
    signal B_cal_fail       : std_logic;

    signal B_clk            : std_logic;
    signal B_reset_n        : std_logic;

    signal B_ready          : std_logic;
    signal B_read, B_read_del1, B_read_del2, B_read_del3, B_read_del4 : std_logic;
    signal B_write          : std_logic;
    signal B_address, B_addr, B_addr_del1, B_addr_del2, B_addr_del3, B_addr_del4 : std_logic_vector(25 downto 0);
    signal B_readdata       : std_logic_vector(511 downto 0);
    signal B_writedata      : std_logic_vector(511 downto 0);
    signal B_burstcount     : std_logic_vector(6 downto 0);
    signal B_readdatavalid  : std_logic;

    signal A_errout         : std_logic_vector(31 downto 0);
    signal B_errout         : std_logic_vector(31 downto 0);

    constant CLK_MHZ : time := 4 ns;

begin

    --! we output counting errors when we performe the counter test
    o_error <= B_errout when i_ddr_control(DDR_BIT_COUNTERTEST_B) = '1' else A_errout;


    --! setup memory controller
    memctlA : entity work.ddr_memory_controller
    port map (
        -- Control and status registers
        i_ddr_control       => i_ddr_control(DDR_RANGE_A),
        o_ddr_status        => o_ddr_status(DDR_RANGE_A),

        o_ddr_calibrated    => o_A_ddr_calibrated,
        o_ddr_ready         => o_A_ddr_ready,

        i_ddr_addr          => i_A_ddr_addr,
        i_ddr_data          => i_A_ddr_datain,
        o_ddr_data          => o_A_ddr_dataout,
        i_ddr_write         => i_A_ddr_write,
        i_ddr_read          => i_A_ddr_read,
        o_ddr_read_valid    => o_A_ddr_read_valid,

        -- Error counters
        o_error             => A_errout,

        -- IF to DDR
        i_M_cal_success     => A_cal_success,
        i_M_cal_fail        => A_cal_fail,
        i_M_clk             => i_clk,
        i_M_reset_n         => i_reset_n,
        i_M_ready           => A_ready,
        o_M_read            => A_read,
        o_M_write           => A_write,
        o_M_address         => A_address,
        i_M_readdata        => A_readdata,
        o_M_writedata       => A_writedata,
        o_M_burstcount      => A_burstcount,
        i_M_readdatavalid   => A_readdatavalid,

        i_reset_n           => i_reset_n,
        i_clk               => i_clk--,
    );

    memctlB : entity work.ddr_memory_controller
    port map (
        -- Control and status registers
        i_ddr_control       => i_ddr_control(DDR_RANGE_B),
        o_ddr_status        => o_ddr_status(DDR_RANGE_B),

        o_ddr_calibrated    => o_B_ddr_calibrated,
        o_ddr_ready         => o_B_ddr_ready,

        i_ddr_addr          => i_B_ddr_addr,
        i_ddr_data          => i_B_ddr_datain,
        o_ddr_data          => o_B_ddr_dataout,
        i_ddr_write         => i_B_ddr_write,
        i_ddr_read          => i_B_ddr_read,
        o_ddr_read_valid    => o_B_ddr_read_valid,

        -- Error counters
        o_error             => B_errout,

        -- IF to DDR
        i_M_cal_success     => B_cal_success,
        i_M_cal_fail        => B_cal_fail,
        i_M_clk             => i_clk,
        i_M_reset_n         => i_reset_n,
        i_M_ready           => B_ready,
        o_M_read            => B_read,
        o_M_write           => B_write,
        o_M_address         => B_address,
        i_M_readdata        => B_readdata,
        o_M_writedata       => B_writedata,
        o_M_burstcount      => B_burstcount,
        i_M_readdatavalid   => B_readdatavalid,

        i_reset_n           => i_reset_n,
        i_clk               => i_clk--,
    );

    --! simulation of ddr ram
    e_ddr3_a : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => 9,
        g_ADDR1_WIDTH => 9,
        g_DATA0_WIDTH => 512,
        g_DATA1_WIDTH => 512--,
    )
    port map (
        i_addr0     => A_address(8 downto 0),
        i_addr1     => A_address(8 downto 0),
        i_clk0      => i_clk,
        i_clk1      => i_clk,
        i_wdata0    => A_writedata,
        i_wdata1    => (others => '0'),
        i_we0       => A_write,
        i_we1       => '0',
        o_rdata0    => open,
        o_rdata1    => A_readdata--,
    );

    e_ddr3_b : entity work.ip_ram_2rw
    generic map (
        g_ADDR0_WIDTH => 9,
        g_ADDR1_WIDTH => 9,
        g_DATA0_WIDTH => 512,
        g_DATA1_WIDTH => 512--,
    )
    port map (
        i_addr0     => B_address(8 downto 0),
        i_addr1     => B_address(8 downto 0),
        i_clk0      => i_clk,
        i_clk1      => i_clk,
        i_wdata0    => B_writedata,
        i_wdata1    => (others => '0'),
        i_we0       => B_write,
        i_we1       => '0',
        o_rdata0    => open,
        o_rdata1    => B_readdata--,
    );

    -- Memready
    process begin
        A_ready <= '0';
        B_ready <= '0';
        wait for CLK_MHZ * 25;
        A_ready <= '1';
        B_ready <= '1';
        wait for CLK_MHZ * 300;
        A_ready <= '0';
        B_ready <= '0';
        wait for CLK_MHZ;
        A_ready <= '1';
        B_ready <= '1';
        wait for CLK_MHZ * 250;
        A_ready <= '0';
        B_ready <= '0';
        wait for CLK_MHZ;
        A_ready <= '1';
        B_ready <= '1';
        wait for CLK_MHZ * 600;
    end process;

    A_cal_success <= '1';
    B_cal_success <= '1';

    -- Memory A simulation
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n <= '0' ) then
        A_readdatavalid <= '0';
        A_read_del1 <= '0';
        A_read_del2 <= '0';
        A_read_del3 <= '0';
        A_read_del4 <= '0';
    elsif rising_edge(i_clk) then
        A_read_del1 <= A_read;
        A_read_del2 <= A_read_del1;
        A_read_del3 <= A_read_del2;
        A_read_del4 <= A_read_del3;
        A_readdatavalid <= A_read_del4;

        A_addr_del1 <= A_address;
        A_addr_del2 <= A_addr_del1;
        A_addr_del3 <= A_addr_del2;
        A_addr_del4 <= A_addr_del3;
    --  A_mem_q <= (others => '0');
    --  A_mem_q(25 downto 0) <= A_mem_addr_del4;
    end if;
    end process;

    -- Memory B simulation
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n <= '0' ) then
        B_readdatavalid <= '0';
        B_read_del1 <= '0';
        B_read_del2 <= '0';
        B_read_del3 <= '0';
        B_read_del4 <= '0';
    elsif rising_edge(i_clk) then
        B_read_del1 <= B_read;
        B_read_del2 <= B_read_del1;
        B_read_del3 <= B_read_del2;
        B_read_del4 <= B_read_del3;
        B_readdatavalid <= B_read_del4;

        B_addr_del1 <= B_address;
        B_addr_del2 <= B_addr_del1;
        B_addr_del3 <= B_addr_del2;
        B_addr_del4 <= B_addr_del3;
    --  B_mem_q               <= (others => '0');
    --  B_mem_q(25 downto 0)  <= B_addr_del4;
    end if;
    end process;

end architecture;
