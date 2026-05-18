--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

--
-- counter memory (histogram)
-- - two 1r1w rams (no RDW check)
-- - no wait states (except for init)
-- - zero delay (RDW -> new data)
--
entity counter_memory is
generic (
    g_ADDR_WIDTH : positive := 8;
    g_DATA_WIDTH : positive := 8;
    g_OVERFLOW : boolean := false;
    g_RDW_X : boolean := true;
    g_WREG_N : natural := 1;
    g_RAMSTYLE : string := "no_rw_check"--;
);
port (
    -- write interface
    i_waddr     : in    std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    i_wdata     : in    std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others => '0');
    i_we        : in    std_logic := '0';
    -- wmode = 0 => [waddr] = wdata
    -- wmode = 1 => [waddr] += wdata
    i_wmode     : in    std_logic_vector(3 downto 0) := X"1";

    -- read interface
    i_raddr     : in    std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    o_rdata     : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);

    -- from reset to ready it takes 2^(g_ADDR_WIDTH-1) cycles
    o_ready     : out   std_logic;
    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of counter_memory is

    signal ready : std_logic;

    signal ram_waddr, ram_raddr : std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    signal wdata_q, ram_wdata, ram_rdata : std_logic_vector(g_DATA_WIDTH-1 downto 0);
    signal ram_we : std_logic;
    signal wmode_q : std_logic_vector(i_wmode'range);

    signal raddr_q : std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    signal rdata : std_logic_vector(g_DATA_WIDTH-1 downto 0);

begin

    o_ready <= ready;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        ready <= '0';
        ram_waddr <= (others => '0');
        wdata_q <= (others => '0');
        ram_we <= '1';
        wmode_q <= (others => '0');
        raddr_q <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        if ( ready = '1' ) then
            ram_waddr <= i_waddr;
            wdata_q <= i_wdata;
            ram_we <= i_we;
            wmode_q <= i_wmode;
            raddr_q <= i_raddr;
        elsif ( ram_waddr /= (ram_waddr'range => '1') ) then
            -- after reset waddr = 0, wdata = 0 and we = 1
            -- cycle through all addresses
            ram_waddr <= ram_waddr + 1;
        else
            -- go to ready after last address
            ready <= '1';
        end if;
        --
    end if;
    end process;

    process(wdata_q, wmode_q, ram_rdata)
        variable v_wdata : std_logic_vector(g_DATA_WIDTH downto 0);
    begin
        ram_wdata <= (others => 'X');
        if ( wmode_q = X"0" ) then
            -- [waddr] = wdata
            ram_wdata <= wdata_q;
        end if;
        if ( wmode_q = X"1" ) then
            -- [waddr] += wdata
            v_wdata := ('0' & ram_rdata) + ('0' & wdata_q);
            ram_wdata <= v_wdata(ram_wdata'range);
            if ( not g_OVERFLOW and v_wdata(v_wdata'left) = '1' ) then
                -- handle overflow
                ram_wdata <= (others => '1');
            end if;
        end if;
    end process;

    ram_raddr <= i_waddr when ( i_we = '1' ) else i_raddr;

    -- main storage
    e_ram : entity work.ram_1r1w_wreg
    generic map (
        g_ADDR_WIDTH => g_ADDR_WIDTH,
        g_DATA_WIDTH => g_DATA_WIDTH,
        g_WREG_N => g_WREG_N,
        g_RAMSTYLE => g_RAMSTYLE--,
    )
    port map (
        i_waddr => ram_waddr,
        i_wdata => ram_wdata,
        i_we => ram_we,

        i_raddr => ram_raddr,
        o_rdata => ram_rdata,

        i_clk => i_clk--,
    );

    generate_RDW_X : if g_RDW_X generate
        o_rdata <= (others => 'X') when ( ram_we = '1' ) else ram_rdata;
    end generate;

    generate_RDW : if not g_RDW_X generate
        -- read interface
        e_rram : entity work.ram_1r1w_wreg
        generic map (
            g_ADDR_WIDTH => g_ADDR_WIDTH,
            g_DATA_WIDTH => g_DATA_WIDTH,
            g_WREG_N => g_WREG_N,
            g_RAMSTYLE => g_RAMSTYLE--,
        )
        port map (
            i_waddr => ram_waddr,
            i_wdata => ram_wdata,
            i_we => ram_we,

            i_raddr => i_raddr,
            o_rdata => rdata,

            i_clk => i_clk--,
        );

        o_rdata <=
            -- latest wdata at waddr
            ram_wdata when ( ram_we = '1' and ram_waddr = raddr_q ) else
            rdata;
    end generate;

end architecture;
