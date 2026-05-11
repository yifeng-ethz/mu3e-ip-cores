--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity enc_8b10b_n is
generic (
    g_BYTES : positive := 4--;
);
port (
    i_data      : in    std_logic_vector(g_BYTES*8-1 downto 0);
    i_datak     : in    std_logic_vector(g_BYTES-1 downto 0);

    o_data      : out   std_logic_vector(g_BYTES*10-1 downto 0);

    o_err       : out   std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of enc_8b10b_n is

    signal data : std_logic_vector(o_data'range);
    signal disp : std_logic_vector(g_BYTES downto 0);
    signal err : std_logic_vector(g_BYTES-1 downto 0);

begin

    generate_enc_8b10b : for i in 0 to g_BYTES-1 generate
    begin
        e_enc_8b10b : entity work.enc_8b10b
        port map (
            i_data => i_datak(i) & i_data(i*8 + 7 downto 0 + i*8),
            i_disp => disp(i),
            o_data => data(i*10 + 9 downto 0 + i*10),
            o_disp => disp(i+1),
            o_err => err(i)--,
        );
    end generate;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        o_data <= (others => '0');
        disp(0) <= '0';
        o_err <= '0';
        --
    elsif rising_edge(i_clk) then
        o_data <= data;
        disp(0) <= disp(g_BYTES);
        o_err <= '0';
        if ( err /= 0 ) then
            o_err <= '1';
        end if;
        --
    end if;
    end process;

end architecture;
