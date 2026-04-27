-- File name: sc_hub_fifo_sc.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Version : 26.2.0
-- Date    : 20260331
-- Change  : Add a generic show-ahead FIFO for the modular sc_hub v2 datapath.
-- =======================================
-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sc_hub_pkg.all;

entity sc_hub_fifo_sc is
    generic(
        WIDTH_G : positive := 32;
        DEPTH_G : positive := 256
    );
    port(
        csi_clk    : in  std_logic;
        rsi_reset  : in  std_logic;
        clear      : in  std_logic;
        write_en   : in  std_logic;
        write_data : in  std_logic_vector(WIDTH_G - 1 downto 0);
        read_en    : in  std_logic;
        read_data  : out std_logic_vector(WIDTH_G - 1 downto 0);
        empty      : out std_logic;
        full       : out std_logic;
        usedw      : out std_logic_vector(ceil_log2_func(DEPTH_G + 1) - 1 downto 0)
    );
end entity sc_hub_fifo_sc;

architecture rtl of sc_hub_fifo_sc is
    subtype fifo_index_t is natural range 0 to DEPTH_G - 1;
    type fifo_mem_t is array (fifo_index_t) of std_logic_vector(WIDTH_G - 1 downto 0);

    signal fifo_mem      : fifo_mem_t := (others => (others => '0'));
    signal rd_ptr        : fifo_index_t := 0;
    signal wr_ptr        : fifo_index_t := 0;
    signal word_count    : natural range 0 to DEPTH_G := 0;
    signal read_data_int : std_logic_vector(WIDTH_G - 1 downto 0);

    function next_index_func (
        value_in : fifo_index_t
    ) return fifo_index_t is
    begin
        if (value_in = DEPTH_G - 1) then
            return 0;
        else
            return value_in + 1;
        end if;
    end function next_index_func;
begin
    read_data_int <= fifo_mem(rd_ptr) when (word_count /= 0) else (others => '0');

    read_data <= read_data_int;
    empty     <= '1' when (word_count = 0) else '0';
    full      <= '1' when (word_count = DEPTH_G) else '0';
    usedw     <= std_logic_vector(to_unsigned(word_count, usedw'length));

    fifo_storage : process(csi_clk)
        variable can_write_v : boolean;
        variable can_read_v  : boolean;
    begin
        if rising_edge(csi_clk) then
            if (rsi_reset = '1' or clear = '1') then
                rd_ptr     <= 0;
                wr_ptr     <= 0;
                word_count <= 0;
            else
                can_write_v := (write_en = '1') and (word_count < DEPTH_G);
                can_read_v  := (read_en = '1') and (word_count > 0);

                if (can_write_v = true) then
                    fifo_mem(wr_ptr) <= write_data;
                    wr_ptr           <= next_index_func(wr_ptr);
                end if;

                if (can_read_v = true) then
                    rd_ptr <= next_index_func(rd_ptr);
                end if;

                if (can_write_v = true and can_read_v = false) then
                    word_count <= word_count + 1;
                elsif (can_write_v = false and can_read_v = true) then
                    word_count <= word_count - 1;
                end if;
            end if;
        end if;
    end process fifo_storage;
end architecture rtl;
