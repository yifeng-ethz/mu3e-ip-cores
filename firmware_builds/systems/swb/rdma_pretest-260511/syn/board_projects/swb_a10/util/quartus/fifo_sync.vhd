--

library ieee;
use ieee.std_logic_1164.all;

entity fifo_sync is
generic (
    g_DATA_RESET : std_logic_vector := "0";
    g_DATA_WIDTH : positive := 1;
    -- 8 elemets
    g_ADDR_WIDTH : positive := 3;
    g_WREG_N : natural := 0;
    g_RREG_N : natural := 0;
    g_LPM_HINT: string := "UNUSED"--;
);
port (
    -- write domain
    i_wdata     : in    std_logic_vector(work.util.max(g_DATA_WIDTH, g_DATA_RESET'length)-1 downto 0);
    i_wclk      : in    std_logic;
    i_wreset_n  : in    std_logic := '1';

    -- read domain
    o_rdata     : out   std_logic_vector(work.util.max(g_DATA_WIDTH, g_DATA_RESET'length)-1 downto 0);
    i_rclk      : in    std_logic;
    i_rreset_n  : in    std_logic := '1'--;
);
end entity;

architecture rtl of fifo_sync is

    signal rempty, wfull, we : std_logic;
    signal rdata, wdata : std_logic_vector(o_rdata'range);

    -- force `downto` range direction
    constant DATA_RESET : std_logic_vector(g_DATA_RESET'length-1 downto 0) := g_DATA_RESET;

begin

    e_fifo : entity work.ip_dcfifo_v2
    generic map (
        g_ADDR_WIDTH => g_ADDR_WIDTH,
        g_WREG_N => g_WREG_N,
        g_RREG_N => g_RREG_N,
        g_DATA_WIDTH => i_wdata'length,
        g_LPM_HINT => g_LPM_HINT--,
    )
    port map (
        i_we        => we,
        i_wdata     => wdata,
        o_wfull     => wfull,
        i_wclk      => i_wclk,

        i_rack      => not rempty,
        o_rdata     => rdata,
        o_rempty    => rempty,
        i_rclk      => i_rclk,

        i_reset_n   => i_rreset_n--,
    );

    process(i_wclk, i_wreset_n)
    begin
    if ( i_wreset_n /= '1' ) then
        we <= '0';
        --
    elsif rising_edge(i_wclk) then
        wdata <= i_wdata;
        we <= not wfull;
        --
    end if;
    end process;

    process(i_rclk, i_rreset_n)
    begin
    if ( i_rreset_n /= '1' ) then
        o_rdata <= (others => '0');
        o_rdata(DATA_RESET'range) <= DATA_RESET;
        --
    elsif rising_edge(i_rclk) then
        if ( rempty = '0' ) then
            o_rdata <= rdata;
        end if;
        --
    end if;
    end process;

end architecture;
