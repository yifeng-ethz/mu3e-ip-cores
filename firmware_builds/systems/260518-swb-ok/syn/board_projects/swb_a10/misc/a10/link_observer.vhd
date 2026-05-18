-- link observer for BERT
-- Marius Koeppel, August 2019

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity link_observer is
generic (
    g_m : integer := 7;
    g_poly : std_logic_vector := "1100000" -- x^7+x^6+1
);
port (
    i_rx_data   : in    std_logic_vector(g_m-1 downto 0);
    i_rx_datak  : in    std_logic_vector(3 downto 0);

    o_mem_addr  : out   std_logic_vector(2 downto 0);
    o_mem_wdata : out   std_logic_vector(31 downto 0);
    o_mem_we    : out   std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture rtl of link_observer is

    signal error_counter : std_logic_vector(63 downto 0);
    signal bit_counter : std_logic_vector(63 downto 0);

    signal tmp_rx_data : std_logic_vector(g_m-1 downto 0);
    signal next_rx_data : std_logic_vector(g_m-1 downto 0);
    signal enable : std_logic;
    signal sync_reset : std_logic;

    type state_type is (err_low, err_high, bit_low, bit_high);
    signal state : state_type;

begin

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        o_mem_addr <= (others => '0');
        o_mem_wdata <= (others => '0');
        o_mem_we <= '0';
        state <= err_low;
        --
    elsif rising_edge(i_clk) then
        case state is
        when err_low =>
            o_mem_addr <= "001";
            o_mem_wdata <= error_counter(31 downto 0);
            o_mem_we <= '1';
            state <= err_high;
        when err_high =>
            o_mem_addr <= "010";
            o_mem_wdata <= error_counter(63 downto 32);
            o_mem_we <= '1';
            state <= bit_low;
        when bit_low =>
            o_mem_addr <= "011";
            o_mem_wdata <= bit_counter(31 downto 0);
            o_mem_we <= '1';
            state <= bit_high;
        when bit_high =>
            o_mem_addr <= "100";
            o_mem_wdata <= bit_counter(63 downto 32);
            o_mem_we <= '1';
            state <= err_low;
        when others =>
            o_mem_addr <= (others => '0');
            o_mem_wdata <= (others => '0');
            o_mem_we <= '0';
            state <= err_low;
        end case;
    end if;
    end process;

    e_linear_shift_link : entity work.linear_shift_link
    generic map (
        g_m => g_m,
        g_poly => g_poly
    )
    port map (
        i_sync_reset => sync_reset,
        i_seed => i_rx_data,
        i_en => enable,
        o_lsfr => next_rx_data,
        o_datak => open,

        i_reset_n => i_reset_n,
        i_clk => i_clk--,
    );

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        error_counter <= (others => '0');
        bit_counter <= (others => '0');
        tmp_rx_data <=  x"000000BC";
        enable <= '0';
        sync_reset <= '1';
    elsif rising_edge(i_clk) then
        tmp_rx_data <= i_rx_data;
        if (i_rx_data = x"000000BC" and i_rx_datak = "0001") then
            -- idle
            enable <= '0';
            sync_reset <= '1';
        elsif (i_rx_datak = "0000") then
            enable <= '1';
            sync_reset <= '0';
            bit_counter <= bit_counter + '1';
            if(tmp_rx_data = next_rx_data) then
                -- no error
            else
                error_counter <= error_counter + '1';
            end if;
        end if;
    end if;
    end process;

end architecture;
