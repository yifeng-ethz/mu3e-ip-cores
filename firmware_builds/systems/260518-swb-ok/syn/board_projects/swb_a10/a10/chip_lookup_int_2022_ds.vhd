--
-- Marius Koeppel
--
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity chip_lookup_int_2022_ds is
port (
    i_fpgaID    : in   std_logic_vector(3 downto 0);
    i_chipID    : in   std_logic_vector(3 downto 0);
    o_chipID    : out  std_logic_vector(6 downto 0)--;
);
end entity;

architecture arch of chip_lookup_int_2022_ds is

begin

    o_chipID <=
        "0111100" when i_fpgaID = x"0" and i_chipID = x"0" else
        "0111101" when i_fpgaID = x"0" and i_chipID = x"1" else
        "0111110" when i_fpgaID = x"0" and i_chipID = x"2" else
        "0111111" when i_fpgaID = x"0" and i_chipID = x"3" else
        "1000000" when i_fpgaID = x"0" and i_chipID = x"4" else
        "1000001" when i_fpgaID = x"0" and i_chipID = x"5" else
        "1000010" when i_fpgaID = x"0" and i_chipID = x"6" else
        "1000011" when i_fpgaID = x"0" and i_chipID = x"7" else
        "1000100" when i_fpgaID = x"0" and i_chipID = x"8" else
        "1000101" when i_fpgaID = x"0" and i_chipID = x"9" else
        "1000110" when i_fpgaID = x"0" and i_chipID = x"a" else
        "1000111" when i_fpgaID = x"0" and i_chipID = x"b" else
        "1001000" when i_fpgaID = x"1" and i_chipID = x"0" else
        "1001001" when i_fpgaID = x"1" and i_chipID = x"1" else
        "1001010" when i_fpgaID = x"1" and i_chipID = x"2" else
        "1001011" when i_fpgaID = x"1" and i_chipID = x"3" else
        "1001100" when i_fpgaID = x"1" and i_chipID = x"4" else
        "1001101" when i_fpgaID = x"1" and i_chipID = x"5" else
        "1001110" when i_fpgaID = x"1" and i_chipID = x"6" else
        "1001111" when i_fpgaID = x"1" and i_chipID = x"7" else
        "1010000" when i_fpgaID = x"1" and i_chipID = x"8" else
        "1010001" when i_fpgaID = x"1" and i_chipID = x"9" else
        "1010010" when i_fpgaID = x"1" and i_chipID = x"a" else
        "1010011" when i_fpgaID = x"1" and i_chipID = x"b" else
        "1010100" when i_fpgaID = x"2" and i_chipID = x"0" else
        "1010101" when i_fpgaID = x"2" and i_chipID = x"1" else
        "1010110" when i_fpgaID = x"2" and i_chipID = x"2" else
        "1010111" when i_fpgaID = x"2" and i_chipID = x"3" else
        "1011000" when i_fpgaID = x"2" and i_chipID = x"4" else
        "1011001" when i_fpgaID = x"2" and i_chipID = x"5" else
        "1011010" when i_fpgaID = x"2" and i_chipID = x"6" else
        "1011011" when i_fpgaID = x"2" and i_chipID = x"7" else
        "1011100" when i_fpgaID = x"2" and i_chipID = x"8" else
        "1011101" when i_fpgaID = x"2" and i_chipID = x"9" else
        "1011110" when i_fpgaID = x"2" and i_chipID = x"a" else
        "1011111" when i_fpgaID = x"2" and i_chipID = x"b" else
        "1100000" when i_fpgaID = x"3" and i_chipID = x"0" else
        "1100001" when i_fpgaID = x"3" and i_chipID = x"1" else
        "1100010" when i_fpgaID = x"3" and i_chipID = x"2" else
        "1100011" when i_fpgaID = x"3" and i_chipID = x"3" else
        "1100100" when i_fpgaID = x"3" and i_chipID = x"4" else
        "1100101" when i_fpgaID = x"3" and i_chipID = x"5" else
        "1100110" when i_fpgaID = x"3" and i_chipID = x"6" else
        "1100111" when i_fpgaID = x"3" and i_chipID = x"7" else
        "1101000" when i_fpgaID = x"3" and i_chipID = x"8" else
        "1101001" when i_fpgaID = x"3" and i_chipID = x"9" else
        "1101010" when i_fpgaID = x"3" and i_chipID = x"a" else
        "1101011" when i_fpgaID = x"3" and i_chipID = x"b" else
        "1101100" when i_fpgaID = x"4" and i_chipID = x"0" else
        "1101101" when i_fpgaID = x"4" and i_chipID = x"1" else
        "1101110" when i_fpgaID = x"4" and i_chipID = x"2" else
        "1101111" when i_fpgaID = x"4" and i_chipID = x"3" else
        "1110000" when i_fpgaID = x"4" and i_chipID = x"4" else
        "1110001" when i_fpgaID = x"4" and i_chipID = x"5" else
        "1110010" when i_fpgaID = x"4" and i_chipID = x"6" else
        "1110011" when i_fpgaID = x"4" and i_chipID = x"7" else
        "1110100" when i_fpgaID = x"4" and i_chipID = x"8" else
        "1110101" when i_fpgaID = x"4" and i_chipID = x"9" else
        "1110110" when i_fpgaID = x"4" and i_chipID = x"a" else
        "1110111" when i_fpgaID = x"4" and i_chipID = x"b" else
        -- trigger input
        "1111000" when i_fpgaID = x"5" and i_chipID = x"3" else
        "1111001" when i_fpgaID = x"5" and i_chipID = x"4" else
        "1111111";

end architecture;
