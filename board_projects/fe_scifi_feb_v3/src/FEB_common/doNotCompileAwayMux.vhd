--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity doNotCompileAwayMux is
generic (
    WIDTH_g : positive := 1--;
);
port (
    i_clk                   : in  std_logic;
    i_reset_n               : in  std_logic;
    i_doNotCompileAway      : in  std_logic_vector(WIDTH_g downto 0);
    o_led                   : out std_logic--;
);
end entity;

architecture rtl of doNotCompileAwayMux is

    signal counter          : unsigned(16 downto 0):= (others => '0');
    signal doNotCompileAway : std_logic_vector(WIDTH_g downto 0);

begin

    e_doNotCompileAway : entity work.ff_sync
    generic map ( W => i_doNotCompileAway'length )
    port map (
        i_d => i_doNotCompileAway, o_q => doNotCompileAway,
        i_reset_n => i_reset_n, i_clk => i_clk--,
    );

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        counter <= (others => '0');
    elsif rising_edge(i_clk) then
        if(counter = WIDTH_g) then
            counter <= (others => '0');
        else
            counter <= counter + 1;
        end if;
        o_led <= doNotCompileAway(to_integer(counter));
    end if;
    end process;

end architecture;
