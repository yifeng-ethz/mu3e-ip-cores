--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

-- reset and alignment logic for lvds input of reset link
-- Martin Mueller August 2019
--
-- see <ug_altlvds.pdf> / "1.5.3.4. Recommended Initialization and Reset Flow"
--
-- 1 assert pll_areset and rx_reset
-- 2 deassert pll_areset
--   and monitor rx_locked (PLL lock indicator)
-- 3 deassert rx_reset after rx_locked becomes asserted and stable
-- 4 apply the DPA training pattern and allow the DPA circuit to lock
-- 5 wait for rx_dpa_locked to assert
-- 6 assert rx_fifo_reset for at least one parallel clock cycle
-- 7 assert rx_cda_reset for at least one parallel clock cycle
-- 8 begin word alignment by applying pulses to rx_channel_data_align
-- 9 when the word boundaries are established on each channel
--   the interface is ready for operation
--
entity lvds_controller is
generic (
    i_align_pattern : std_logic_vector(7 downto 0) := x"BC";
    i_stable_required : std_logic_vector(15 downto 0) := x"0010";
    i_loss_lock_words : std_logic_vector(15 downto 0) := x"0010"
);
port (
    i_data              : in    std_logic_vector(7 downto 0);
    i_cda_max           : in    std_logic;
    i_dpa_locked        : in    std_logic;
    i_rx_locked         : in    std_logic;
    o_ready             : out   std_logic;
    o_data_align        : out   std_logic;
    o_pll_areset        : out   std_logic;
    o_dpa_lock_reset    : out   std_logic;
    o_fifo_reset        : out   std_logic;
    o_rx_reset          : out   std_logic;
    o_cda_reset         : out   std_logic; -- not available in ArriaV
    o_align_clicks      : out   std_logic_vector(7 downto 0);
    o_lvds_state        : out   std_logic_vector(3 downto 0);

    i_areset_n          : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture rtl of lvds_controller is

    signal lvds_state       : std_logic_vector(3 downto 0);
    signal stable_counter   : std_logic_vector(15 downto 0);
    signal data_align       : std_logic;
    signal align_clicks     : std_logic_vector(7 downto 0);
    signal align_delay      : std_logic_vector(2 downto 0);
    signal realign_lvds_n   : std_logic;

begin

    e_sync_realign_n : entity work.reset_sync
    port map ( i_areset_n => i_areset_n, o_reset_n => realign_lvds_n, i_clk => i_clk );

    o_data_align <= data_align;
    o_align_clicks <= align_clicks;

    -- FIXME: use `if ( realign_lvds_n /= '1' ) then
    process(i_clk, realign_lvds_n)
    begin
    if rising_edge (i_clk) and ( realign_lvds_n = '0' ) then
        o_pll_areset    <= '1';
        o_rx_reset      <= '1';
        o_dpa_lock_reset<= '1';
        lvds_state      <= x"0";
        stable_counter  <= (others => '0');
        align_clicks    <= (others => '0');
        o_ready         <= '0';
        o_cda_reset     <= '0';
        o_fifo_reset    <= '0';
        data_align      <= '0';
    elsif rising_edge(i_clk) then
        case lvds_state is
        when x"0" =>
            o_pll_areset      <= '0';
            if(stable_counter = i_stable_required) then
                lvds_state      <= x"1";
                o_rx_reset      <= '0';
                o_dpa_lock_reset<= '0';
                stable_counter  <= (others => '0');
            elsif(i_rx_locked = '1') then
                stable_counter  <= stable_counter + '1';
            else
                stable_counter  <= (others => '0');
            end if;

        when x"1"=>
            if ( i_dpa_locked = '1' ) then
                lvds_state      <= x"2";
                o_fifo_reset    <= '1';
            end if;

        when x"2" =>
            o_fifo_reset        <= '0';
            lvds_state          <= x"3";

        when x"3" =>
            o_cda_reset         <= '1';
            lvds_state          <= x"4";

        when x"4" =>
            o_cda_reset         <= '0';
            lvds_state          <= x"5";
            align_delay         <= "000";

        -- reset alignment
        when x"5" =>
            if ( i_cda_max = '0' ) then
                data_align      <= not data_align;
            else
                lvds_state      <= x"6";
                stable_counter  <= (others => '0');
            end if;

        when x"6" =>
            if ( stable_counter = x"0005" ) then
                lvds_state          <= x"7";
                stable_counter      <= (others => '0');
            else
                stable_counter      <= stable_counter + '1';
            end if;

        -- alignment
        when X"7" =>
            if ( i_data = i_align_pattern) then
                lvds_state      <= x"8";
            else
                if ( align_delay = "111" ) then
                    data_align      <= not data_align;
                    if ( data_align = '0' ) then
                        align_clicks <= align_clicks + '1';
                    end if;
                    align_delay     <= "000";
                else
                    align_delay     <= align_delay + '1';
                end if;
            end if;

        when x"8" =>
            o_ready             <= '1';
            -- TODO: fix realign conditions
            if ( i_data /= i_align_pattern ) then
                stable_counter      <= stable_counter + '1';
            else
                stable_counter      <= (others => '0');
            end if;

            if ( stable_counter = i_loss_lock_words ) then
                o_pll_areset    <= '1';
                o_rx_reset      <= '1';
                o_dpa_lock_reset<= '1';
                lvds_state      <= x"0";
                stable_counter  <= (others => '0');
                align_clicks    <= (others => '0');
                o_ready         <= '0';
                o_cda_reset     <= '0';
                o_fifo_reset    <= '0';
                data_align      <= '0';
            end if;

        when others =>
            o_pll_areset    <= '1';
            o_rx_reset      <= '1';
            o_dpa_lock_reset<= '1';
            lvds_state      <= x"0";
            stable_counter  <= (others => '0');
            align_clicks    <= (others => '0');
            o_ready         <= '0';
            o_cda_reset     <= '0';
            o_fifo_reset    <= '0';
            data_align      <= '0';
        end case;
    end if;
    end process;

end architecture;
