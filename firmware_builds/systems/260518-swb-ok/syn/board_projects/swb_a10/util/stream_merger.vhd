--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

-- merge packets delimited by SOP and EOP from N input streams
entity stream_merger is
generic (
    W : positive := 32;
    N : positive--;
);
port (
    -- input streams
    i_rdata     : in    std_logic_vector(N*W-1 downto 0);
    i_rsop      : in    std_logic_vector(N-1 downto 0); -- start of packet (SOP)
    i_reop      : in    std_logic_vector(N-1 downto 0); -- end of packet (EOP)
    i_rempty    : in    std_logic_vector(N-1 downto 0);
    o_rack      : out   std_logic_vector(N-1 downto 0); -- read ACK

    -- output stream
    o_wdata     : out   std_logic_vector(W-1 downto 0);
    o_wsop      : out   std_logic; -- SOP
    o_weop      : out   std_logic; -- EOP
    i_wfull     : in    std_logic;
    o_we        : out   std_logic; -- write enable

    o_index     : out   std_logic_vector(N-1 downto 0);
    o_busy      : out   std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of stream_merger is

    -- one hot signal indicating current active input stream
    signal index : std_logic_vector(N-1 downto 0) := (0 => '1', others => '0');

    -- SOP mark
    signal busy : std_logic;

begin

    -- set rack for current not empty input
    o_rack <=
        (others => '0') when ( i_wfull = '1' or i_reset_n = '0' ) else
        not i_rempty and index;

    o_busy <= busy;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        o_wdata <= (others => '0');
        o_wsop <= '0';
        o_weop <= '0';
        o_we <= '0';
        o_index <= (others => '0');

        index <= (0 => '1', others => '0');
        busy <= '0';
        --
    elsif rising_edge(i_clk) then
        assert (true
            and work.util.count_bits(index) = 1
        ) severity error;

        for i in index'range loop
            if ( index(i) = '1' ) then
                o_wdata <= i_rdata((i+1)*W-1 downto i*W);
            end if;
        end loop;
        o_wsop <= or_reduce(i_rsop and index);
        o_weop <= or_reduce(i_reop and index);
        o_we <= '0';
        o_index <= (others => '0');

        if ( or_reduce(i_rempty and index) = '0' and i_wfull = '0' ) then
            -- write data
            o_we <= '1';
            o_index <= index;

            if ( or_reduce(i_rsop and index) = '1' ) then
                -- set SOP mark
                busy <= '1';
            end if;

            if ( or_reduce(i_reop and index) = '1' ) then
                -- reset SOP mark
                busy <= '0';
                -- go to next index
                index <= work.util.round_robin_next(index, not i_rempty);
            end if;
        elsif ( busy = '0' ) then
            -- go to next index
            index <= work.util.round_robin_next(index, not i_rempty);
        end if;

        --
    end if;
    end process;

end architecture;
