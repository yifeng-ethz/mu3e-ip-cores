--
-- author : Alexandr Kozlinskiy
-- date : 2017-01-19
--

library ieee;
use ieee.std_logic_1164.all;

entity hex2seg7 is
port (
    i_hex   : in    std_logic_vector(3 downto 0);
    o_seg   : out   std_logic_vector(6 downto 0)--;
);
end entity;

architecture arch of hex2seg7 is

begin

    process(i_hex)
    begin
        case i_hex is
        when X"0" => o_seg <= "1000000";
        when X"1" => o_seg <= "1111001";
        when X"2" => o_seg <= "0100100";
        when X"3" => o_seg <= "0110000";
        when X"4" => o_seg <= "0011001";
        when X"5" => o_seg <= "0010010";
        when X"6" => o_seg <= "0000010";
        when X"7" => o_seg <= "1111000";
        when X"8" => o_seg <= "0000000";
        when X"9" => o_seg <= "0011000";
        when X"A" => o_seg <= "0001000";
        when X"B" => o_seg <= "0000011";
        when X"C" => o_seg <= "1000110";
        when X"D" => o_seg <= "0100001";
        when X"E" => o_seg <= "0000110";
        when X"F" => o_seg <= "0001110";
        when others =>
            o_seg <= (others => 'X');
        end case;
        --
    end process;

end architecture;
