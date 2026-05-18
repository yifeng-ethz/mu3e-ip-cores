--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity tb_farm_coordinate_converter is
end entity;

architecture rtl of tb_farm_coordinate_converter is

    constant CLK_PERIOD: time := 10 ns;

    signal reset_n  : std_logic := '0';
    signal clk      : std_logic := '0';
    signal chip     : std_logic_vector(7 downto 0);
    signal row      : std_logic_vector(7 downto 0);
    signal col      : std_logic_vector(7 downto 0);
    signal ena      : std_logic;
    signal x        : std_logic_vector(31 downto 0);
    signal y        : std_logic_vector(31 downto 0);
    signal z        : std_logic_vector(31 downto 0);
    signal oena     : std_logic;
    signal ramaddr  : std_logic_vector(7+4 downto 0);
    signal ramdata  : std_logic_vector(31 downto 0);
    signal ramwren  : std_logic;

begin

    dut : entity work.farm_coordinate_converter
    generic map (
        NCHIPS  => 252
    )
    port map (
        i_chip      => chip,
        i_row       => row,
        i_col       => col,
        i_ena       => ena,
        o_x         => x,
        o_y         => y,
        o_z         => z,
        o_ena       => oena,
        i_ramaddr   => ramaddr,
        i_ramdata   => ramdata,
        i_ramwren   => ramwren,
        i_reset_n   => reset_n,
        i_clk       => clk--,
    );

    clkgen : process
    begin
        wait for CLK_PERIOD/2;
            clk <= not clk;
    end process;

    resetgen:process
    begin
    reset_n <= '0';
    wait for 10 * CLK_PERIOD;
    reset_n <= '1';
    wait;
    end process;

    rawmritegen:process
    begin
        ramdata <= (others => '0');
        ramaddr <= (others => '0');
        ramwren <= '0';
    wait for 11 * CLK_PERIOD;
        ramdata <= X"C2C80000"; -- -100
        ramaddr <= (others => '0'); -- sx
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"C2CA0000"; -- -101
        ramaddr <= ramaddr + '1'; -- sy
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"C2CC0000"; -- -102
        ramaddr <= ramaddr + '1'; -- sz
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"41200000"; -- 10
        ramaddr <= ramaddr + '1'; -- cx
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"00000000"; -- 0
        ramaddr <= ramaddr + '1'; -- cy
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"00000000"; -- 0
        ramaddr <= ramaddr + '1'; -- cz
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"00000000"; -- 0
        ramaddr <= ramaddr + '1'; -- cx
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"41a00000"; -- 20
        ramaddr <= ramaddr + '1'; -- cy
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"00000000"; -- 0
        ramaddr <= ramaddr + '1'; -- cz
        ramwren <= '1';
    -- Second chip
    wait for CLK_PERIOD;
        ramdata <= X"42C80000"; -- 100
        ramaddr <= "00000001" & "0000"; -- sx
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"42CA0000"; -- 101
        ramaddr <= ramaddr + '1'; -- sy
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"42CC0000"; -- 102
        ramaddr <= ramaddr + '1'; -- sz
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"C1200000"; -- -10
        ramaddr <= ramaddr + '1'; -- cx
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"00000000"; -- 0
        ramaddr <= ramaddr + '1'; -- cy
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"00000000"; -- 0
        ramaddr <= ramaddr + '1'; -- cz
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"00000000"; -- 0
        ramaddr <= ramaddr + '1'; -- cx
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"C1a00000"; -- -20
        ramaddr <= ramaddr + '1'; -- cy
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= X"00000000"; -- 0
        ramaddr <= ramaddr + '1'; -- cz
        ramwren <= '1';
    wait for CLK_PERIOD;
        ramdata <= (others => '0');
        ramaddr <= (others => '0');
        ramwren <= '0';
    wait;
    end process;

    inputgen:process
    begin
        chip <= (others => '1');
        row  <= (others => '0');
        col  <= (others => '0');
        ena  <= '0';
    wait for 50 * CLK_PERIOD;
        chip <= (others => '0');
        row  <= X"11";
        col  <= X"01";
        ena  <= '1';
    wait for CLK_PERIOD;
        chip <= (others => '1');
        row  <= (others => '0');
        col  <= (others => '0');
        ena  <= '0';
    end process;

end architecture;
