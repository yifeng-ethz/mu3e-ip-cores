--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rst_shift_block is
port (
    i_d           : in std_logic_vector(0 downto 0); -- datain
    i_clk_125     : in std_logic; -- 125Mhz clk
    i_reset_125_n : in std_logic; -- 125Mhz reset_n
    i_clk         : in std_logic;
    i_reset_n     : in std_logic; -- reset
    i_cdata       : in std_logic_vector(5 downto 0); -- configuration input
    i_we          : in std_logic; -- state machine start signal
    o_d           : out std_logic_vector(0 downto 0) -- dataout
);
end entity;

architecture bhv of rst_shift_block is


    -- cclk is divided internally downto XMHz
    constant c_P : std_logic_vector(3 downto 0) := std_logic_vector(to_unsigned(5, 4));
    signal s_cclk : std_logic := '1';
    signal s_last_cclk : std_logic := '1';
    signal s_counter : unsigned(3 downto 0) := (others => '0');
    -- start signal in units of cclk
    signal s_cstartin : std_logic := '0';
    -- signals for connection
    signal s_cclkena : std_logic_vector(0 downto 0);
    signal s_cdataout : std_logic;
    signal s_cupdateout : std_logic;
    signal s_datashift : std_logic_vector(0 downto 0);

begin

    cclk : entity work.clkdiv
    generic map (
        g_N => 5
    )
    port map (
        i_clk => i_clk,
        i_reset_n => i_reset_n,
        o_clk => s_cclk
    );

    process (i_clk)
    begin
    if rising_edge(i_clk) then
        s_last_cclk <= s_cclk;
        if i_we = '1' then
            s_cstartin <= '1';
        elsif s_last_cclk = '0' and s_cclk ='1' then
            s_cstartin <= '0';
        end if;
    end if;
    end process;

    conf : entity work.obuf_config
    port map (
        i_cclk => s_cclk,
        i_reset_n => i_reset_n,
        i_cdata => i_cdata,
        i_cstart => s_cstartin,
        o_cdata => s_cdataout,
        o_cclkena => s_cclkena,
        o_cupdate => s_cupdateout,
        o_datashift => s_datashift(0)
    );

    ip : entity work.ip_reset_shift
    port map (
        datashift => s_datashift,
        datain => i_d,
        io_config_clk => s_cclk,
        io_config_clkena => s_cclkena,
        io_config_datain => s_cdataout,
        io_config_update => s_cupdateout,
        dataout => o_d,
        --oe(0) => s_oe,
        i_reset_n => i_reset_125_n,
        clk => i_clk_125
    );

end architecture;
