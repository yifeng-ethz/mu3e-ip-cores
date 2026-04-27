--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 2-port RAM (1 read port and 1 write port)
entity ram_1r1w is
generic (
    g_DATA_WIDTH : positive := 8;
    g_ADDR_WIDTH : positive := 8;
    g_RDW_X : boolean := false;
    -- `ramstyle` attribute
    -- - quartus:
    --   - see "Quartus Help / ramstyle VHDL Synthesis Attribute"
    --   - values: "no_rw_check", "logic", "M9K", "M10K", "M20K", "M144K" or "MLAB"
    --   - e.g. use "no_rw_check, MLAB" to implement in MLABs
    g_RAMSTYLE : string := "no_rw_check"--;
);
port (
    i_waddr     : in    std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    i_wdata     : in    std_logic_vector(g_DATA_WIDTH-1 downto 0);
    i_we        : in    std_logic;
    i_wclk      : in    std_logic;

    i_raddr     : in    std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    i_re        : in    std_logic := '1';
    o_rdata     : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);
    i_rclk      : in    std_logic--;
);
end entity;

architecture arch of ram_1r1w is

    type ram_t is array (natural range <>) of std_logic_vector(g_DATA_WIDTH-1 downto 0);
    signal ram : ram_t(2**g_ADDR_WIDTH-1 downto 0);
    attribute ramstyle : string;
    attribute ramstyle of ram : signal is g_RAMSTYLE;

begin

    process(i_wclk)
    begin
    if rising_edge(i_wclk) then
        if ( i_we = '1' ) then
            ram(to_integer(unsigned(i_waddr))) <= i_wdata;
        end if;
    end if;
    end process;

    process(i_rclk)
    begin
    if rising_edge(i_rclk) then
        o_rdata <= (others => 'X');
        if ( i_re = '1' ) then
            o_rdata <= ram(to_integer(unsigned(i_raddr)));
        end if;
        if ( g_RDW_X and i_re = '1' and i_we = '1' and i_raddr = i_waddr ) then
            -- read during write
            o_rdata <= (others => 'X');
        end if;
    end if;
    end process;

end architecture;
