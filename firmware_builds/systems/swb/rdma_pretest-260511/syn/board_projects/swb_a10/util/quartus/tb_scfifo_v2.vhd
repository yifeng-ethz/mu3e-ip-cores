--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity tb_scfifo_v2 is
end entity;

architecture TB of tb_scfifo_v2 is

    signal reset_n : std_logic;
    signal clk : std_logic := '0';
    constant CLK_MHZ : real := 250.0;

    signal data, q0, q1 : std_logic_vector(7 downto 0);
    signal wen0, wen1, re0, re1, empty0, empty1, full0, full1 : std_logic;

begin

    clk <= not clk after (0.5 us / CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / CLK_MHZ);

    write_fifo : process(clk, reset_n)
    begin
    if ( reset_n /= '1' ) then
        wen0 <= '0';
        wen1 <= '0';
        data <= (others => '0');
    elsif rising_edge(clk) then
        data <= data + '1';
        wen0 <= not full0;
        wen1 <= not full1;
    end if;
    end process;

    read_fifo : process(clk, reset_n)
    begin
    if ( reset_n /= '1' ) then
        re0 <= '0';
        re1 <= '0';
    elsif rising_edge(clk) then
        re0 <= not empty0;
        re1 <= not empty1;
    end if;
    end process;

    dut0 : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 12,
        g_DATA_WIDTH => data'length--,
    )
    port map (
        i_we        => wen0,
        i_wdata     => data,
        o_wfull     => full0,

        i_rack      => re0,
        o_rdata     => q0,
        o_rempty    => empty0,

        i_reset_n   => reset_n,
        i_clk       => clk--,
    );

    dut1 : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => 12,
        g_DATA_WIDTH => data'length--,
    )
    port map (
        i_we        => wen1,
        i_wdata     => data,
        o_wfull     => full1,

        i_rack      => re1,
        o_rdata     => q1,
        o_rempty    => empty1,

        i_reset_n   => reset_n,
        i_clk       => clk--,
    );

end architecture;
