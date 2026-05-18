-----------------------------------------------------------------------------
-- DDR3 Memory controller
--
-- Niklaus Berger, JGU Mainz
-- niberger@uni-mainz.de
--
-- Marius Koeppel, JGU Mainz
-- mkoeppel@uni-mainz.de
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;
use work.a10_pcie_registers.all;

entity ddr_memory_controller is
port (
    -- Control and status registers
    i_ddr_control       : in    std_logic_vector(15 downto 0);
    o_ddr_status        : out   std_logic_vector(15 downto 0);

    o_ddr_calibrated    : out   std_logic;
    o_ddr_ready         : out   std_logic;

    i_ddr_addr          : in    std_logic_vector(25 downto 0);
    i_ddr_data          : in    std_logic_vector(511 downto 0);
    o_ddr_data          : out   std_logic_vector(511 downto 0);
    i_ddr_write         : in    std_logic;
    i_ddr_read          : in    std_logic;
    o_ddr_read_valid    : out   std_logic;

    -- Error counters
    o_error             : out   std_logic_vector(31 downto 0);

    -- IF to DDR
    i_M_cal_success     : in    std_logic;
    i_M_cal_fail        : in    std_logic;
    i_M_clk             : in    std_logic;
    i_M_reset_n         : in    std_logic;
    i_M_ready           : in    std_logic;
    o_M_read            : out   std_logic;
    o_M_write           : out   std_logic;
    o_M_address         : out   std_logic_vector(25 downto 0);
    i_M_readdata        : in    std_logic_vector(511 downto 0);
    o_M_writedata       : out   std_logic_vector(511 downto 0);
    o_M_burstcount      : out   std_logic_vector(6 downto 0);
    i_M_readdatavalid   : in    std_logic;

    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture rtl of ddr_memory_controller is

    type controller_mode_type is (disabled, waiting, ready, countertest, dataflow);
    signal mode : controller_mode_type;

    constant counter_address_1 : std_logic_vector(25 downto 0) := (others => '1');
    signal counter_read, counter_write, counter_readdatavalid, counter_readdatavalid_reg : std_logic;
    signal counter_address : std_logic_vector(25 downto 0);
    signal counter_writedata, counter_readdata : std_logic_vector(511 downto 0);

    --! counter test
    type counter_state_type is (disabled, writing, reading, done);
    signal counter_state    : counter_state_type;
    signal RWDone, started, Running : std_logic;
    signal poserr_reg, counterr_reg, timecount_reg, mycounter : std_logic_vector(31 downto 0);
    signal LastC : std_logic_vector(27 downto 0);
    signal check, pcheck : std_logic_vector(15 downto 0);

    --! sync signals to/from DDR
    signal ddr_sync_data_in, wdata_sync_data_in : std_logic_vector(512 + 1 - 1 downto 0);
    signal ddr_sync_status_in, wdata_sync_status_in : std_logic_vector(3 downto 0);
    signal ddr_sync_out, wdata_sync_out, wdata : std_logic_vector(512 + 26 + 1 + 1 - 1 downto 0);
    signal we, wfull, rempty, rack, we_in, wfull_in, rempty_in, rack_in : std_logic;

    --! internal input signals
    signal M_write, M_read, M_cal_success, M_cal_fail, M_reset_n, M_ready, M_readdatavalid : std_logic;
    signal M_address : std_logic_vector(25 downto 0);
    signal M_writedata, M_readdata : std_logic_vector(511 downto 0);

begin

    --! sync incoming signals from DDR
    --                              1             1              1                 1
    wdata_sync_status_in <= i_M_ready & i_M_reset_n & i_M_cal_fail & i_M_cal_success;
    e_sync_status_in : entity work.fifo_sync
    generic map(
        g_WREG_N => 1,
        g_RREG_N => 1,
        g_DATA_RESET => (ddr_sync_status_in'range => '0')--,
    )
    port map (
        i_wdata => wdata_sync_status_in,
        i_wclk => i_M_clk, i_wreset_n => '1',
        o_rdata => ddr_sync_status_in,
        i_rclk => i_clk, i_rreset_n => '1'--,
    );
    --                              512                   1
    wdata_sync_data_in <=  i_M_readdata & i_M_readdatavalid;
    e_sync_data_in : entity work.ip_dcfifo_v2
    generic map (
        g_ADDR_WIDTH => 8,
        g_WREG_N     => 1,
        g_RREG_N     => 1,
        g_DATA_WIDTH => wdata_sync_data_in'length--,
    )
    port map (
        i_we        => we_in,
        i_wdata     => wdata_sync_data_in,
        o_wfull     => wfull_in,
        i_wclk      => i_M_clk,

        i_rack      => rack_in,
        o_rdata     => ddr_sync_data_in,
        o_rempty    => rempty_in,
        i_rclk      => i_clk,

        i_reset_n   => i_reset_n--,
    );
    --! write logic sync in FIFO
    --! NOTE: since we only read from the slower clock side we make sure here
    --! that the FIFO does not get full by only writing if the data is valid
    we_in <= not wfull_in and i_M_readdatavalid;
    --! read logic for sync in FIFO
    rack_in <= not rempty_in;
    M_cal_success <= ddr_sync_status_in(0);
    M_cal_fail <= ddr_sync_status_in(1);
    M_reset_n <= ddr_sync_status_in(2);
    M_ready <= ddr_sync_status_in(3);
    M_readdatavalid <= ddr_sync_data_in(0) and not rempty_in;
    M_readdata <= ddr_sync_data_in(512 downto 1);

    --! sync outcoming signals to DDR
    --                        512          26         1        1
    wdata_sync_out <= M_writedata & M_address & M_write & M_read;
    e_sync_out : entity work.ip_dcfifo_v2
    generic map (
        g_ADDR_WIDTH => 8,
        g_WREG_N     => 1,
        g_RREG_N     => 1,
        g_DATA_WIDTH => wdata_sync_out'length--,
    )
    port map (
        i_we        => we,
        i_wdata     => wdata,
        o_wfull     => wfull,
        i_wclk      => i_clk,

        i_rack      => rack,
        o_rdata     => ddr_sync_out,
        o_rempty    => rempty,
        i_rclk      => i_M_clk,

        i_reset_n   => i_reset_n--,
    );
    --! write process sync out FIFO
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        we <= '0';
        --
    elsif rising_edge(i_clk) then
        wdata <= wdata_sync_out;
        we <= not wfull;
        --
    end if;
    end process;
    --! read logic for sync out FIFO, we dont read if the DDR is not ready
    rack <= '1' when not rempty and i_M_ready else '0';
    o_M_read <= ddr_sync_out(0) when not rempty and i_M_ready else '0';
    o_M_write <= ddr_sync_out(1) when not rempty and i_M_ready else '0';
    o_M_address <= ddr_sync_out(25+2 downto 1+1);
    o_M_writedata <= ddr_sync_out(511+26+2 downto 25+2+1);

    --! HW burst size
    o_M_burstcount <= "0000001";

    --! counter forwarding
    o_error   <=    poserr_reg      when i_ddr_control(DDR_COUNTERSEL_RANGE_A) = "01" else
                    counterr_reg    when i_ddr_control(DDR_COUNTERSEL_RANGE_A) = "10" else
                    timecount_reg;

    --! status register
    o_ddr_status(DDR_BIT_CAL_SUCCESS)  <= M_cal_success;
    o_ddr_status(DDR_BIT_CAL_FAIL)     <= M_cal_fail;
    o_ddr_status(DDR_BIT_RESET_N)      <= M_reset_n;
    o_ddr_status(DDR_BIT_READY)        <= M_ready;
    o_ddr_status(DDR_BIT_TEST_WRITING) <= '1' when counter_state = writing else '0';
    o_ddr_status(DDR_BIT_TEST_READING) <= '1' when counter_state = reading else '0';
    o_ddr_status(DDR_BIT_TEST_DONE)    <= '1' when counter_state = done else '0';

    --! dataflow out
    o_ddr_read_valid <= M_readdatavalid when mode = dataflow else '0';
    o_ddr_data <= M_readdata;
    o_ddr_ready <= M_ready;
    o_ddr_calibrated <= M_cal_success;

    --! mode MUX
    M_read  <=  counter_read  when mode = countertest else
                i_ddr_read    when mode = dataflow    else
                '0';

    M_write <=  counter_write when mode = countertest else
                i_ddr_write   when mode = dataflow    else
                '0';

    M_address   <=  counter_address   when mode = countertest else
                    i_ddr_addr        when mode = dataflow    else
                    (others => '0');

    M_writedata <=  counter_writedata when mode = countertest else
                    i_ddr_data        when mode = dataflow    else
                    (others => '0');

    --! Mode state machine
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        mode <= disabled;
        --
    elsif rising_edge(i_clk) then
        case mode is
        when disabled =>
            if ( i_ddr_control(DDR_BIT_ENABLE_A) = '1' ) then
                mode <= waiting;
            end if;
        when waiting =>
            if ( M_reset_n = '1' and M_cal_success = '1' ) then
                mode <= ready;
            end if;
        when ready =>
            if ( i_ddr_control(DDR_BIT_COUNTERTEST_A) = '1' ) then
                mode <= countertest;
            else
                mode <= dataflow;
            end if;
        when countertest =>
            if ( i_ddr_control(DDR_BIT_COUNTERTEST_A) = '0' ) then
                mode <= ready;
            end if;
        when dataflow =>
            if ( i_ddr_control(DDR_BIT_COUNTERTEST_A) = '1' ) then
                mode <= ready;
            end if;
        end case;
    end if;
    end process;

    --! counter test state machine
    process(i_clk, i_reset_n)
        variable counter_var : std_logic_vector(31 downto 0);
    begin
    if ( i_reset_n = '0' ) then
        counter_state       <= disabled;
        counter_read        <= '0';
        counter_write       <= '0';
        counter_readdatavalid <= '0';
        counter_readdatavalid_reg <= '0';
        --
    elsif rising_edge(i_clk) then

        counter_read    <= '0';
        counter_write   <= '0';

        -- Register once to ease timing
        counter_readdata                <= M_readdata;
        counter_readdatavalid           <= M_readdatavalid;
        counter_readdatavalid_reg       <= counter_readdatavalid;

        case counter_state is
        when disabled =>

            if ( mode = countertest and M_ready = '1' ) then
                counter_state <= writing;
            end if;
            mycounter       <= (others => '1');
            counter_address <= (others => '1');
            RWDone          <= '0';
            Running         <= '0';
            poserr_reg      <= (others => '0');
            counterr_reg    <= (others => '0');
            timecount_reg   <= (others => '0');
            started         <= '0';

        when writing =>

            timecount_reg <= timecount_reg + '1';
            counter_write <= '1';

            if ( M_ready = '1' ) then
                started         <= '1';
                counter_var     := mycounter + '1';
                mycounter       <= mycounter + '1';
                counter_address <= counter_address + '1';
            else
                counter_var := mycounter;
            end if;

            counter_writedata <= X"1" & counter_var(27 downto 0) &
                                 X"2" & counter_var(27 downto 0) &
                                 X"3" & counter_var(27 downto 0) &
                                 X"4" & counter_var(27 downto 0) &
                                 X"5" & counter_var(27 downto 0) &
                                 X"6" & counter_var(27 downto 0) &
                                 X"7" & counter_var(27 downto 0) &
                                 X"8" & counter_var(27 downto 0) &
                                 X"9" & counter_var(27 downto 0) &
                                 X"A" & counter_var(27 downto 0) &
                                 X"B" & counter_var(27 downto 0) &
                                 X"C" & counter_var(27 downto 0) &
                                 X"D" & counter_var(27 downto 0) &
                                 X"E" & counter_var(27 downto 0) &
                                 X"F" & counter_var(27 downto 0) &
                                 X"0" & counter_var(27 downto 0);

            if ( counter_address = counter_address_1 and started = '1' ) then
                RWDone <= '1';
                counter_write <= '0';
            end if;

            if ( RWDone = '1' ) then
                counter_write <= '0';
                counter_state <= reading;
                counter_address <= (others => '1');
                RWDone <= '0';
                started <= '0';
            end if;

        when reading =>

            timecount_reg <= timecount_reg + '1';
            counter_read <= M_ready;

            if ( M_ready = '1' ) then
                counter_address <= counter_address + '1';
                started         <= '1';
            end if;

            if ( counter_address = counter_address_1 and started = '1' ) then
                RWDone <= '1';
                counter_read <= '0';
            end if;

            if ( RWDone = '1' ) then
                counter_state <= done;
            end if;

            pcheck  <= (others => '0');
            check   <= (others => '0');

            if ( counter_readdatavalid = '1' ) then
                Running <= '1';
                LastC   <= counter_readdata(27 downto 0) + '1';

                if ( Running = '1' ) then
                    if ( counter_readdata(31 downto 28) /= X"0" ) then
                        pcheck(0) <= '1';
                    end if;
                    if ( counter_readdata(63 downto 60) /= X"F" ) then
                        pcheck(1) <= '1';
                    end if;
                    if ( counter_readdata(95 downto 92) /= X"E") then
                        pcheck(2) <= '1';
                    end if;
                    if ( counter_readdata(127 downto 124) /= X"D" ) then
                        pcheck(3) <= '1';
                    end if;
                    if ( counter_readdata(159 downto 156) /= X"C" ) then
                        pcheck(4) <= '1';
                    end if;
                    if ( counter_readdata(191 downto 188) /= X"B" ) then
                        pcheck(5) <= '1';
                    end if;
                    if ( counter_readdata(223 downto 220) /= X"A" ) then
                        pcheck(6) <= '1';
                    end if;
                    if ( counter_readdata(255 downto 252) /= X"9" ) then
                        pcheck(7) <= '1';
                    end if;
                    if ( counter_readdata(287 downto 284) /= X"8" ) then
                        pcheck(8) <= '1';
                    end if;
                    if ( counter_readdata(319 downto 316) /= X"7" ) then
                        pcheck(9) <= '1';
                    end if;
                    if ( counter_readdata(351 downto 348) /= X"6" ) then
                        pcheck(10) <= '1';
                    end if;
                    if ( counter_readdata(383 downto 380) /= X"5" ) then
                        pcheck(11) <= '1';
                    end if;
                    if ( counter_readdata(415 downto 412) /= X"4" ) then
                        pcheck(12) <= '1';
                    end if;
                    if ( counter_readdata(447 downto 444) /= X"3" ) then
                        pcheck(13) <= '1';
                    end if;
                    if ( counter_readdata(479 downto 476) /= X"2" ) then
                        pcheck(14) <= '1';
                    end if;
                    if ( counter_readdata(511 downto 508) /= X"1" ) then
                        pcheck(15) <= '1';
                    end if;

                    if ( counter_readdata(27 downto 0) /= LastC ) then
                        check(0) <= '1';
                    end if;
                    if ( counter_readdata(59 downto 32) /= LastC ) then
                        check(1) <= '1';
                    end if;
                    if ( counter_readdata(91 downto 64) /= LastC ) then
                        check(2) <= '1';
                    end if;
                    if ( counter_readdata(123 downto 96) /= LastC ) then
                        check(3) <= '1';
                    end if;
                    if ( counter_readdata(155 downto 128) /= LastC ) then
                        check(4) <= '1';
                    end if;
                    if ( counter_readdata(187 downto 160) /= LastC ) then
                        check(5) <= '1';
                    end if;
                    if ( counter_readdata(219 downto 192) /= LastC ) then
                        check(6) <= '1';
                    end if;
                    if ( counter_readdata(251 downto 224) /= LastC ) then
                        check(7) <= '1';
                    end if;
                    if ( counter_readdata(283 downto 256) /= LastC ) then
                        check(8) <= '1';
                    end if;
                    if ( counter_readdata(315 downto 288) /= LastC ) then
                        check(9) <= '1';
                    end if;
                    if ( counter_readdata(347 downto 320) /= LastC ) then
                        check(10) <= '1';
                    end if;
                    if ( counter_readdata(379 downto 352) /= LastC ) then
                        check(11) <= '1';
                    end if;
                    if ( counter_readdata(411 downto 384) /= LastC ) then
                        check(12) <= '1';
                    end if;
                    if ( counter_readdata(443 downto 416) /= LastC ) then
                        check(13) <= '1';
                    end if;
                    if ( counter_readdata(475 downto 448) /= LastC ) then
                        check(14) <= '1';
                    end if;
                    if ( counter_readdata(507 downto 480) /= LastC ) then
                        check(15) <= '1';
                    end if;
                end if;
            end if;

            if ( counter_readdatavalid_reg = '1' ) then
                if ( pcheck /= 0 ) then
                    poserr_reg <= poserr_reg + '1';
                end if;
                if ( check /= 0 ) then
                    counterr_reg <= counterr_reg + '1';
                end if;
            end if;

        when done =>
            if ( mode /= countertest ) then
                counter_state <= disabled;
            end if;

        end case;
    end if;
    end process;

end architecture;
