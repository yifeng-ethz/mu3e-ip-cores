--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

--
-- counter ram (accumulator)
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
    -- _wmode_          | _action_
    -- 0 (store)        | [waddr] <= wdata
    -- 1 (increment)    | [waddr] <= [waddr] + wdata
    -- F (custom)       | wdata_new <= F(rdata_prev, wdata_prev)
    i_wmode     : in    std_logic_vector(3 downto 0) := X"1";

    -- custom function of rdata_prev and wdata_prev
    o_rdata_prev    : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);
    o_wdata_prev    : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);
    i_wdata_new     : in    std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others => '0');

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

    signal waddr_prev, raddr : std_logic_vector(g_ADDR_WIDTH-1 downto 0);
    signal rdata_prev, wdata_prev, wdata_new : std_logic_vector(g_DATA_WIDTH-1 downto 0);
    signal we_prev : std_logic;
    signal wmode_prev : std_logic_vector(i_wmode'range);

    signal raddr_prev : std_logic_vector(g_ADDR_WIDTH-1 downto 0);

begin

    o_ready <= ready;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        ready <= '0';
        waddr_prev <= (others => '0');
        wdata_prev <= (others => '0');
        we_prev <= '1';
        wmode_prev <= (others => '0');
        raddr_prev <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        if ( ready = '1' ) then
            waddr_prev <= i_waddr;
            wdata_prev <= i_wdata;
            we_prev <= i_we;
            wmode_prev <= i_wmode;
            raddr_prev <= i_raddr;
        elsif ( waddr_prev /= (waddr_prev'range => '1') ) then
            -- after reset waddr = 0, wdata = 0 and we = 1
            -- cycle through all addresses
            waddr_prev <= waddr_prev + 1;
        else
            -- go to ready after last address
            ready <= '1';
        end if;
        --
    end if;
    end process;

    o_rdata_prev <= rdata_prev;
    o_wdata_prev <= wdata_prev;

    process(wdata_prev, wmode_prev, rdata_prev, i_wdata_new)
        variable v_wdata : std_logic_vector(g_DATA_WIDTH downto 0);
    begin
        wdata_new <= (others => 'X');
        if ( wmode_prev = X"0" ) then
            -- [waddr] = wdata
            wdata_new <= wdata_prev;
        end if;
        if ( wmode_prev = X"1" ) then
            -- [waddr] += wdata
            v_wdata := ('0' & rdata_prev) + ('0' & wdata_prev);
            wdata_new <= v_wdata(wdata_new'range);
            if ( not g_OVERFLOW and v_wdata(v_wdata'left) = '1' ) then
                -- handle overflow
                wdata_new <= (others => '1');
            end if;
        end if;
        if ( wmode_prev = X"F" ) then
            wdata_new <= i_wdata_new;
        end if;
    end process;

    raddr <= i_waddr when ( i_we = '1' ) else i_raddr;

    -- main storage
    e_ram : entity work.ram_1r1w_wreg
    generic map (
        g_ADDR_WIDTH => g_ADDR_WIDTH,
        g_DATA_WIDTH => g_DATA_WIDTH,
        g_WREG_N => g_WREG_N,
        g_RAMSTYLE => g_RAMSTYLE--,
    )
    port map (
        i_waddr => waddr_prev,
        i_wdata => wdata_new,
        i_we => we_prev,

        i_raddr => raddr,
        o_rdata => rdata_prev,

        i_clk => i_clk--,
    );

    generate_RDW_X : if g_RDW_X generate
        o_rdata <= (others => 'X') when ( we_prev = '1' ) else rdata_prev;
    end generate;

    generate_RDW : if not g_RDW_X generate
        signal rdata : std_logic_vector(g_DATA_WIDTH-1 downto 0);
    begin
        -- read interface
        e_rram : entity work.ram_1r1w_wreg
        generic map (
            g_ADDR_WIDTH => g_ADDR_WIDTH,
            g_DATA_WIDTH => g_DATA_WIDTH,
            g_WREG_N => g_WREG_N,
            g_RAMSTYLE => g_RAMSTYLE--,
        )
        port map (
            i_waddr => waddr_prev,
            i_wdata => wdata_new,
            i_we => we_prev,

            i_raddr => i_raddr,
            o_rdata => rdata,

            i_clk => i_clk--,
        );

        o_rdata <=
            -- Read-During-Write/Update
            wdata_new when ( we_prev = '1' and waddr_prev = raddr_prev ) else
            rdata;
    end generate;

end architecture;
