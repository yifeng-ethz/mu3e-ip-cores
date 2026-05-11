--

library ieee;
use ieee.std_logic_1164.all;

-- fifo based on registers
entity fifo_reg is
generic (
    g_DATA_WIDTH : positive := 32;
    g_N : positive := 1--;
);
port (
    i_we        : in    std_logic;
    i_wdata     : in    std_logic_vector(g_DATA_WIDTH-1 downto 0);
    -- wfull_n = not wfull
    o_wfull     : out   std_logic;
    o_wfull_n   : out   std_logic;

    i_rack      : in    std_logic;
    o_rdata     : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);
    -- rvalid = not rempty = rempty_n
    o_rvalid    : out   std_logic;
    o_rempty    : out   std_logic;
    o_rempty_n  : out   std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of fifo_reg is

    signal we : std_logic;
    signal wdata : std_logic_vector(i_wdata'range);
    signal wfull : std_logic;

    type rdata_array_t is array (natural range <>) of std_logic_vector(o_rdata'range);
    signal rdata : rdata_array_t(0 to g_N);
    signal rvalid : std_logic_vector(0 to g_N);

    -- do not infer ram
    attribute RAMSTYLE : string;
    attribute RAMSTYLE of rdata : signal is "LOGIC";

begin

    we <= i_we;
    wdata <= i_wdata when ( we = '1' ) else (others => '-');
    wfull <= '1' when ( i_reset_n /= '1' ) else rvalid(g_N);
    o_wfull <= wfull;
    o_wfull_n <= not wfull;

    -- rdata(0) is the head of the fifo
    o_rdata <= rdata(0);
    o_rvalid <= rvalid(0);
    o_rempty <= not rvalid(0);
    o_rempty_n <= rvalid(0);

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        rdata <= (others => (others => '-'));
        rvalid <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        -- read
        if ( i_rack = '1' and rvalid(0) = '1' ) then
            -- shift left
            rdata(0 to g_N-1) <= rdata(1 to g_N);
            rdata(g_N) <= (others => '-');
            rvalid(0 to g_N-1) <= rvalid(1 to g_N);
            rvalid(g_N) <= '0';
        end if;

        -- write
        if ( i_rack = '1' and rvalid(0) = '1' ) then
            -- write during read
            -- copy wdata into last valid rdata
            for i in 0 to g_N loop
                -- NOTE: wfull = '1' when rvalid(g_N) = '1'
                if ( -- ( i = g_N and rvalid(g_N) = '1' ) or
                     ( i < g_N and rvalid(i to i+1) = "10" ) ) then
                    rdata(i) <= wdata;
                    rvalid(i) <= we;
                end if;
            end loop;
        else
            -- copy wdata into first empty rdata
            for i in 0 to g_N loop
                if ( (i = 0 and rvalid(0) = '0') or
                     (i > 0 and rvalid(i-1 to i) = "10") ) then
                    rdata(i) <= wdata;
                    rvalid(i) <= we;
                end if;
            end loop;
        end if;
    end if;
    end process;

end architecture;
