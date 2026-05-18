--
-- Marius Koeppel
--
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity chip_lookup_edm_2021 is
port (
    i_fpgaID    : in   std_logic_vector(3 downto 0);
    i_chipID    : in   std_logic_vector(3 downto 0);
    o_chipID    : out  std_logic_vector(6 downto 0)--;
);
end entity;

architecture arch of chip_lookup_edm_2021 is

begin

    o_chipID <=
        "0000000" when i_fpgaID = x"0" and i_chipID = x"0" else
        "0000001" when i_fpgaID = x"0" and i_chipID = x"1" else
        "0000010" when i_fpgaID = x"0" and i_chipID = x"2" else
        "0000011" when i_fpgaID = x"0" and i_chipID = x"3" else
        "0000100" when i_fpgaID = x"1" and i_chipID = x"0" else
        "0000101" when i_fpgaID = x"1" and i_chipID = x"1" else
        "0000110" when i_fpgaID = x"1" and i_chipID = x"2" else
        "0000111" when i_fpgaID = x"1" and i_chipID = x"3" else
        "0001000" when i_fpgaID = x"0" and i_chipID = x"4" else -- szintillator
        "0001001" when i_fpgaID = x"0" and i_chipID = x"5" else -- rf signal
        "1111111";

end architecture;
