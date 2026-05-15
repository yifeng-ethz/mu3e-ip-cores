--

library ieee;
use ieee.std_logic_1164.all;

-- NOTE: deprecated, use ip_dcfifo_v2
entity ip_dcfifo IS
generic (
    ADDR_WIDTH  : positive := 8;
    DATA_WIDTH  : positive := 8;
    SHOWAHEAD   : string := "ON";
    OVERFLOW    : string := "ON";
    g_LPM_HINT  : string := "";
    DEVICE      : string := "Arria 10"--;
);
port (
    wrreq       : in    std_logic;
    data        : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    wrclk       : in    std_logic;
    wrfull      : out   std_logic;
    wrusedw     : out   std_logic_vector(ADDR_WIDTH-1 downto 0);

    rdreq       : in    std_logic;
    rdclk       : in    std_logic;
    q           : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    rdempty     : out   std_logic;
    rdusedw     : out   std_logic_vector(ADDR_WIDTH-1 downto 0);

    aclr        : in    std_logic := '0'--;
);
end entity;

architecture arch of ip_dcfifo is
begin

    e_ip_dcfifo_v2 : entity work.ip_dcfifo_v2
    generic map (
        g_ADDR_WIDTH => ADDR_WIDTH,
        g_DATA_WIDTH => DATA_WIDTH,
        g_SHOWAHEAD => SHOWAHEAD,
        g_WREG_N => 0,
        g_RREG_N => 0,
        g_DEVICE_FAMILY => DEVICE,
        g_LPM_HINT => g_LPM_HINT--,
    )
    port map (
        i_we        => wrreq,
        i_wdata     => data,
        o_wfull     => wrfull,
        o_wusedw    => wrusedw,
        i_wclk      => wrclk,

        i_rack      => rdreq,
        o_rdata     => q,
        o_rempty    => rdempty,
        o_rusedw    => rdusedw,
        i_rclk      => rdclk,

        i_reset_n   => not aclr--,
    );

end architecture;
