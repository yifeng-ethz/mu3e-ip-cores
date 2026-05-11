--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity util_tb is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 1000.0--;
);
end entity;

use work.util_slv.all;

architecture arch of util_tb is

    signal test2 : slv2_array_t(3 downto 0) := ( "11", "10", "01", "11" );
    signal test3 : slv3_array_t(3 downto 0) := ( "111", "110", "101", "100" );

begin

    assert ( work.util.SIMULATION = true ) severity failure;

    process
    begin
        report "D [util_tb] SIMULATION = " & boolean'image(work.util.SIMULATION);
        if work.util.SIMULATION then
            report "OK"; else report "ERROR" severity error;
        end if;

        report "D [util_tb] to_slv(test2) = " & work.util.to_string(to_slv(test2));
        if ( to_slv(test2) = "11100111" ) then
            report "OK"; else report "ERROR" severity error;
        end if;

        report "D [util_tb] to_slv(test3) = " & work.util.to_string(to_slv(test3));
        if ( to_slv(test3) = "111110101100" ) then
            report "OK"; else report "ERROR" severity error;
        end if;

        report "D [util_tb] one_hot_to_index(""1"") = " & work.util.to_string(work.util.one_hot_to_index("1"));
        if ( work.util.one_hot_to_index("1") = "0" ) then
            report "OK"; else report "ERROR" severity error;
        end if;

        report "D [util_tb] one_hot_to_index(""0010"") = " & work.util.to_string(work.util.one_hot_to_index("0010"));
        if ( work.util.one_hot_to_index("0010") = "10" ) then
            report "OK"; else report "ERROR" severity error;
        end if;

        wait;
    end process;

end architecture;
