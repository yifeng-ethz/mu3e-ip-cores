--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity word_rate is
generic (
    g_CLK_MHZ : real := 125.0--;
);
port (
    i_valid : in std_logic;
    o_rate : out std_logic_vector(31 downto 0);
    i_reset_n : in std_logic;
    i_clk : in std_logic--;
);
end entity;

architecture rtl of word_rate is

    signal counter : std_logic_vector(31 downto 0);
    signal time_counter : std_logic_vector(31 downto 0);
    signal en : std_logic;

begin

    process(i_clk)
    begin
    if rising_edge(i_clk) then
        if ( i_reset_n /= '1' ) then
            o_rate <= (others => '0');
            counter <= (others => '0');
            time_counter <= (others => '0');
            en <= '0';
            --
        else
            en <= i_valid;
            if ( time_counter = integer(g_CLK_MHZ*1000000.0) ) then
                o_rate <= counter;
                counter <= (others => '0');
                time_counter <= (others => '0');
            else
                if ( en = '1' ) then
                    counter <= counter + '1';
                end if;
                time_counter <= time_counter + '1';
            end if;
        end if;
    end if;
    end process;

end architecture;
