library ieee;
use ieee.std_logic_1164.all;

entity max10_link_adapter is
    port (
        i_clk              : in    std_logic;

        i_link_csn         : in    std_logic;
        i_link_clk         : in    std_logic;
        i_link_mosi_out    : in    std_logic;
        i_link_mosi_oe     : in    std_logic;
        i_link_d1_out      : in    std_logic;
        i_link_d1_oe       : in    std_logic;
        i_link_d2_out      : in    std_logic;
        i_link_d2_oe       : in    std_logic;
        i_link_d3_out      : in    std_logic;
        i_link_d3_oe       : in    std_logic;

        o_link_mosi_in     : out   std_logic;
        o_link_d1_in       : out   std_logic;
        o_link_d2_in       : out   std_logic;
        o_link_d3_in       : out   std_logic;

        o_max10_spi_sclk   : out   std_logic;
        o_max10_spi_csn    : out   std_logic;
        io_max10_spi_mosi  : inout std_logic;
        io_max10_spi_miso  : inout std_logic;
        io_max10_spi_d1    : inout std_logic;
        io_max10_spi_d2    : inout std_logic;
        io_max10_spi_d3    : inout std_logic
    );
end entity max10_link_adapter;

architecture rtl of max10_link_adapter is
    signal link_clk_d1      : std_logic := '0';
    signal link_csn_d1      : std_logic := '1';
    signal link_mosi_out_d1 : std_logic := '0';
    signal link_mosi_oe_d1  : std_logic := '0';
    signal link_d1_out_d1   : std_logic := '0';
    signal link_d1_oe_d1    : std_logic := '0';
    signal link_d2_out_d1   : std_logic := '0';
    signal link_d2_oe_d1    : std_logic := '0';
    signal link_d3_out_d1   : std_logic := '0';
    signal link_d3_oe_d1    : std_logic := '0';

    signal max10_spi_mosi_in : std_logic := '0';
    signal max10_spi_d1_in   : std_logic := '0';
    signal max10_spi_d2_in   : std_logic := '0';
    signal max10_spi_d3_in   : std_logic := '0';

    attribute altera_attribute : string;
    attribute altera_attribute of link_clk_d1 : signal is
        "-name FAST_OUTPUT_REGISTER ON; -name PRESERVE_REGISTER ON; -name DONT_MERGE_REGISTER ON";
    attribute altera_attribute of link_csn_d1 : signal is
        "-name FAST_OUTPUT_REGISTER ON; -name PRESERVE_REGISTER ON; -name DONT_MERGE_REGISTER ON";
    attribute altera_attribute of link_mosi_out_d1 : signal is
        "-name FAST_OUTPUT_REGISTER ON; -name PRESERVE_REGISTER ON; -name DONT_MERGE_REGISTER ON";
    attribute altera_attribute of link_d1_out_d1 : signal is
        "-name FAST_OUTPUT_REGISTER ON; -name PRESERVE_REGISTER ON; -name DONT_MERGE_REGISTER ON";
    attribute altera_attribute of link_d2_out_d1 : signal is
        "-name FAST_OUTPUT_REGISTER ON; -name PRESERVE_REGISTER ON; -name DONT_MERGE_REGISTER ON";
    attribute altera_attribute of link_d3_out_d1 : signal is
        "-name FAST_OUTPUT_REGISTER ON; -name PRESERVE_REGISTER ON; -name DONT_MERGE_REGISTER ON";
    attribute altera_attribute of link_mosi_oe_d1 : signal is
        "-name FAST_OUTPUT_ENABLE_REGISTER ON; -name PRESERVE_REGISTER ON; -name DONT_MERGE_REGISTER ON";
    attribute altera_attribute of link_d1_oe_d1 : signal is
        "-name FAST_OUTPUT_ENABLE_REGISTER ON; -name PRESERVE_REGISTER ON; -name DONT_MERGE_REGISTER ON";
    attribute altera_attribute of link_d2_oe_d1 : signal is
        "-name FAST_OUTPUT_ENABLE_REGISTER ON; -name PRESERVE_REGISTER ON; -name DONT_MERGE_REGISTER ON";
    attribute altera_attribute of link_d3_oe_d1 : signal is
        "-name FAST_OUTPUT_ENABLE_REGISTER ON; -name PRESERVE_REGISTER ON; -name DONT_MERGE_REGISTER ON";
begin
    o_link_mosi_in <= max10_spi_mosi_in;
    o_link_d1_in <= max10_spi_d1_in;
    o_link_d2_in <= max10_spi_d2_in;
    o_link_d3_in <= max10_spi_d3_in;

    -- Keep the dedicated SCLK pin parked high; the shared MISO pin carries the
    -- forwarded clock that the MAX10 side samples against.
    o_max10_spi_sclk <= '1';
    o_max10_spi_csn <= link_csn_d1;

    process (i_clk)
    begin
        if rising_edge(i_clk) then
            link_clk_d1      <= i_link_clk;
            link_csn_d1      <= i_link_csn;
            link_mosi_out_d1 <= i_link_mosi_out;
            link_mosi_oe_d1  <= i_link_mosi_oe;
            link_d1_out_d1   <= i_link_d1_out;
            link_d1_oe_d1    <= i_link_d1_oe;
            link_d2_out_d1   <= i_link_d2_out;
            link_d2_oe_d1    <= i_link_d2_oe;
            link_d3_out_d1   <= i_link_d3_out;
            link_d3_oe_d1    <= i_link_d3_oe;
        end if;
    end process;

    iobuf_max10_spi_mosi : entity work.ip_altiobuf_bidir
        port map (
            datain(0)   => link_mosi_out_d1,
            oe(0)       => link_mosi_oe_d1,
            dataout(0)  => max10_spi_mosi_in,
            dataio(0)   => io_max10_spi_mosi
        );

    iobuf_max10_spi_miso : entity work.ip_altiobuf_bidir
        port map (
            datain(0)   => link_clk_d1,
            oe(0)       => '1',
            dataout(0)  => open,
            dataio(0)   => io_max10_spi_miso
        );

    iobuf_max10_spi_d1 : entity work.ip_altiobuf_bidir
        port map (
            datain(0)   => link_d1_out_d1,
            oe(0)       => link_d1_oe_d1,
            dataout(0)  => max10_spi_d1_in,
            dataio(0)   => io_max10_spi_d1
        );

    iobuf_max10_spi_d2 : entity work.ip_altiobuf_bidir
        port map (
            datain(0)   => link_d2_out_d1,
            oe(0)       => link_d2_oe_d1,
            dataout(0)  => max10_spi_d2_in,
            dataio(0)   => io_max10_spi_d2
        );

    iobuf_max10_spi_d3 : entity work.ip_altiobuf_bidir
        port map (
            datain(0)   => link_d3_out_d1,
            oe(0)       => link_d3_oe_d1,
            dataout(0)  => max10_spi_d3_in,
            dataio(0)   => io_max10_spi_d3
        );
end architecture rtl;
