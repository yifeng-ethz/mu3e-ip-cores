--

library ieee;
use std.env.finish;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

entity tb_ff_sync is
end entity;

architecture arch of tb_ff_sync is

    constant CLK_MHZ : integer := 1000; -- MHz
    signal clk, reset_n : std_logic := '0';
    signal input1, input2, input3, output1, output2, output3 : std_logic_vector(3 downto 0);

begin

    clk <= not clk after (0.5 us / CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / CLK_MHZ);

    e_ff_sync_1 : entity work.ff_sync
    generic map (
        N => 1,
        W => input1'length--,
    )
    port map (
        i_d       => input1,
        o_q       => output1,
        i_reset_n => reset_n,
        i_clk     => clk--,
    );

    e_ff_sync_2 : entity work.ff_sync
    generic map (
        N => 2,
        W => input2'length--,
    )
    port map (
        i_d       => input2,
        o_q       => output2,
        i_reset_n => reset_n,
        i_clk     => clk--,
    );

    e_ff_sync_3 : entity work.ff_sync
    generic map (
        N => 3,
        W => input3'length--,
    )
    port map (
        i_d       => input3,
        o_q       => output3,
        i_reset_n => reset_n,
        i_clk     => clk--,
    );

    process(clk, reset_n)
    begin
        if ( reset_n /= '1' ) then
            input1 <= (others => '0');
            input2 <= (others => '0');
            input3 <= (others => '0');
            --
        elsif rising_edge(clk) then
            input1 <= input1 + '1';
            input2 <= input2 + '1';
            input3 <= input3 + '1';
        end if;
    end process;

    process
    begin
        wait until ( output3 = (output3'range => '1') );

        assert (output1 = input1 - 1) report "FAIL" severity failure;
        assert (output2 = input2 - 2) report "FAIL" severity failure;
        assert (output3 = input3 - 3) report "FAIL" severity failure;

        report "DONE";
        finish;
    end process;

end architecture;
