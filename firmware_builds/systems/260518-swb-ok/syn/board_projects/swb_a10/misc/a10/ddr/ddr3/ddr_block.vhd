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
    g_simulation            : boolean := false;
    g_DDR4                  : boolean := false--;
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

    signal A_clk            : std_logic;
    signal A_reset_n        : std_logic;

    signal A_ready          : std_logic;
    signal A_read           : std_logic;
    signal A_write          : std_logic;
    signal A_address        : std_logic_vector(25 downto 0);
    signal A_readdata       : std_logic_vector(511 downto 0);
    signal A_writedata      : std_logic_vector(511 downto 0);
    signal A_burstcount     : std_logic_vector(6 downto 0);
    signal A_readdatavalid  : std_logic;

    signal B_cal_success    : std_logic;
    signal B_cal_fail       : std_logic;

    signal B_clk            : std_logic;
    signal B_reset_n        : std_logic;

    signal B_ready          : std_logic;
    signal B_read           : std_logic;
    signal B_write          : std_logic;
    signal B_address        : std_logic_vector(25 downto 0);
    signal B_readdata       : std_logic_vector(511 downto 0);
    signal B_writedata      : std_logic_vector(511 downto 0);
    signal B_burstcount     : std_logic_vector(6 downto 0);
    signal B_readdatavalid  : std_logic;

    signal A_errout         : std_logic_vector(31 downto 0);
    signal B_errout         : std_logic_vector(31 downto 0);

begin

    e_ddr_A : component work.cmp.ip_emif_ddr3
    port map (
        amm_ready_0         => A_ready,
        amm_read_0          => A_read,
        amm_write_0         => A_write,
        amm_address_0       => A_address,
        amm_readdata_0      => A_readdata,
        amm_writedata_0     => A_writedata,
        amm_burstcount_0    => A_burstcount,
        amm_byteenable_0    => (others => '1'),
        amm_readdatavalid_0 => A_readdatavalid,
        emif_usr_clk        => A_clk,
        emif_usr_reset_n    => A_reset_n,
        global_reset_n      => i_reset_n,
        mem_ck              => o_A_mem_ck,
        mem_ck_n            => o_A_mem_ck_n,
        mem_a               => o_A_mem_a(15 downto 0),
        mem_ba              => o_A_mem_ba,
        mem_cke             => o_A_mem_cke,
        mem_cs_n            => o_A_mem_cs_n,
        mem_odt             => o_A_mem_odt,
        mem_reset_n         => o_A_mem_reset_n,
        mem_we_n            => o_A_mem_we_n,
        mem_ras_n           => o_A_mem_ras_n,
        mem_cas_n           => o_A_mem_cas_n,
        mem_dqs             => io_A_mem_dqs,
        mem_dqs_n           => io_A_mem_dqs_n,
        mem_dq              => io_A_mem_dq,
        mem_dm              => o_A_mem_dm,
        oct_rzqin           => i_A_oct_rzqin,
        pll_ref_clk         => i_A_pll_ref_clk,
        local_cal_success   => A_cal_success,
        local_cal_fail      => A_cal_fail
    );

    e_ddr_B : component work.cmp.ip_emif_ddr3
    port map (
        amm_ready_0         => B_ready,
        amm_read_0          => B_read,
        amm_write_0         => B_write,
        amm_address_0       => B_address,
        amm_readdata_0      => B_readdata,
        amm_writedata_0     => B_writedata,
        amm_burstcount_0    => B_burstcount,
        amm_byteenable_0    => (others => '1'),
        amm_readdatavalid_0 => B_readdatavalid,
        emif_usr_clk        => B_clk,
        emif_usr_reset_n    => B_reset_n,
        global_reset_n      => i_reset_n,
        mem_ck              => o_B_mem_ck,
        mem_ck_n            => o_B_mem_ck_n,
        mem_a               => o_B_mem_a(15 downto 0),
        mem_ba              => o_B_mem_ba,
        mem_cke             => o_B_mem_cke,
        mem_cs_n            => o_B_mem_cs_n,
        mem_odt             => o_B_mem_odt,
        mem_reset_n         => o_B_mem_reset_n,
        mem_we_n            => o_B_mem_we_n,
        mem_ras_n           => o_B_mem_ras_n,
        mem_cas_n           => o_B_mem_cas_n,
        mem_dqs             => io_B_mem_dqs,
        mem_dqs_n           => io_B_mem_dqs_n,
        mem_dq              => io_B_mem_dq,
        mem_dm              => o_B_mem_dm,
        oct_rzqin           => i_B_oct_rzqin,
        pll_ref_clk         => i_B_pll_ref_clk,
        local_cal_success   => B_cal_success,
        local_cal_fail      => B_cal_fail
    );

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
        i_M_clk             => A_clk,
        i_M_reset_n         => A_reset_n,
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
        i_M_clk             => B_clk,
        i_M_reset_n         => B_reset_n,
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

end architecture;
