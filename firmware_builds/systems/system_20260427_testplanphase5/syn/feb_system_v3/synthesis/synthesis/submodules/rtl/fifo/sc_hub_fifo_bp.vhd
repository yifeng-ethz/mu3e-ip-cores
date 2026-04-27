-- File name: sc_hub_fifo_bp.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Version : 26.2.0
-- Date    : 20260331
-- Change  : Add the 40-bit backpressure FIFO wrapper used by the reply path.
-- =======================================
-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sc_hub_pkg.all;

entity sc_hub_fifo_bp is
    generic(
        DEPTH_G : positive := 512
    );
    port(
        csi_clk   : in  std_logic;
        rsi_reset : in  std_logic;
        clear     : in  std_logic;
        write_en  : in  std_logic;
        write_data: in  std_logic_vector(39 downto 0);
        read_en   : in  std_logic;
        read_data : out std_logic_vector(39 downto 0);
        empty     : out std_logic;
        full      : out std_logic;
        half_full : out std_logic;
        usedw     : out std_logic_vector(ceil_log2_func(DEPTH_G + 1) - 1 downto 0)
    );
end entity sc_hub_fifo_bp;

architecture rtl of sc_hub_fifo_bp is
    signal usedw_int : std_logic_vector(ceil_log2_func(DEPTH_G + 1) - 1 downto 0);
begin
    fifo_inst : entity work.sc_hub_fifo_sc
    generic map(
        WIDTH_G => 40,
        DEPTH_G => DEPTH_G
    )
    port map(
        csi_clk    => csi_clk,
        rsi_reset  => rsi_reset,
        clear      => clear,
        write_en   => write_en,
        write_data => write_data,
        read_en    => read_en,
        read_data  => read_data,
        empty      => empty,
        full       => full,
        usedw      => usedw_int
    );

    usedw     <= usedw_int;
    half_full <= '1' when (to_integer(unsigned(usedw_int)) >= (DEPTH_G / 2)) else '0';
end architecture rtl;
