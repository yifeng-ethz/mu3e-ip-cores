-- receive run control signals from FEBs
-- TODO more than one FEB


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mudaq.all;

entity run_control_link_listener is
port (
    i_reset_ack_seen_n  : in    std_logic;
    i_reset_run_end_n   : in    std_logic;
    i_aligned           : in    std_logic; -- word alignment achieved
    i_data              : in    std_logic_vector(31 downto 0); -- optical from frontend board
    i_datak             : in    std_logic_vector(3  downto 0);
    o_merger_timeout    : out   std_logic;
    o_FEB_status        : out   std_logic_vector(25 downto 0);

    -- receive clock (156.25 MHz)
    i_clk               : in    std_logic--;
);
end entity;

architecture rtl of run_control_link_listener is

    signal run_prep_acknowledge_received : std_logic;
    signal end_of_run_received : std_logic;
    signal run_number : std_logic_vector(23 downto 0);

begin

    o_merger_timeout <= '1' when ( i_data = MERGER_TIMEOUT ) else '0';

    process(i_clk, i_reset_run_end_n, i_reset_ack_seen_n, i_data, i_aligned)
    begin
    if ( i_reset_ack_seen_n = '0' or i_aligned = '0' ) then
        run_prep_acknowledge_received    <= '0';
        run_number                       <= (others => '0');
    elsif ( i_reset_run_end_n = '0' or i_aligned = '0' ) then
        end_of_run_received              <= '0';
    elsif rising_edge(i_clk) then
        o_FEB_status <=
            run_prep_acknowledge_received &
            end_of_run_received &
            run_number;

        if ( i_data = RUN_END and i_datak = RUN_END_DATAK ) then
            run_prep_acknowledge_received   <= '0';
            end_of_run_received             <= '1';

        elsif ( i_data(7 downto 0) = run_prep_acknowledge(7 downto 0) and i_datak = run_prep_acknowledge_datak ) then
            run_prep_acknowledge_received   <= '1';
            end_of_run_received             <= '0';
            run_number                      <= i_data(31 downto 8);
        end if;
    end if;
    end process;

end architecture;
