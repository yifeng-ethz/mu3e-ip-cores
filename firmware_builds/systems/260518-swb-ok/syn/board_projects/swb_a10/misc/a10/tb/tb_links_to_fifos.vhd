library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

use work.a10_pcie_registers.all;
use work.mudaq.all;

entity tb_links_to_fifos is
end entity;

architecture arch of tb_links_to_fifos is

    constant CLK_MHZ : real := 10000.0; -- MHz
    signal clk, reset_n : std_logic := '0';

    signal rx : work.mu3e.link32_array_t(7 downto 0) := (others => work.mu3e.LINK32_IDLE);
    signal package_stage, subheader : slv8_array_t(7 downto 0);
    signal rdempty : std_logic_vector(7 downto 0);

begin

    clk     <= not clk after (0.5 us / CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / CLK_MHZ);

    --! links to fifos
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_links_to_fifos : entity work.links_to_fifos
    generic map (
        g_LINK_N => 8--,
    )
    port map (
        i_rx            => rx,
        i_rmask_n       => (others => '1'),

        i_lookup_ctrl   => (others => '1'),
        i_sync_enable   => '1',

        o_q             => open,
        i_ren           => (others => '0'),
        o_rdempty       => rdempty,

        o_counter       => open,
        i_reset_n_cnt   => reset_n,

        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

    gen_chip_lookup_and_fifos : for i in 0 to 7 GENERATE

        gen_hits : process(clk, reset_n)
        begin
        if ( reset_n /= '1' ) then
            rx(i) <= work.mu3e.LINK32_IDLE;
            package_stage(i) <= (others => '0');
            subheader(i) <= (others => '0');
            --
        elsif rising_edge(clk) then
            package_stage(i) <= package_stage(i) + '1';
            rx(i) <= work.mu3e.LINK32_IDLE;

            case package_stage(i) is

            when "00000000" =>
                rx(i).idle <= '0';
                rx(i).sop <= '1';
                rx(i).data <= x"E80000BC";
            when "00000010" =>
                rx(i).idle <= '0';
                rx(i).datak <= "0000";
                rx(i).data <= x"AFFEAFFE";
            when "00000011" =>
                rx(i).idle <= '0';
                rx(i).datak <= "0000";
                rx(i).data <= x"BEEFBEEF";
            when "00000100" =>
                rx(i).idle <= '0';
                rx(i).datak <= "0000";
                rx(i).data <= x"D0D0D0D0";
            when "00000101" =>
                rx(i).idle <= '0';
                rx(i).datak <= "0000";
                rx(i).data <= x"D1D1D1D1";
            when "00001000" =>
                rx(i).idle <= '0';
                rx(i).sbhdr <= '1';
                rx(i).data(31 downto 24) <= subheader(i); -- 0: 0000000000000001
                rx(i).data(23 downto 8) <= "0000000010000000"; -- <-- should be 0 in reality but for the test we set a value
                rx(i).data(7 downto 0) <= work.util.K23_7;
                subheader(i) <= subheader(i) + '1';
            when "00001001" =>
                rx(i).idle <= '0';
                rx(i).datak <= "0000";
                rx(i).data <= x"DEEDDEED";
                rx(i).data(31 downto 28) <= "0000";
            when "00001010" =>
                rx(i).idle <= '0';
                rx(i).sbhdr <= '1';
                rx(i).data(31 downto 24) <= subheader(i); -- 1: (others => '1')
                rx(i).data(23 downto 8) <= "0000000000000001";
                rx(i).data(7 downto 0) <= work.util.K23_7;
                subheader(i) <= subheader(i) + '1';
            when "00001100" =>
                rx(i).idle <= '0';
                rx(i).sbhdr <= '1';
                rx(i).data(31 downto 24) <= subheader(i); -- 2: 0000000000000000
                rx(i).data(23 downto 8) <= (others => '1');
                rx(i).data(7 downto 0) <= work.util.K23_7;
                subheader(i) <= subheader(i) + '1';
            when "00001101" =>
                rx(i).idle <= '0';
                rx(i).sbhdr <= '1';
                rx(i).data(31 downto 24) <= subheader(i); -- 3: (others => '1')
                rx(i).data(23 downto 8) <= "0000000000000000";
                rx(i).data(7 downto 0) <= work.util.K23_7;
                subheader(i) <= subheader(i) + '1';
            when "00001110" =>
                rx(i).idle <= '0';
                rx(i).datak <= "0000";
                rx(i).data <= x"DEEDDEED";
                rx(i).data(31 downto 28) <= "0000";
            when "00001111" =>
                rx(i).idle <= '0';
                rx(i).sbhdr <= '1';
                rx(i).data(31 downto 24) <= subheader(i); -- 4: (others => '1')
                rx(i).data(23 downto 8) <= (others => '1');
                rx(i).data(7 downto 0) <= work.util.K23_7;
                subheader(i) <= subheader(i) + '1';
            when "00010000" =>
                rx(i).idle <= '0';
                rx(i).datak <= "0000";
                rx(i).data <= x"DEEDDEED";
                rx(i).data(31 downto 28) <= "0000";
            when "00010001" =>
                rx(i).idle <= '0';
                rx(i).datak <= "0000";
                rx(i).data <= x"DEEDDEED";
                rx(i).data(31 downto 28) <= "0001";
            when "00010010" =>
                rx(i).idle <= '0';
                rx(i).datak <= "0000";
                rx(i).data <= x"DEEDDEED";
                rx(i).data(31 downto 28) <= "0010";
            when "00011000" =>
                rx(i).idle <= '0';
                rx(i).eop <= '1';
                rx(i).data <= x"00FFFF9C";
                package_stage(i) <= "00000000";
            when others =>

            end case;
        end if;
        end process;

    end generate;

end architecture;
