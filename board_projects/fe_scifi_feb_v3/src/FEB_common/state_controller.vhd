-- run start and reset state machine for AriaV frontend board
-- Protocol defined in Mu3e-Note-46 "Run Start and Reset Protocol" (Version 12.11.2018) (+ Stop reset signal)

----------------------------------
-- PLEASE READ THE README !!!!!!!
----------------------------------

--states:
--idle
--run prepare
--Sync
--running
--terminating
--link test
--sync test
--Reset
--out of DAQ

-- Martin Mueller, 2018

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mudaq.all;


ENTITY state_controller is
generic (
    FULL_VERSION_g : boolean := true--;
);
port (
    reset_link_8bData   : in    std_logic_vector(7 downto 0); -- input reset line

    fpga_addr           : in    std_logic_vector(15 downto 0); -- FPGA address input for addressed reset commands(from jumpers on final FEB board)
    runnumber           : out   std_logic_vector(31 downto 0); -- runnumber received from midas with the prep_run command
    reset_mask          : out   std_logic_vector(15 downto 0); -- payload output of the reset command
    link_test_payload   : out   std_logic_vector(15 downto 0); -- to be specified
    sync_test_payload   : out   std_logic_vector(15 downto 0); -- to be specified
    terminated          : in    std_logic; -- connect this to data merger "end of run was transmitted, run can be terminated"

    o_state             : out   run_state_t; -- state output

    i_reset_n           : in    std_logic; -- hard reset for testing
    i_clk               : in    std_logic--; -- 125 Mhz clock from reset transceiver
);
END ENTITY;

architecture rtl of state_controller is

    signal state : run_state_t;

    signal recieving_payload:               std_logic;
    signal payload_byte_counter:            integer range 0 to 10;
    signal addressing_payload_byte_counter: integer range 0 to 10;
    --signal terminated:                      std_logic;

    -- address signals
    signal addressed:           std_logic;
    signal address_part1_match: std_logic;
    signal recieving_address:   std_logic;
    signal ignoring_signals:    std_logic;

