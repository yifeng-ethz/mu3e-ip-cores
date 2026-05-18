--
-- Marius Koeppel
--
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity chip_lookup_scifi is
port (
    i_fpgaID    : in   std_logic_vector (3 downto 0);
    i_chipID    : in   std_logic_vector (3 downto 0);
    o_chipID    : out  std_logic_vector (6 downto 0)--;
);
end entity;

architecture arch of chip_lookup_scifi is

begin

    o_chipID <=
        "0000000" when i_fpgaID = x"0" and i_chipID(2 downto 0) = "000" else
        "0000001" when i_fpgaID = x"0" and i_chipID(2 downto 0) = "001" else
        "0000010" when i_fpgaID = x"0" and i_chipID(2 downto 0) = "010" else
        "0000011" when i_fpgaID = x"0" and i_chipID(2 downto 0) = "011" else
        "0000100" when i_fpgaID = x"2" and i_chipID(2 downto 0) = "100" else
        "0000101" when i_fpgaID = x"2" and i_chipID(2 downto 0) = "101" else
        "0000110" when i_fpgaID = x"2" and i_chipID(2 downto 0) = "110" else
        "0000111" when i_fpgaID = x"2" and i_chipID(2 downto 0) = "111" else
        "0001000" when i_fpgaID = x"1" and i_chipID(2 downto 0) = "000" else
        "0001001" when i_fpgaID = x"1" and i_chipID(2 downto 0) = "001" else
        "0001010" when i_fpgaID = x"1" and i_chipID(2 downto 0) = "010" else
        "0001011" when i_fpgaID = x"1" and i_chipID(2 downto 0) = "011" else
        "0001100" when i_fpgaID = x"3" and i_chipID(2 downto 0) = "100" else
        "0001101" when i_fpgaID = x"3" and i_chipID(2 downto 0) = "101" else
        "0001110" when i_fpgaID = x"3" and i_chipID(2 downto 0) = "110" else
        "0001111" when i_fpgaID = x"3" and i_chipID(2 downto 0) = "111" else
        "1111111";

end architecture;
