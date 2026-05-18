-- M. Mueller, June 2023

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity qc_histos is
port (
    i_data                  : in    work.mu3e.link32_t;
    i_chip_sel              : in    integer range 0 to 128 := 0;
    i_raddr                 : in    std_logic_vector(31 downto 0);
    o_rdata                 : out   std_logic_vector(31 downto 0);
    i_zeromem               : in    std_logic;
    i_ena                   : in    std_logic;
    i_reset_n               : in    std_logic;
    i_clk                   : in    std_logic--;
);
end entity;

architecture arch of qc_histos is

    signal qc_ena : std_logic;
    signal wdata_histo : std_logic_vector(15 downto 0);
    signal row, col : std_logic_vector(7 downto 0);

begin

    process(i_clk, i_reset_n) is
    begin
    if ( i_reset_n = '0' ) then
        --
    elsif rising_edge(i_clk) then
        qc_ena <= '0';
        if ( i_chip_sel = to_integer(unsigned(i_data.data(27 downto 22))) ) then
            qc_ena <= i_data.dthdr;
        end if;
        col <= i_data.data(21 downto 14);
        row <= i_data.data(13 downto 6);
    end if;
    end process;

    wdata_histo <= col & row;
    histogram_generic_inst: entity work.histogram_generic_half_rate
    generic map (
        g_DATA_WIDTH => 16,
        g_ADDR_WIDTH => 16--,
    )
    port map (
        i_raddr         => i_raddr(15 downto 0),
        o_rdata         => o_rdata(15 downto 0),
        i_rclk          => i_clk,

        i_ena           => i_ena,
        i_can_overflow  => '0',
        i_wdata         => wdata_histo,
        i_valid         => qc_ena,
        o_busy_n        => open,
        i_wclk          => i_clk,

        i_zeromem       => i_zeromem,
        i_reset_n       => i_reset_n--,
    );

end architecture;
