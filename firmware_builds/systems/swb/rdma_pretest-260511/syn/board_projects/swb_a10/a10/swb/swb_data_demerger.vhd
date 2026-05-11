-- demerging data and slowcontrol from FEB on the switching board
-- Martin Mueller, May 2019

library ieee;
use ieee.std_logic_1164.all;

entity swb_data_demerger is
port (
    i_aligned                   : in    std_logic; -- word alignment achieved
    i_data                      : in    work.mu3e.link32_t; -- optical from frontend board

    o_data                      : out   work.mu3e.link32_t; -- to sorting fifos
    o_sc                        : out   work.mu3e.link32_t; -- slowcontrol from frontend board
    o_rc                        : out   work.mu3e.link32_t;
    o_fpga_id                   : out   std_logic_vector(15 downto 0);  -- FPGA ID of the connected frontend board

    i_reset_n                   : in    std_logic;
    i_clk                       : in    std_logic--;
);
end entity;

architecture arch of swb_data_demerger is

    type state_t is (
        STATE_DATA,
        STATE_SC,
        STATE_IDLE
    );
    signal state : state_t;

begin

    process(i_clk, i_reset_n, i_aligned)
    begin
    if ( i_reset_n = '0' or i_aligned = '0' ) then
        state <= STATE_IDLE;
        o_data <= work.mu3e.LINK32_IDLE;
        o_sc <= work.mu3e.LINK32_IDLE;
        o_rc <= work.mu3e.LINK32_IDLE;
        --
    elsif rising_edge(i_clk) then
        o_data <= work.mu3e.LINK32_IDLE;
        o_sc <= work.mu3e.LINK32_IDLE;
        o_rc <= work.mu3e.LINK32_IDLE;

        case state is
        when STATE_IDLE =>
            if ( i_data.datak = "0001" and i_data.data(7 downto 0) /= work.util.K28_5 and i_data.data(7 downto 0) /= work.util.K28_4 ) then
                o_rc <= i_data;
            elsif ( i_data.datak(3 downto 0) = "0001" and i_data.data(7 downto 0) = work.util.K28_5 and (i_data.data(31 downto 29) = "111" or i_data.data(31 downto 29) = "110" ) ) then -- Mupix or MuTrig preamble
                o_fpga_id <= i_data.data(23 downto 8);
                state <= STATE_DATA;
                o_data <= i_data;
            elsif ( i_data.datak(3 downto 0) = "0001" and i_data.data(7 downto 0) = work.util.K28_5 and i_data.data(31 downto 26) = "000111" ) then -- SC preamble
                o_fpga_id                 <= i_data.data(23 downto 8);
                state <= STATE_SC;
--                slowcontrol_type <= i_data.data(25 downto 24);
                o_sc <= i_data;
            end if;
            --
        when STATE_DATA =>
            if ( i_data.datak = "0001" and (i_data.data(7 downto 0) = work.mudaq.MERGER_TIMEOUT(7 downto 0) or i_data.data(7 downto 0) = work.mudaq.RUN_END(7 downto 0) or i_data.data(7 downto 0) = work.mudaq.RUN_PREP_ACKNOWLEDGE(7 downto 0)) ) then
                o_rc <= i_data;
            elsif ( i_data.data(7 downto 0) = work.util.K28_4 and i_data.datak = "0001" ) then
                state <= STATE_IDLE;
                o_data <= i_data;
            else
                o_data <= i_data;
            end if;
            --
        when STATE_SC =>
            if ( i_data.datak = "0001" and i_data.data(7 downto 0) /= work.util.K28_5 and i_data.data(7 downto 0) /= work.util.K28_4 ) then
                o_rc <= i_data;
            elsif ( i_data.data(7 downto 0) = work.util.K28_4 and i_data.datak = "0001" ) then
                state <= STATE_IDLE;
                o_sc <= i_data;
            else
                o_sc <= i_data;
            end if;
            --
        when others =>
            state <= STATE_IDLE;
            --
        end case;
        --
    end if;
    end process;

end architecture;
