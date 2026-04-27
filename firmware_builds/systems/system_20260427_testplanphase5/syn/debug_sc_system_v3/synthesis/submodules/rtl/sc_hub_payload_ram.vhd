-- File name: sc_hub_payload_ram.vhd
-- Author: OpenAI Codex
-- =======================================
-- Version : 26.3.0
-- Date    : 20260402
-- Change  : Add a simple single-clock payload RAM wrapper with one write port
--           and one synchronous read port, intended for per-slot M10K-backed
--           payload storage in standalone timing/resource builds.
-- =======================================
-- altera vhdl_input_version vhdl_2008

library ieee;
use ieee.std_logic_1164.all;

entity sc_hub_payload_ram is
    generic (
        DATA_WIDTH_G : positive := 32;
        ADDR_WIDTH_G : positive := 8
    );
    port (
        i_clk     : in  std_logic;
        i_rd_addr : in  natural range 0 to 2 ** ADDR_WIDTH_G - 1;
        i_wr_addr : in  natural range 0 to 2 ** ADDR_WIDTH_G - 1;
        i_wr_data : in  std_logic_vector(DATA_WIDTH_G - 1 downto 0);
        i_wr_en   : in  std_logic := '0';
        o_rd_data : out std_logic_vector(DATA_WIDTH_G - 1 downto 0)
    );
end entity sc_hub_payload_ram;

architecture rtl of sc_hub_payload_ram is
    subtype word_t is std_logic_vector(DATA_WIDTH_G - 1 downto 0);
    type ram_t is array (0 to 2 ** ADDR_WIDTH_G - 1) of word_t;

    signal ram       : ram_t := (others => (others => '0'));
    signal rd_data_q : word_t := (others => '0');

    attribute ramstyle : string;
    attribute ramstyle of ram : signal is "M10K,no_rw_check";
begin
    o_rd_data <= rd_data_q;

    ram_reg : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_wr_en = '1') then
                ram(i_wr_addr) <= i_wr_data;
            end if;
            rd_data_q <= ram(i_rd_addr);
        end if;
    end process ram_reg;
end architecture rtl;
