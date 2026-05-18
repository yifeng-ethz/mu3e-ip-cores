--

library ieee;
use ieee.std_logic_1164.all;

entity link64_scfifo is
generic (
    g_ADDR_WIDTH : positive := 8;
    g_WREG_N : natural := 0;
    g_RREG_N : natural := 0;
    g_DEVICE_FAMILY : string := "Arria 10"--;
);
port (
    i_we            : in    std_logic;
    i_wdata         : in    work.mu3e.link64_t;
    o_wfull         : out   std_logic;
    o_wfull_n       : out   std_logic;
    o_almost_full   : out   std_logic;

    i_rack          : in    std_logic;
    o_rdata         : out   work.mu3e.link64_t;
    o_rempty        : out   std_logic;
    o_rempty_n      : out   std_logic;
    o_almost_empty  : out   std_logic;

    o_usedw         : out   std_logic_vector(g_ADDR_WIDTH-1 downto 0);

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture arch of link64_scfifo is

    signal rdata : std_logic_vector(work.mu3e.LINK_64B_LENGTH-1 downto 0);

begin

    o_rdata <= work.mu3e.to_link(rdata);

    e_fifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => g_ADDR_WIDTH,
        g_DATA_WIDTH => rdata'length,
        g_WREG_N => g_WREG_N,
        g_RREG_N => g_RREG_N,
        g_DEVICE_FAMILY => g_DEVICE_FAMILY--
    )
    port map (
        i_we            => i_we,
        i_wdata         => work.mu3e.to_slv(i_wdata),
        o_wfull         => o_wfull,
        o_wfull_n       => o_wfull_n,
        o_almost_full   => o_almost_full,

        i_rack          => i_rack,
        o_rdata         => rdata,
        o_rempty        => o_rempty,
        o_rempty_n      => o_rempty_n,
        o_almost_empty  => o_almost_empty,

        o_usedw         => o_usedw,

        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

end architecture;
