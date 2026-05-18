-- receive run control signals from FEBs
-- TODO more than one FEB

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

entity run_control is
generic (
    -- number of links
    g_LINKS : positive := 4--;
);
port (
    i_reset_ack_seen_n      : in  std_logic;
    i_reset_run_end_n       : in  std_logic;
    i_buffers_empty         : in  std_logic_vector(31 downto 0);
    i_aligned               : in  std_logic_vector(31 downto 0); -- word alignment achieved
    i_data                  : in  work.mu3e.link32_array_t(g_LINKS-1 downto 0); -- optical from frontend board
    i_link_enable           : in  std_logic_vector(31 downto 0);
    i_addr                  : in  std_logic_vector(31 downto 0);
    i_run_number            : in  std_logic_vector(23 downto 0);
    o_run_number            : out std_logic_vector(31 downto 0);
    o_runNr_ack             : out std_logic_vector(31 downto 0);
    o_run_stop_ack          : out std_logic_vector(31 downto 0);
    o_buffers_empty         : out std_logic_vector(31 downto 0);
    o_feb_merger_timeout    : out std_logic_vector(31 downto 0);
    o_time_counter          : out std_logic_vector(63 downto 0);

    -- clk / reset
    i_reset_n               : in  std_logic;
    i_clk                   : in  std_logic--;
);
end entity;

architecture rtl of run_control is

    signal FEB_status : slv32_array_t(g_LINKS-1 downto 0);
    signal feb_merger_timeouts : std_logic_vector(g_LINKS-1 downto 0);
    signal CNT_feb_merger_timeouts : unsigned(31 downto 0);
    signal runNr_ack : std_logic_vector(31 downto 0);
    signal addr : integer;

BEGIN

    o_feb_merger_timeout <= std_logic_vector(CNT_feb_merger_timeouts);

    addr <= to_integer(unsigned(i_addr));

    o_runNr_ack <= runNr_ack;

    g_link_listener : for i in g_LINKS-1 downto 0 generate
    begin
        e_link_listener : entity work.run_control_link_listener
        port map (
            i_aligned               => i_aligned(i),
            i_data                  => i_data(i).data,
            i_datak                 => i_data(i).datak,
            o_merger_timeout        => feb_merger_timeouts(i),
            o_FEB_status            => FEB_status(i)(25 downto 0),
            i_reset_ack_seen_n      => i_reset_ack_seen_n,
            i_reset_run_end_n       => i_reset_run_end_n,
            i_clk                   => i_clk--,
        );
    end generate;

    feb_merger_timeout : process(i_clk, i_reset_ack_seen_n, i_reset_run_end_n)
    begin
    if ( i_reset_ack_seen_n = '0' ) then
        CNT_feb_merger_timeouts  <= (others => '0');
    elsif rising_edge(i_clk) then
        if( or_reduce(feb_merger_timeouts)='1' ) then
            CNT_feb_merger_timeouts <= CNT_feb_merger_timeouts + 1;
        end if;
    end if;
    end process;

    --! time counter for getting the current time one the SWB
    --! reset if one of the FEBs send back the runNr at start of run
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        o_time_counter <= (others => '0');
    elsif rising_edge(i_clk) then
        o_time_counter <= o_time_counter + '1';
        if ( or_reduce(runNr_ack) = '1' ) then
            o_time_counter <= (others => '0');
        end if;
    end if;
    end process;

    process(i_clk)
    begin
    if rising_edge(i_clk) then
        if ( i_reset_ack_seen_n = '0' ) then
            o_run_number                    <= (others => '0');
            runNr_ack                     <= (others => '0');
        end if;

        if ( i_reset_run_end_n = '0' ) then
            o_run_stop_ack                  <= (others => '0');
        end if;

        if ( and_reduce(i_buffers_empty) = '1' ) then
            o_buffers_empty         <= (0 => '1', others => '0');
        else
            o_buffers_empty         <= (others => '0');
        end if;

        for J in 0 to g_LINKS-1 loop
            if ( FEB_status(j)(25) = '1' and FEB_status(J)(23 downto 0) = i_run_number ) then
                runNr_ack(J)      <= '1';
            else
                runNr_ack(J)      <= '0';
            end if;

            o_run_stop_ack(J)       <= FEB_status(J)(24);
        end loop;

        if ( 0 <= addr and addr < g_LINKS ) then
            o_run_number <= "000000" & FEB_status(addr)(25 downto 0);
        else
            o_run_number <= (others => '0');
        end if;
    end if;
    end process;

end architecture;
