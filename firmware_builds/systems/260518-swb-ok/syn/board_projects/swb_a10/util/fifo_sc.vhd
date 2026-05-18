--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

--
-- FIFO
-- - Single Clock
-- - Fall-Through (Show-Ahead)
--
entity fifo_sc is
generic (
    g_DATA_WIDTH : positive := 8;
    g_ADDR_WIDTH : positive := 8--;
);
port (
    i_we        : in    std_logic;
    i_wdata     : in    std_logic_vector(g_DATA_WIDTH-1 downto 0);
    o_wfull     : out   std_logic;

    i_rack      : in    std_logic;
    o_rdata     : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);
    o_rempty    : out   std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

library ieee;
use ieee.numeric_std.all;

architecture arch of fifo_sc is

    subtype addr_t is std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    subtype ptr_t is std_logic_vector(g_ADDR_WIDTH downto 0);

    constant XOR_FULL : ptr_t := "10" & ( g_ADDR_WIDTH-2 downto 0 => '0' );

    signal we, rack : std_logic;
    signal wfull, rempty : std_logic;
    signal wptr, wptr_next, rptr, rptr_next : ptr_t := (others => '0');

    signal rdata : std_logic_vector(g_DATA_WIDTH-1 downto 0);

    signal rdw : std_logic;
    signal rdata_rdw : std_logic_vector(g_DATA_WIDTH-1 downto 0);

begin

    -- psl assert always ( we = '1' |=> rempty = '0' ) @ i_clk ;



    o_wfull <= wfull;
    o_rempty <= rempty;

    -- check for underflow and overflow
    we <= ( i_we and not wfull );
    rack <= ( i_rack and not rempty );

    wptr_next <= wptr + ("" & we);
    rptr_next <= rptr + ("" & rack);

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        wptr <= (others => '0');
        wfull <= '1';
        rptr <= (others => '0');
        rempty <= '1';
        rdw <= '0';
        --
    elsif rising_edge(i_clk) then
        -- advance pointers
        wptr <= wptr_next;
        rptr <= rptr_next;

        wfull <= work.util.to_std_logic( (rptr_next xor wptr_next) = XOR_FULL );
        rempty <= work.util.to_std_logic( rptr_next = wptr_next );

        -- read during write
        rdw <= we and work.util.to_std_logic( rptr_next = wptr );
        rdata_rdw <= i_wdata;
        --
    end if; -- rising_edge
    end process;

    e_ram : entity work.ram_1r1w
    generic map (
        g_DATA_WIDTH => g_DATA_WIDTH,
        g_ADDR_WIDTH => g_ADDR_WIDTH--,
    )
    port map (
        i_waddr         => wptr(addr_t'range),
        i_we            => we,
        i_wdata         => i_wdata,
        i_wclk          => i_clk,

        i_raddr         => rptr_next(addr_t'range),
        o_rdata         => rdata,
        i_rclk          => i_clk--,
    );

    o_rdata <=
        (others => '-') when ( rempty = '1' ) else
        rdata_rdw when ( rdw = '1' ) else
        rdata;

end architecture;
