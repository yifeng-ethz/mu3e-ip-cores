-- sync FEB state from reset rx clk to global clock & measure phase between them
-- Martin Mueller, March 2019

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mudaq.all;

ENTITY state_phase_box is
generic (
    PHASE_WIDTH_g : positive := 16--;
);
PORT (
    -- input state (rx recovered clock)
    i_state_125_rx      : in    run_state_t;
    -- _same_ frequence as global 125 clock
    i_clk_125_rx        : in    std_logic;

    -- output state (global 125 clock)
    o_state_125         : out   run_state_t;
    i_reset_125_n       : in    std_logic;
    i_clk_125           : in    std_logic;

    o_phase             : out   std_logic_vector(PHASE_WIDTH_g-1 downto 0);
    i_reset_n           : in    std_logic;
    -- free running clock
    i_clk               : in    std_logic--;
);
END ENTITY;

architecture rtl of state_phase_box is
begin

    e_clk_phase : entity work.clk_phase
    generic map ( W => PHASE_WIDTH_g )
    port map (
        i_clk1              => i_clk_125,
        i_clk2              => i_clk_125_rx,

        o_phase             => o_phase,

        i_reset_n           => i_reset_n,
        i_clk               => i_clk--,
    );

    process(i_clk_125, i_reset_125_n)
    begin
    if ( i_reset_125_n = '0' ) then
        o_state_125 <= RUN_STATE_IDLE;
        --
    elsif rising_edge(i_clk_125) then
        if(i_state_125_rx = RUN_STATE_IDLE)        then o_state_125 <= RUN_STATE_IDLE; end if;
        if(i_state_125_rx = RUN_STATE_PREP)        then o_state_125 <= RUN_STATE_PREP; end if;
        if(i_state_125_rx = RUN_STATE_SYNC)        then o_state_125 <= RUN_STATE_SYNC; end if;
        if(i_state_125_rx = RUN_STATE_RUNNING)     then o_state_125 <= RUN_STATE_RUNNING; end if;
        if(i_state_125_rx = RUN_STATE_TERMINATING) then o_state_125 <= RUN_STATE_TERMINATING; end if;
        if(i_state_125_rx = RUN_STATE_LINK_TEST)   then o_state_125 <= RUN_STATE_LINK_TEST; end if;
        if(i_state_125_rx = RUN_STATE_SYNC_TEST)   then o_state_125 <= RUN_STATE_SYNC_TEST; end if;
        if(i_state_125_rx = RUN_STATE_RESET)       then o_state_125 <= RUN_STATE_RESET; end if;
        if(i_state_125_rx = RUN_STATE_OUT_OF_DAQ)  then o_state_125 <= RUN_STATE_OUT_OF_DAQ; end if;
        if(i_state_125_rx = RUN_STATE_IDLE)        then o_state_125 <= RUN_STATE_IDLE; end if;
    end if;
    end process;

END architecture;
