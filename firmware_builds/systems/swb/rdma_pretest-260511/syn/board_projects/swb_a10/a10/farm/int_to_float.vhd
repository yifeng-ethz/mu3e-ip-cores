--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity int_to_float is
port (
    i_int       : in    std_logic_vector(7 downto 0);
    o_float     : out   std_logic_vector(31 downto 0);
    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture rtl of int_to_float is

begin

    process(i_clk, i_reset_n)
        variable mantissa : std_logic_vector(7 downto 0);
        variable exponent : std_logic_vector(7 downto 0);
        variable zero : std_logic;
    begin
    if ( i_reset_n = '0' )then
        o_float <= (others => '0');
    elsif rising_edge(i_clk) then
        mantissa := i_int;
        exponent := X"86"; -- 134 = 127 + 7
        zero     := '1';

        -- mantissa right shifting and exponent decrementing
        for i in 7 downto 0 loop
            if ( mantissa(7) = '1' ) then
                zero := '0';
                exit;
            else
                mantissa := mantissa(6 downto 0) & '0';
                exponent := exponent - 1;
            end if;
        end loop;
        if ( zero = '1' ) then
            exponent := (others => '0');
        end if;
        o_float <= '0' & exponent & mantissa(6 downto 0) & X"0000";
    end if;
    end process;

end architecture;
