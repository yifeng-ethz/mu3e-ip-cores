library ieee;
use ieee.std_logic_1164.all;

entity alt_dcfifo_w40d256_patched is
    port (
        aclr       : in  std_logic                    := '0';
        data       : in  std_logic_vector(39 downto 0);
        rdclk      : in  std_logic;
        rdreq      : in  std_logic;
        wrclk      : in  std_logic;
        wrreq      : in  std_logic;
        q          : out std_logic_vector(39 downto 0);
        rdempty    : out std_logic;
        rdfull     : out std_logic;
        rdusedw    : out std_logic_vector(9 downto 0);
        wrempty    : out std_logic;
        wrfull     : out std_logic;
        wrusedw    : out std_logic_vector(9 downto 0)
    );
end entity alt_dcfifo_w40d256_patched;

architecture rtl of alt_dcfifo_w40d256_patched is
    signal fifo_q_s        : std_logic_vector(39 downto 0);
    signal fifo_rdempty_s  : std_logic;
    signal fifo_rdfull_s   : std_logic;
    signal fifo_rdusedw_s  : std_logic_vector(9 downto 0);
    signal fifo_wrempty_s  : std_logic;
    signal fifo_wrfull_s   : std_logic;
    signal fifo_wrusedw_s  : std_logic_vector(9 downto 0);
begin
    vendor_fifo : entity work.alt_dcfifo_w40d256
        port map (
            data       => data,
            rdclk      => rdclk,
            rdreq      => rdreq,
            wrclk      => wrclk,
            wrreq      => wrreq,
            q          => fifo_q_s,
            rdempty    => fifo_rdempty_s,
            rdfull     => fifo_rdfull_s,
            rdusedw    => fifo_rdusedw_s,
            wrempty    => fifo_wrempty_s,
            wrfull     => fifo_wrfull_s,
            wrusedw    => fifo_wrusedw_s
        );

    q          <= fifo_q_s;
    rdempty    <= fifo_rdempty_s;
    rdfull     <= fifo_rdfull_s;
    rdusedw    <= fifo_rdusedw_s;
    wrempty    <= fifo_wrempty_s;
    wrfull     <= fifo_wrfull_s;
    wrusedw    <= fifo_wrusedw_s;
end architecture rtl;
