library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity tb_zero_suppression is
end entity;

architecture rtl of tb_zero_suppression is

    signal clk          : std_logic := '1';
    signal reset_n      : std_logic;
    signal data_in      : work.mu3e.link32_t := work.mu3e.LINK32_IDLE;
    signal data_out     : work.mu3e.link32_t := work.mu3e.LINK32_IDLE;

    signal ena_subh_suppress : std_logic := '1';
    signal ena_head_suppress : std_logic := '1';

begin

    clk     <= not clk after (500 ns / 50);
    reset_n <= '0', '1' after 30 ns;

    process
    begin
        wait;
    end process;

    zero_suppression_inst: entity work.zero_suppression
    port map (
        i_ena_subh_suppression => ena_subh_suppress,
        i_ena_head_suppression => ena_head_suppress,
        i_data                 => work.mu3e.to_link(data_in.data,data_in.datak),
        o_data                 => data_out,
        i_reset_n              => reset_n,
        i_clk                  => clk--,
    );

end architecture;