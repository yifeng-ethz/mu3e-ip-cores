----------------------------------------------------------------------------
-- Reset logic
--
-- Niklaus Berger, Heidelberg University
-- nberger@physi.uni-heidelberg.de
--
--
--
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

use work.a10_pcie_registers.all;

entity reset_logic is
port (
    i_reset_register    : in    std_logic_vector(31 downto 0);
--    i_reset_reg_written : in    std_logic;

    o_resets_n          : out   std_logic_vector(31 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture rtl of reset_logic is

    signal reset_register : std_logic_vector(i_reset_register'range);
    signal resets_n, resets0, resets1, resets2, resets3, resets4 : std_logic_vector(o_resets_n'range);

begin

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        reset_register  <= (others => '0');
        o_resets_n      <= (others => '0');
        resets_n        <= (others => '0');
        resets0         <= (others => '0');
        resets1         <= (others => '0');
        resets2         <= (others => '0');
        resets3         <= (others => '0');
        resets4         <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        reset_register <= i_reset_register;

        o_resets_n <= resets_n;

        resets_n <= not ( resets0 or resets1 or resets2 or resets3 or resets4 );

        resets0 <= (others => '0');
        resets1 <= resets0;
        resets2 <= resets1;
        resets3 <= resets2;
        resets4 <= resets3;

        if ( reset_register(RESET_BIT_ALL) = '1'
--            and reset_reg_written <= '1'
        ) then
            resets0 <= (others => '1');
        end if;

        for i in reset_register'range loop
            if ( reset_register(i) = '1'
--                and reset_reg_written <= '1'
            ) then
                resets0(i) <= '1';
            end if;
        end loop;

    end if;
    end process;

end architecture;
