--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 2-port RAM (1 read port and 1 write port)
-- - latency: 1 clock cycle
-- - Read-During-Write (RDW): new data
-- - register wdata through g_WREG_N registers
entity ram_1r1w_wreg is
generic (
    g_DATA_WIDTH : positive := 8;
    g_ADDR_WIDTH : positive := 8;
    g_WREG_N : natural := 1;
    g_RAMSTYLE : string := "no_rw_check"--;
);
port (
    i_waddr     : in    std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    i_wdata     : in    std_logic_vector(g_DATA_WIDTH-1 downto 0);
    i_we        : in    std_logic;

    i_raddr     : in    std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    o_rdata     : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);

    i_clk       : in    std_logic--;
);
end entity;

architecture arch of ram_1r1w_wreg is

    type waddr_t is array (natural range <>) of std_logic_vector(i_waddr'range);
    type wdata_t is array (natural range <>) of std_logic_vector(i_wdata'range);

    signal waddr : waddr_t(g_WREG_N downto 0);
    signal wdata : wdata_t(g_WREG_N downto 0);
    signal we : std_logic_vector(g_WREG_N downto 0) := (others => '0');

    signal rdata, rdata_rdw : std_logic_vector(o_rdata'range);
    signal rdw : std_logic := '0';

begin

    e_ram : entity work.ram_1r1w
    generic map (
        g_ADDR_WIDTH => g_ADDR_WIDTH,
        g_DATA_WIDTH => g_DATA_WIDTH,
        g_RDW_X => true,
        g_RAMSTYLE => g_RAMSTYLE--,
    )
    port map (
        i_waddr => waddr(g_WREG_N),
        i_wdata => wdata(g_WREG_N),
        i_we => we(g_WREG_N),
        i_wclk => i_clk,

        i_raddr => i_raddr,
        i_re => '1',
        o_rdata => rdata,
        i_rclk => i_clk--,
    );

    waddr(0) <= i_waddr;
    wdata(0) <= i_wdata;
    we(0) <= i_we;

    process(i_clk)
    begin
    if rising_edge(i_clk) then
        waddr(g_WREG_N downto 1) <= waddr(g_WREG_N-1 downto 0);
        wdata(g_WREG_N downto 1) <= wdata(g_WREG_N-1 downto 0);
        we(g_WREG_N downto 1) <= we(g_WREG_N-1 downto 0);

        rdata_rdw <= (others => '0');
        rdw <= '0';
        for i in g_WREG_N downto 0 loop
            if ( we(i) = '1' and waddr(i) = i_raddr ) then
                rdata_rdw <= wdata(i);
                rdw <= '1';
            end if;
        end loop;
    end if;
    end process;

    o_rdata <= rdata_rdw when ( rdw = '1' ) else rdata;

end architecture;
