library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mp_sorter_datagen_tb is
end entity;

architecture rtl of mp_sorter_datagen_tb is

    constant CLK_MHZ : positive := 125;
    signal clk, reset_n : std_logic := '0';
    signal reset : std_logic;


    signal fifo_wdata : std_logic_vector(35 downto 0);
    signal fifo_write : std_logic;
    signal counter    : std_logic_vector(31 downto 0);
    signal counter_int: unsigned(31 downto 0);

begin

    clk <= not clk after (500 ns / CLK_MHZ);
    reset_n <= '0', '1' after 32 ns;
    reset <= not reset_n;
    counter <= std_logic_vector(counter_int);

    e_mp_sorter_datagen : entity work.mp_sorter_datagen
    port map (
        i_reset_n                 => reset_n,
        i_clk                     => clk,
        i_running                 => '1',
        i_global_ts(31 downto 0)  => std_logic_vector(counter_int),--counter,
        i_global_ts(63 downto 32) => (others => '0'),
        i_control_reg             => (31 => '1', others => '0'),
        i_seed                    => "11001111101100010101110100100010011010110001101011110100101000000",
        o_fifo_wdata              => fifo_wdata,
        o_fifo_write              => fifo_write--,
    );

    process
    begin
        counter <= (others => '0');
        counter_int <= (others => '0');
        wait until ( reset_n = '1' );
        
        for i in 0 to 80000 loop
            wait until rising_edge(clk);
            counter_int <= counter_int + 1;
        end loop;
        wait;
    end process;

end architecture;