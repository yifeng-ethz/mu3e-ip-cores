-- QUARTUS_SYNTH

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

-- SPI master with avalon interface
entity avalon_spi_master is
generic (
    DATA_WIDTH        : positive := 8;
    FIFO_ADDR_WIDTH   : positive := 4--;
);
port (
    sclk            : out   std_logic;
    sdo             : out   std_logic;
    sdi             : in    std_logic;
    ss_n            : out   std_logic_vector(31 downto 0);

    avs_address     : in    std_logic_vector(1 downto 0);
    avs_read        : in    std_logic;
    avs_readdata    : out   std_logic_vector(31 downto 0);
    avs_write       : in    std_logic;
    avs_writedata   : in    std_logic_vector(31 downto 0);
    avs_waitrequest : out   std_logic;

    reset           : in    std_logic;
    clk             : in    std_logic--;
);
end entity;

architecture arch of avalon_spi_master is

    -- slave select register
    signal ss : std_logic_vector(ss_n'range);
    -- slave select override
    signal sso : std_logic;

    signal spi_ss_n : std_logic;
    signal spi_wdata, spi_rdata : std_logic_vector(31 downto 0);
    signal spi_we, spi_wfull, spi_rack, spi_rempty : std_logic;
    signal spi_sclk_div : std_logic_vector(15 downto 0);
    signal spi_cpol, spi_sdo_cpha, spi_sdi_cpha : std_logic;
    signal spi_error_wfifo_uf, spi_error_sdi_uf, spi_error_rfifo_of : std_logic;
    signal spi_reset : std_logic;

begin

    ss_n <= not (ss and (ss'range => not spi_ss_n or sso));

    process(clk, reset)
    begin
    if ( reset /= '0' ) then
        ss <= (others => '0');
        sso <= '0';
        avs_readdata <= X"CCCCCCCC";
        avs_waitrequest <= '0';
        spi_we <= '0';
        spi_rack <= '0';
        spi_sclk_div <= (others => '0');
        spi_cpol <= '0';
        spi_sdo_cpha <= '0';
        spi_sdi_cpha <= '0';
        spi_reset <= '0';
    elsif rising_edge(clk) then
        avs_readdata <= X"CCCCCCCC";
        avs_waitrequest <= '0';
        spi_we <= '0';
        spi_rack <= '0';

        -- tx data
        if ( avs_write = '1' and avs_address = "00" and spi_wfull = '0' ) then
            spi_wdata <= avs_writedata;
            spi_we <= '1';
        end if;
        -- rx data
        if ( avs_read = '1' and avs_address = "00" and spi_rempty = '0' ) then
            avs_readdata <= spi_rdata;
            spi_rack <= '1';
        end if;

        -- slave select
        if ( avs_write = '1' and avs_address = "01" ) then
            ss <= avs_writedata;
        end if;
        if ( avs_read = '1' and avs_address = "01" ) then
            avs_readdata <= ss;
        end if;

        -- status
        if ( avs_write = '1' and avs_address = "10" ) then
            sso <= avs_writedata(31);
            --
        end if;
        if ( avs_read = '1' and avs_address = "10" ) then
            avs_readdata <= (others => '0');
            avs_readdata(0) <= spi_wfull;
            avs_readdata(1) <= spi_error_wfifo_uf;
            avs_readdata(8) <= spi_rempty;
            avs_readdata(9) <= spi_error_sdi_uf;
            avs_readdata(10) <= spi_error_rfifo_of;
            avs_readdata(31) <= sso;
        end if;

        -- control
        if ( avs_write = '1' and avs_address = "11" ) then
            spi_sclk_div <= avs_writedata(15 downto 0);
            spi_cpol <= avs_writedata(16);
            spi_sdo_cpha <= avs_writedata(17);
            spi_sdi_cpha <= avs_writedata(18);
            spi_reset <= avs_writedata(31);
        end if;
        if ( avs_read = '1' and avs_address = "11" ) then
            avs_readdata <= (others => '0');
            avs_readdata(15 downto 0) <= spi_sclk_div;
            avs_readdata(16) <= spi_cpol;
            avs_readdata(17) <= spi_sdo_cpha;
            avs_readdata(18) <= spi_sdi_cpha;
            avs_readdata(31) <= spi_reset;
        end if;

    end if;
    end process;

    e_spi_master : entity work.spi_master
    generic map (
        g_DATA_WIDTH => DATA_WIDTH,
        g_FIFO_ADDR_WIDTH => FIFO_ADDR_WIDTH--,
    )
    port map (
        o_sclk => sclk,
        o_sdo => sdo,
        i_sdi => sdi,
        o_ss_n => spi_ss_n,

        i_wdata => spi_wdata(DATA_WIDTH-1 downto 0),
        i_we => spi_we,
        o_wfull => spi_wfull,

        o_rdata => spi_rdata(DATA_WIDTH-1 downto 0),
        i_rack => spi_rack,
        o_rempty => spi_rempty,

        i_sclk_div => spi_sclk_div,
        i_cpol => spi_cpol,
        i_sdo_cpha => spi_sdo_cpha,
        i_sdi_cpha => spi_sdi_cpha,

        o_error_wfifo_uf => spi_error_wfifo_uf,
        o_error_sdi_uf => spi_error_sdi_uf,
        o_error_rfifo_of => spi_error_rfifo_of,

        i_reset_n => not ( reset or spi_reset ),
        i_clk => clk--,
    );

end architecture;
