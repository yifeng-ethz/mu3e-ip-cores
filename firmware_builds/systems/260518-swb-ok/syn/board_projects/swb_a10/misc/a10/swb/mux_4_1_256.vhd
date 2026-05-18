----------------------------------
--
-- 4 to 1 256bit hit multiplexer
-- Assume hits at maximum every fourth cycle
--
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

entity mux_4_1_256 is
generic (
    N : integer := 4--;
);
port (
    i_data      : in    slv256_array_t(N - 1 downto 0);
    i_valid     : in    std_logic_vector(N - 1 downto 0);

    o_data      : out   std_logic_vector(255 downto 0);
    o_valid     : out   std_logic;

    o_word_cnt  : out std_logic_vector(63 downto 0);
    o_word_rate : out std_logic_vector(31 downto 0);

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture rtl of mux_4_1_256 is

    signal data_out : std_logic_vector(255 downto 0);
    signal data_in_buffer : slv256_array_t(N - 1 downto 0);
    signal data_valid_buffer : std_logic_vector(N - 1 downto 0);
    signal data_taken : std_logic_vector(N - 1 downto 0);
    signal s_word_cnt : std_logic_vector(63 downto 0);
    signal s_valid : std_logic;

begin

    o_data <= data_out;
    o_word_cnt <= s_word_cnt;
    o_valid <= s_valid;

    e_rate : entity work.word_rate
    generic map ( g_CLK_MHZ => 250.0 )
    port map (
        i_valid => s_valid, o_rate => o_word_rate,
        i_reset_n => i_reset_n, i_clk => i_clk--,
    );

    process(i_clk) is
        variable position : integer range 0 to N;
        variable valid_not_taken : std_logic_vector(N - 1 downto 0);
        variable taken_mask : std_logic_vector(N - 1 downto 0);
    begin
    if rising_edge(i_clk) then
        if ( i_reset_n = '0' ) then
            data_valid_buffer <= (others => '0');
            data_taken <= (others => '0');
            s_word_cnt <= (others => '0');
            s_valid <= '0';
        else
            data_taken <= (others => '0');
            s_valid <= '0';
            data_valid_buffer <= i_valid or (data_valid_buffer and (not data_taken));

            for i in 0 to N - 1 loop
                if(i_valid(i) = '1') then
                    data_in_buffer(i)  <= i_data(i);
                end if;
            end loop;

            valid_not_taken := (data_valid_buffer and (not data_taken));
            position := N;
            for i in 0 to N - 1 loop
                if ( valid_not_taken(i) /= '0' ) then
                    position := i;
                    exit;
                end if;
            end loop;

            --position := work.util.count_leading_zeroes((data_valid_buffer and (not data_taken)));
            if ( position < N ) then
                data_out <= data_in_buffer(position);
                s_valid <= '1';
                s_word_cnt <= s_word_cnt + '1';
                taken_mask := (others => '0');
                taken_mask(position) := '1';
                data_taken <= taken_mask;
            end if;
        end if;
    end if;
    end process;

end architecture;
