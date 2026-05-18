--
-- Marius Koeppel
--
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.a10_pcie_registers.all;
use work.mudaq.all;

entity chip_lookup is
port (
    i_fpgaID        : in   std_logic_vector(5 downto 0);
    i_FEBChipID     : in   std_logic_vector(5 downto 0);
    i_data_type     : in   std_logic_vector(5 downto 0);

    i_lookup_ctrl   : in  std_logic_vector(31 downto 0);

    o_globalChipID  : out  std_logic_vector(13 downto 0);

    i_reset_n       : in  std_logic;
    i_clk           : in  std_logic--;
);
end entity;

architecture arch of chip_lookup is

    signal look_up_addr    : std_logic_vector(6 downto 0);
    signal globalChipID    : std_logic_vector(13 downto 0);
    signal generic_loop_up : work.util_slv.slv14_array_t(127 downto 0) := (others => (others => '0'));

begin

    o_globalChipID <= globalChipID;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        --
    elsif rising_edge(i_clk) then

        case i_lookup_ctrl(SWB_LOOKUP_CTRL_COMMAND_RANGE) is
            when "00" => -- IDLE
                --
            when "01" => -- WRITE RAM
                generic_loop_up(to_integer(unsigned(i_lookup_ctrl(SWB_LOOKUP_CTRL_ADDR_RANGE)))) <= i_lookup_ctrl(SWB_LOOKUP_CTRL_VALUE_RANGE);
                --
            when others =>
                --
        end case;
    end if;
    end process;
    -- TODO: this works for 8 input links and for outer pixel even only one
    look_up_addr <= i_fpgaID(0) & i_FEBChipID when i_data_type = OUTER_HEADER_ID else i_fpgaID(2 downto 0) & i_FEBChipID(3 downto 0);
    globalChipID <= generic_loop_up(to_integer(unsigned(look_up_addr)));

end architecture;
