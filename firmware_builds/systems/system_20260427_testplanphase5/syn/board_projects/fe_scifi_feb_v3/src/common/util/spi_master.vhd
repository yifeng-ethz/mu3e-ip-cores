--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- SPI master
--
-- NOTE: see spi_slave.vhd for wave diagram
--
entity spi_master is
generic (
    g_DATA_WIDTH        : positive := 8;
    g_FIFO_ADDR_WIDTH   : positive := 4--;
);
port (
    o_sclk              : out   std_logic;
    o_sdo               : out   std_logic;
    i_sdi               : in    std_logic;
    o_ss_n              : out   std_logic;

    i_wdata             : in    std_logic_vector(g_DATA_WIDTH-1 downto 0);
    i_we                : in    std_logic;
    o_wfull             : out   std_logic;

    o_rdata             : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);
    i_rack              : in    std_logic;
    o_rempty            : out   std_logic;

    -- sck clock divider (cycles between clock transitions)
    i_sclk_div          : in    std_logic_vector(15 downto 0) := (others => '0');
    -- clock polarity
    i_cpol              : in    std_logic := '0';
    -- clock phase (separate for sdo and sdi)
    i_sdo_cpha          : in    std_logic := '0';
    i_sdi_cpha          : in    std_logic := '0';

    o_error_wfifo_uf    : out   std_logic;
    o_error_sdi_uf      : out   std_logic;
    o_error_rfifo_of    : out   std_logic;

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture arch of spi_master is

    signal sclk : std_logic;
    signal ss : std_logic;
    signal sclk_cnt : unsigned(i_sclk_div'range);

    signal wfifo_rempty : std_logic;

begin

    -- clock polarity
    o_sclk <= sclk xor i_cpol;
    o_ss_n <= not ss;

    -- generate clock (sclk) and slave select (ss)
    process(i_clk)
    begin
    if ( i_reset_n /= '1' ) then
        sclk <= '0';
        ss <= '0';
        sclk_cnt <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        if ( ss = '1' ) then
            if ( sclk_cnt = unsigned(i_sclk_div) ) then
                -- reset ss on sclk rising edge
                if ( sclk = '0' and wfifo_rempty = '1' ) then
                    ss <= '0';
                else
                    sclk <= not sclk;
                end if;

                sclk_cnt <= (others => '0');
            else
                sclk_cnt <= sclk_cnt + 1;
            end if;
        elsif ( wfifo_rempty = '0' ) then
            sclk <= '0';
            ss <= '1';
            sclk_cnt <= (others => '0');
        end if;
        --
    end if;
    end process;

    e_spi_slave : entity work.spi_slave
    generic map (
        g_DATA_WIDTH => g_DATA_WIDTH,
        g_FIFO_ADDR_WIDTH => g_FIFO_ADDR_WIDTH--,
    )
    port map (
        i_sclk => sclk,
        o_sdo => o_sdo,
        i_sdi => i_sdi,
        i_ss_n => not ss,

        i_wdata => i_wdata,
        i_we => i_we,
        o_wfull => o_wfull,

        o_rdata => o_rdata,
        i_rack => i_rack,
        o_rempty => o_rempty,

        i_cpol => '0',
        i_sdo_cpha => i_sdo_cpha,
        i_sdi_cpha => i_sdi_cpha,

        o_wfifo_rempty => wfifo_rempty,

        o_error_wfifo_uf => o_error_wfifo_uf,
        o_error_sdi_uf => o_error_sdi_uf,
        o_error_rfifo_of => o_error_rfifo_of,

        i_reset_n => i_reset_n,
        i_clk => i_clk--,
    );

end architecture;
