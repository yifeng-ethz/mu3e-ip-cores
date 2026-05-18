--
-- author : Marius Koeppel
-- date : 2021-11
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mudaq.all;
use work.a10_pcie_registers.all;

entity a10_reset_link is
port (
    o_datak             : out   std_logic;
    o_data              : out   std_logic_vector(7 downto 0);

    i_reset_run_number  : in    std_logic_vector(31 downto 0);
    i_reset_ctl         : in    std_logic_vector(31 downto 0);

    o_state_out         : out   std_logic_vector(31 downto 0);

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture arch of a10_reset_link is

    type reset_state_type is (
        sync, start_run, rNB0, rNB1, rNB2, rNB3, end_run,
        idle
    );
    signal reset_state : reset_state_type;
    signal reg_run_command : std_logic_vector(7 downto 0);
    signal cur_output : std_logic_vector(2 downto 0);
    signal xcvr_tx_data : std_logic_vector(7 downto 0);
    signal xcvr_tx_datak : std_logic;

begin

    o_data <=
        xcvr_tx_data when cur_output = "000" else
        xcvr_tx_data when cur_output = "111" else
        x"BC";

    o_datak <=
        xcvr_tx_datak when cur_output = "000" else
        xcvr_tx_datak when cur_output = "111" else
        '1';

    -- reset link process
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        xcvr_tx_data <= x"BC";
        xcvr_tx_datak <= '1';
        reset_state <= idle;
        cur_output <= "100";
        o_state_out <= x"00000000";
        --
    elsif rising_edge(i_clk) then
        xcvr_tx_data <= x"BC";
        xcvr_tx_datak <= '1';
        cur_output <= i_reset_ctl(RESET_LINK_FEB_RANGE);
        reg_run_command <= i_reset_ctl(RESET_LINK_COMMAND_RANGE);

        -- if we dont want to do a runstart we can just send the command
        if ( reg_run_command = x"00" and
            i_reset_ctl(RESET_LINK_COMMAND_RANGE) /= RESET_LINK_RUN_PREPARE and
            i_reset_ctl(RESET_LINK_COMMAND_RANGE) /= RESET_LINK_SYNC and
            i_reset_ctl(RESET_LINK_COMMAND_RANGE) /= RESET_LINK_START_RUN and
            i_reset_ctl(RESET_LINK_COMMAND_RANGE) /= RESET_LINK_END_RUN and
            i_reset_ctl(RESET_LINK_COMMAND_RANGE) /= x"00"
        ) then
            xcvr_tx_data <= i_reset_ctl(RESET_LINK_COMMAND_RANGE);
            xcvr_tx_datak<= '0';
            o_state_out  <= i_reset_ctl(RESET_LINK_COMMAND_RANGE) & x"000000";
            reset_state  <= idle;
        else
            case reset_state is

            when idle =>
                -- wait for run prepare
                if ( reg_run_command = x"00" and i_reset_ctl(RESET_LINK_COMMAND_RANGE) = RESET_LINK_RUN_PREPARE ) then
                    xcvr_tx_data <= RESET_LINK_RUN_PREPARE;
                    xcvr_tx_datak <= '0';
                    reset_state <= rNB0;
                    o_state_out <= RESET_LINK_RUN_PREPARE & x"000001";
                end if;

            when rNB0 =>
                xcvr_tx_data <= i_reset_run_number(7 downto 0);
                xcvr_tx_datak <= '0';
                reset_state <= rNB1;

            when rNB1 =>
                xcvr_tx_data <= i_reset_run_number(15 downto 8);
                xcvr_tx_datak <= '0';
                reset_state <= rNB2;

            when rNB2 =>
                xcvr_tx_data <= i_reset_run_number(23 downto 16);
                xcvr_tx_datak <= '0';
                reset_state <= rNB3;

            when rNB3 =>
                xcvr_tx_data <= i_reset_run_number(31 downto 24);
                xcvr_tx_datak <= '0';
                reset_state <= sync;
                o_state_out <= i_reset_run_number;

            when sync =>
                -- wait for sync
                if ( reg_run_command = x"00" and i_reset_ctl(RESET_LINK_COMMAND_RANGE) = RESET_LINK_SYNC ) then
                    xcvr_tx_data <= RESET_LINK_SYNC;
                    xcvr_tx_datak<= '0';
                    reset_state  <= start_run;
                    o_state_out  <= RESET_LINK_SYNC & x"000003";
                end if;

            when start_run =>
                -- wait for start run
                if ( reg_run_command = x"00" and i_reset_ctl(RESET_LINK_COMMAND_RANGE) = RESET_LINK_START_RUN ) then
                    xcvr_tx_data <= RESET_LINK_START_RUN;
                    xcvr_tx_datak<= '0';
                    reset_state  <= end_run;
                    o_state_out  <= RESET_LINK_START_RUN & x"000004";
                end if;

            when end_run =>
                -- wait for end run
                if ( reg_run_command = x"00" and i_reset_ctl(RESET_LINK_COMMAND_RANGE) = RESET_LINK_END_RUN ) then
                    xcvr_tx_data <= RESET_LINK_END_RUN;
                    xcvr_tx_datak<= '0';
                    reset_state  <= idle;
                    o_state_out  <= RESET_LINK_END_RUN & x"000000";
                end if;

            when others =>
                reset_state  <= idle;

            end case;
        end if;
    end if;
    end process;

end architecture;
