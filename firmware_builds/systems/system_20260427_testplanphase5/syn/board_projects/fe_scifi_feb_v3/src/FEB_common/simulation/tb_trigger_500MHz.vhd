library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;

entity tb_trigger_500MHz is
end entity;

architecture arch of tb_trigger_500MHz is

    signal clk, clk_fast, reset_n : std_logic := '0';
    signal trigger : std_logic_vector(3 downto 0);
    signal cnt : std_logic_vector(31 downto 0);
    signal run_state_125 : run_state_t;

begin

    clk     <= not clk after 8 ns;        -- 125MHz
    clk_fast<= not clk_fast after 2 ns;   -- 500MHz
    reset_n <= '0', '1' after 1.0 us;
    run_state_125 <= RUN_STATE_SYNC, RUN_STATE_RUNNING after 2.0 us;

    e_trigger : entity work.trigger_500MHz
    generic map (
        g_N     => 4,
        g_ToT   => "0001"--,
    )
    port map (
        o_trig          => open,
        o_trig_en       => open,
        i_trigger       => trigger,
        i_run_state_125 => run_state_125,
        i_reset_n       => reset_n,
        i_clk_fast      => clk_fast,
        i_clk           => clk--,
    );

    p_gen_trigger : process(clk_fast, reset_n)
    begin
    if ( reset_n = '0' ) then
        cnt <= (others => '0');
    elsif rising_edge(clk_fast) then
        cnt <= cnt + '1';
        trigger(0) <= cnt(1);
        trigger(1) <= cnt(2);
        trigger(2) <= cnt(1);
        trigger(3) <= cnt(2);
    end if;
    end process;

end architecture;
