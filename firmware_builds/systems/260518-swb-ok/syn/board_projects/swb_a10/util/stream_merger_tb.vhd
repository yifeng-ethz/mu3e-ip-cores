--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity stream_merger_tb is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 100.0--;
);
end entity;

use work.util_slv.all;

architecture arch of stream_merger_tb is

    signal clk, reset_n, reset : std_logic := '0';

    signal DONE : std_logic_vector(0 downto 0) := (others => '0');

    -- number of links (streams)
    constant N : positive := 4;

    constant XXXX : std_logic_vector := X"XXXX"; -- empty cycle
    constant SOP : std_logic_vector := X"00BC";
    constant EOP : std_logic_vector := X"009C";

    -- N links with 32 entries per link
    signal links : slv16_array_t(0 to N*32-1) := (
          XXXX ,   XXXX ,   XXXX ,   XXXX ,
          XXXX ,    SOP ,   XXXX ,   XXXX ,
           SOP , X"BABE",   XXXX ,   XXXX ,
        X"CAFE", X"BABE",   XXXX ,   XXXX ,
           EOP ,    EOP ,    SOP ,   XXXX ,
          XXXX ,   XXXX , X"DEAD",   XXXX ,
          XXXX ,   XXXX , X"DEAD",   XXXX ,
          XXXX ,   XXXX ,   XXXX ,    SOP ,
          XXXX ,   XXXX ,   XXXX ,   XXXX ,
          XXXX ,   XXXX , X"DEAD", X"BEEF",
          XXXX ,   XXXX ,    EOP , X"BEEF",
          XXXX ,   XXXX ,   XXXX ,   XXXX ,
          XXXX ,   XXXX ,   XXXX ,    EOP ,
          XXXX ,   XXXX ,   XXXX ,   XXXX ,
        others => XXXX
    );

    signal offsets : integer_vector(N-1 downto 0) := ( others => 0 );

    signal rdata : std_logic_vector(N*XXXX'length-1 downto 0);
    signal rsop, reop, rempty, rack : std_logic_vector(N-1 downto 0);
    signal wdata : std_logic_vector(XXXX'length-1 downto 0);
    signal we : std_logic;
    signal index : std_logic_vector(N-1 downto 0);

begin

    clk <= not clk after (0.5 us / g_CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / g_CLK_MHZ);
    reset <= not reset_n;

    g_data : for i in N-1 downto 0 generate
    begin
        rdata((i+1)*XXXX'length-1 downto i*XXXX'length) <= links(offsets(i)*N+i);
        rsop(i) <= '1' when ( links(offsets(i)*N+i) = SOP ) else '0';
        reop(i) <= '1' when ( links(offsets(i)*N+i) = EOP ) else '0';
        rempty(i) <= '1' when ( is_x(links(offsets(i)*N+i)) ) else '0';
    end generate;

    e_stream_merger : entity work.stream_merger
    generic map (
        W => XXXX'length,
        N => N--,
    )
    port map (
        o_rack          => rack,
        i_rdata         => rdata,
        i_rsop          => rsop,
        i_reop          => reop,
        i_rempty        => rempty,

        o_wdata         => wdata,
        i_wfull         => '0',
        o_we            => we,

        o_index         => index,

        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

    process
    begin
        wait until rising_edge(reset_n);

        loop
            wait until rising_edge(clk);
            report "rdata = " & work.util.to_hstring(rdata);
            for i in N-1 downto 0 loop
                if ( (rack(i) = '1' or rempty(i) = '1') and offsets(i) < links'length/N-1 ) then
                    offsets(i) <= offsets(i) + 1;
                end if;
            end loop;
            exit when ( offsets = (N-1 downto 0 => links'length/N-1) );
        end loop;

        DONE(0) <= '1';
        wait;
    end process;

    process
        variable state : string(1 to 3) := "EOP";
    begin
        wait until rising_edge(reset_n);

        loop
            wait until rising_edge(clk) and we = '1';
            report "wdata(0x" & work.util.to_hstring(index) & ") = " & work.util.to_hstring(wdata);

            assert ( not is_X(wdata) )
                report "invalid data" severity failure;

            if ( state = "SOP" and wdata /= SOP and wdata /= EOP ) then -- data
                state := "SOP";
                --
            elsif ( state = "EOP" and wdata = SOP ) then
                state := "SOP";
            elsif ( state = "SOP" and wdata = SOP ) then
                report "unexpected SOP" severity failure;
            elsif ( state = "SOP" and wdata = EOP ) then
                state := "EOP";
            elsif ( state = "EOP" and wdata = EOP ) then
                report "unexpected EOP" severity failure;
            else
                report "unexpected wdata" severity failure;
            end if;

        end loop;

        --DONE(1) <= '1';
        wait;
    end process;

    process begin
        --rng.init(g_SEED);
        wait until ( and DONE );
        report work.util.SGR_FG_GREEN & "I [tb] SIMULATION DONE" & work.util.SGR_RESET;
        wait;
    end process;

    process begin
        wait for g_STOP_TIME_US * 1 us;
        assert ( and DONE )
            report work.util.SGR_FG_RED & "E [tb] SIMULATION NOT DONE" & work.util.SGR_RESET
            severity error;
        wait;
    end process;

end architecture;