BEGIN

    -- output process
    process(i_clk, recieving_payload)
    begin
    if rising_edge(i_clk) and ( recieving_payload = '0' ) then
        o_state <= state;
    end if;
    end process;

    -- address

    trans_full: if FULL_VERSION_g generate
        --- transition process
        process(i_clk, i_reset_n, addressed)
        begin
        if ( i_reset_n = '0' ) then
            state <= RUN_STATE_IDLE;
            payload_byte_counter <= 0;
            recieving_payload <= '0';
            reset_mask <= (others =>'0');
            link_test_payload <= (others =>'0');
            sync_test_payload <= (others =>'0');
            runnumber <= (others =>'0');
            --
        elsif rising_edge(i_clk) and ( addressed = '1' ) then

            if recieving_payload = '1' then -- recieve payload
                payload_byte_counter <= payload_byte_counter - 1;
                if payload_byte_counter = 1 then
                    recieving_payload <= '0';
                end if;

                -- write payload to correct output
                case state is
                when RUN_STATE_PREP =>
                    runnumber((payload_byte_counter ) * 8 - 1 downto (payload_byte_counter-1)*8) <= reset_link_8bData;
                when RUN_STATE_LINK_TEST =>
                    link_test_payload((payload_byte_counter ) * 8 - 1 downto (payload_byte_counter-1)*8) <= reset_link_8bData;
                when RUN_STATE_SYNC_TEST =>
                    sync_test_payload((payload_byte_counter ) * 8 - 1 downto (payload_byte_counter-1)*8) <= reset_link_8bData;
                when RUN_STATE_RESET =>
                    reset_mask((payload_byte_counter ) * 8 - 1 downto (payload_byte_counter-1)*8) <= reset_link_8bData;
                when others => -- should not happen
                end case;

            else  -- command incoming --> listen and do stuff
                case state is
                ------------ idle ------------
                when RUN_STATE_IDLE =>
                    if reset_link_8bData = x"10" then -- run prepare
                        recieving_payload <= '1';
                        payload_byte_counter <= 4;
                        state <= RUN_STATE_PREP;
                    elsif reset_link_8bData = x"20" then -- start link test
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                        state <= RUN_STATE_LINK_TEST;
                    elsif reset_link_8bData = x"24" then -- start sync test
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                        state <= RUN_STATE_SYNC_TEST;
                    elsif reset_link_8bData = x"30" then -- reset
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                        state <= RUN_STATE_RESET;
                    elsif reset_link_8bData = x"33" then -- disable
                        --state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        state <= RUN_STATE_IDLE;
                    end if;

                ------------ run prepare --------------
                when RUN_STATE_PREP =>
                    if reset_link_8bData = x"11" then -- sync
                        state <= RUN_STATE_SYNC;
                    elsif reset_link_8bData = x"14" then -- abort run
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"30" then -- reset
                        state <= RUN_STATE_RESET;
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                    elsif reset_link_8bData = x"33" then -- disable
                        state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        state <= RUN_STATE_PREP;
                    end if;

                ------------ sync --------------
                when RUN_STATE_SYNC =>
                    if reset_link_8bData = x"12" then -- start run
                        state <= RUN_STATE_RUNNING;
                    elsif reset_link_8bData = x"14" then -- abort run
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"30" then -- reset
                        state <= RUN_STATE_RESET;
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                    elsif reset_link_8bData = x"33" then -- disable
                        state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        state <= RUN_STATE_SYNC;
                    end if;

                ------------ running --------------
                when RUN_STATE_RUNNING =>
                    if reset_link_8bData = x"13" then -- end run
                        state <= RUN_STATE_TERMINATING;
                    elsif reset_link_8bData = x"14" then -- abort run
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"30" then -- reset
                        state <= RUN_STATE_RESET;
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                    elsif reset_link_8bData = x"33" then -- disable
                        state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        state <= RUN_STATE_RUNNING;
                    end if;

                ------------ terminating --------------
                when RUN_STATE_TERMINATING =>
                    if terminated = '1' then -- terminating finished
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"14" then -- abort run
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"30" then -- reset
                        state <= RUN_STATE_RESET;
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                    elsif reset_link_8bData = x"33" then -- disable
                        state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        state <= RUN_STATE_TERMINATING;
                    end if;

               ------------ link test --------------
               when RUN_STATE_LINK_TEST =>
                    if reset_link_8bData = x"21" then -- stop link test
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"30" then -- reset
                        state <= RUN_STATE_RESET;
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                    elsif reset_link_8bData = x"33" then -- disable
                        state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        state <= RUN_STATE_LINK_TEST;
                    end if;

               ------------ sync test --------------
               when RUN_STATE_SYNC_TEST =>
                    if reset_link_8bData = x"25" then -- stop sync test
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"30" then -- reset
                        state <= RUN_STATE_RESET;
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                    elsif reset_link_8bData = x"33" then -- disable
                        state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        state <= RUN_STATE_SYNC_TEST;
                    end if;

                ------------ reset state --------------
                when RUN_STATE_RESET =>
                    if reset_link_8bData = x"31" then -- reset finished
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"33" then -- disable
                        state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        state <= RUN_STATE_RESET;
                    end if;

                when RUN_STATE_OUT_OF_DAQ =>
                    if reset_link_8bData = x"32" then -- enable
                        state <= RUN_STATE_IDLE;
                    end if;

                when others =>
                    state <= RUN_STATE_IDLE;

                end case;
            end if;
        end if;
        end process;
    end generate;


    trans_not_full: if not FULL_VERSION_g generate
        --- transition process
        process(i_clk, i_reset_n, addressed)
        begin
        if ( i_reset_n = '0' ) then
            state <= RUN_STATE_IDLE;
            payload_byte_counter <= 0;
            recieving_payload <= '0';
            reset_mask <= (others =>'0');
            link_test_payload <= (others =>'0');
            sync_test_payload <= (others =>'0');
            runnumber <= (others =>'0');
            --
        elsif rising_edge(i_clk) and ( addressed = '1' ) then

            if recieving_payload = '1' then -- recieve payload
                payload_byte_counter <= payload_byte_counter - 1;
                if payload_byte_counter = 1 then
                    recieving_payload <= '0';
                end if;

                -- write payload to correct output
                case state is
                when RUN_STATE_PREP =>
                    runnumber((payload_byte_counter ) * 8 - 1 downto (payload_byte_counter-1)*8) <= reset_link_8bData;
                when RUN_STATE_LINK_TEST =>
                    link_test_payload((payload_byte_counter ) * 8 - 1 downto (payload_byte_counter-1)*8) <= reset_link_8bData;
                when RUN_STATE_SYNC_TEST =>
                    sync_test_payload((payload_byte_counter ) * 8 - 1 downto (payload_byte_counter-1)*8) <= reset_link_8bData;
                when RUN_STATE_RESET =>
                    reset_mask((payload_byte_counter ) * 8 - 1 downto (payload_byte_counter-1)*8) <= reset_link_8bData;
                when others => -- should not happen
                end case;

            else  -- command incoming --> listen and do stuff
                case state is
                ------------ idle ------------
                when RUN_STATE_IDLE =>
                    if reset_link_8bData = x"10" then -- run prepare
                        recieving_payload <= '1';
                        payload_byte_counter <= 4;
                        state <= RUN_STATE_PREP;
                    --elsif reset_link_8bData = x"20" then -- start link test
                    --    recieving_payload <= '1';
                    --    payload_byte_counter <= 2;
                    --    state <= RUN_STATE_LINK_TEST;
                    --elsif reset_link_8bData = x"24" then -- start sync test
                    --    recieving_payload <= '1';
                    --    payload_byte_counter <= 2;
                    --    state <= RUN_STATE_SYNC_TEST;
                    elsif reset_link_8bData = x"30" then -- reset
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                        state <= RUN_STATE_RESET;
                    elsif reset_link_8bData = x"33" then -- disable
                        --state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        state <= RUN_STATE_IDLE;
                    end if;

                ------------ run prepare --------------
                when RUN_STATE_PREP =>
                    if reset_link_8bData = x"11" then -- sync
                        state <= RUN_STATE_SYNC;
                    elsif reset_link_8bData = x"14" then -- abort run
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"30" then -- reset
                        state <= RUN_STATE_RESET;
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                    elsif reset_link_8bData = x"33" then -- disable
                        --state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        state <= RUN_STATE_PREP;
                    end if;

                ------------ sync --------------
                when RUN_STATE_SYNC =>
                    if reset_link_8bData = x"12" then -- start run
                        state <= RUN_STATE_RUNNING;
                    elsif reset_link_8bData = x"14" then -- abort run
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"30" then -- reset
                        state <= RUN_STATE_RESET;
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                    elsif reset_link_8bData = x"33" then -- disable
                        --state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        state <= RUN_STATE_SYNC;
                    end if;

                ------------ running --------------
                when RUN_STATE_RUNNING =>
                    if reset_link_8bData = x"13" then -- end run
                        state <= RUN_STATE_TERMINATING;
                    elsif reset_link_8bData = x"14" then -- abort run
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"30" then -- reset
                        state <= RUN_STATE_RESET;
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                    elsif reset_link_8bData = x"33" then -- disable
                        --state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        state <= RUN_STATE_RUNNING;
                    end if;

                ------------ terminating --------------
                when RUN_STATE_TERMINATING =>
                    if terminated = '1' then -- terminating finished
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"14" then -- abort run
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"30" then -- reset
                        state <= RUN_STATE_RESET;
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                    elsif reset_link_8bData = x"33" then -- disable
                        --state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        state <= RUN_STATE_TERMINATING;
                    end if;

               ------------ link test --------------
               when RUN_STATE_LINK_TEST =>
                    if reset_link_8bData = x"21" then -- stop link test
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"30" then -- reset
                        state <= RUN_STATE_RESET;
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                    elsif reset_link_8bData = x"33" then -- disable
                        --state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        --state <= RUN_STATE_LINK_TEST;
                        state <= RUN_STATE_IDLE;
                    end if;

               ------------ sync test --------------
               when RUN_STATE_SYNC_TEST =>
                    if reset_link_8bData = x"25" then -- stop sync test
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"30" then -- reset
                        state <= RUN_STATE_RESET;
                        recieving_payload <= '1';
                        payload_byte_counter <= 2;
                    elsif reset_link_8bData = x"33" then -- disable
                        --state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        --state <= RUN_STATE_SYNC_TEST;
                        state <= RUN_STATE_IDLE;
                    end if;

                ------------ reset state --------------
                when RUN_STATE_RESET =>
                    if reset_link_8bData = x"31" then -- reset finished
                        state <= RUN_STATE_IDLE;
                    elsif reset_link_8bData = x"33" then -- disable
                        --state <= RUN_STATE_OUT_OF_DAQ;
                    else
                        state <= RUN_STATE_RESET;
                    end if;

                when RUN_STATE_OUT_OF_DAQ =>
                    --if reset_link_8bData = x"32" then -- enable
                        state <= RUN_STATE_IDLE;
                    --end if;

                when others =>
                    state <= RUN_STATE_IDLE;

                end case;
            end if;
        end if;
        end process;
    end generate;




    -- address process
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        addressed <= '1';
        address_part1_match <= '0';
        recieving_address   <= '0';
        ignoring_signals    <= '0';
        addressing_payload_byte_counter <= 0;
        --
    elsif rising_edge(i_clk) then

        -- address command, not part of a payload, --> compare the next 32 bits with own address
        if (recieving_payload = '0' and reset_link_8bData = x"40" and recieving_address = '0' and ignoring_signals = '0') then
            addressed <= '0';
            recieving_address  <= '1';
            address_part1_match <= '0';
            addressing_payload_byte_counter <= 2;      -- 2 byte address
        end if;


        -- recieve address for 2 cycles
        if (recieving_address = '1' and ignoring_signals = '0') then
            addressing_payload_byte_counter <= addressing_payload_byte_counter -1;

            -- check first address byte
            if (addressing_payload_byte_counter = 2 and reset_link_8bData = fpga_addr(15 downto 8)) then
                address_part1_match <= '1';
            end if;

            -- check second address byte
            if (addressing_payload_byte_counter = 1) then
                recieving_address <= '0';

                if (reset_link_8bData = fpga_addr(7 downto 0) and address_part1_match = '1') then
                    addressed <= '1'; -- address match, go into big case statement next
                    address_part1_match <= '0';

                else
                    addressed <= '0'; -- address mismatch
                end if;
            end if;
        end if;


        -- full address recieved, address mismatch  --> this command is relevant to determine the cycle where fpga should start listening again (commands have different payload sizes)
        if(addressed = '0' and addressing_payload_byte_counter = 0 and ignoring_signals = '0') then
            case reset_link_8bData is
            when x"10" => addressing_payload_byte_counter <= 4; ignoring_signals <= '1';
            when x"20" => addressing_payload_byte_counter <= 2; ignoring_signals <= '1';-- to be specified
            when x"24" => addressing_payload_byte_counter <= 2; ignoring_signals <= '1';-- to be specified
            when x"26" => addressing_payload_byte_counter <= 2; ignoring_signals <= '1';-- to be specified
            when x"30" => addressing_payload_byte_counter <= 2; ignoring_signals <= '1';
            when others => addressed <= '1'; address_part1_match <= '0'; ignoring_signals <= '0'; -- all other commands dont have payload --> back to normal
            end case;
        end if;

        if(ignoring_signals = '1') then   -- ignore payload of commands to different fpgas
            addressing_payload_byte_counter <= addressing_payload_byte_counter - 1;
            if (addressing_payload_byte_counter = 1) then
                ignoring_signals <= '0';
                addressed <= '1';
                address_part1_match <= '0';
            end if;
        end if;

    end if;
    end process;

end architecture;
