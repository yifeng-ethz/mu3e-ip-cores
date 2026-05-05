-- M.Mueller, November 2020

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

use work.feb_sc_registers.all;
use work.mudaq.all;

entity feb_reg_mapping is
generic (
    N_LINKS : positive := 1--;
);
port (
    i_reg_add                   : in  std_logic_vector(15 downto 0);
    i_reg_re                    : in  std_logic;
    o_reg_rdata                 : out std_logic_vector(31 downto 0);
    i_reg_we                    : in  std_logic;
    i_reg_wdata                 : in  std_logic_vector(31 downto 0);

    -- inputs  156--------------------------------------------
    -- ALL INPUTS DEFAULT TO (n*4-1 downto 0 => x"CCC..", others => '1')
    i_run_state_156             : in    run_state_t                   := RUN_STATE_UNDEFINED;
    i_merger_rate_count         : in    std_logic_vector(31 downto 0) := x"CCCCCCCC";
    i_reset_phase               : in    std_logic_vector(15 downto 0) := x"CCCC";
    i_arriaV_temperature        : in    std_logic_vector( 7 downto 0) := x"CC";
    i_fpga_type                 : in    std_logic_vector( 5 downto 0) := "111100";
    i_adc_reg                   : in    slv32_array_t( 4 downto 0) := (others => x"CCCCCCCC");
    i_max10_version             : in    std_logic_vector(31 downto 0) := x"CCCCCCCC";
    i_max10_status              : in    std_logic_vector(31 downto 0) := x"CCCCCCCC";
    i_programming_status        : in    std_logic_vector(31 downto 0) := x"CCCCCCCC";
    i_run_start_denial_reason   : in    std_logic_vector(31 downto 0) := (others => '0');
    i_run_number                : in    std_logic_vector(31 downto 0) := (others => '0');

    i_ffly_pwr                  : in    std_logic_vector(127 downto 0); -- RX optical power in mW
    i_ffly_temp                 : in    std_logic_vector(15 downto 0);  -- temperature in °C
    i_ffly_alarm                : in    std_logic_vector(63 downto 0);  -- latched alarm bits
    i_ffly_vcc                  : in    std_logic_vector(31 downto 0);  -- operating voltagein units of 100 uV

    i_si45_intr_n               : in    std_logic_vector(1 downto 0);
    i_si45_lol_n                : in    std_logic_vector(1 downto 0);

    -- outputs 156--------------------------------------------
    o_reg_cmdlen                : out std_logic_vector(31 downto 0);
    o_reg_offset                : out std_logic_vector(31 downto 0);
    o_reg_reset_bypass          : out std_logic_vector(15 downto 0);
    o_reg_reset_bypass_payload  : out std_logic_vector(31 downto 0);
    o_arriaV_temperature_clr    : out std_logic;
    o_arriaV_temperature_ce     : out std_logic;
    o_fpga_id_reg               : out std_logic_vector(N_LINKS*16-1 downto 0);
    o_programming_ctrl          : out std_logic_vector(31 downto 0);
    o_programming_data          : out std_logic_vector(31 downto 0);
    o_programming_data_ena      : out std_logic;
    o_programming_addr          : out std_logic_vector(31 downto 0);
    o_programming_addr_ena      : out std_logic;
    o_nios_reboot               : out std_logic;
    o_shutdown                  : out std_logic := '0';

    i_testout                   : in  std_logic_vector(31 downto 0);

    i_reset_n                   : in  std_logic;
    i_clk                       : in  std_logic--;
);
end entity;

architecture rtl of feb_reg_mapping is
-- outputs
    signal reg_cmdlen               : std_logic_vector(31 downto 0);
    signal reg_offset               : std_logic_vector(31 downto 0);
    signal reg_reset_bypass         : std_logic_vector(15 downto 0);
    signal reg_reset_bypass_payload : std_logic_vector(31 downto 0);
    signal fpga_id_reg              : std_logic_vector(N_LINKS*16-1 downto 0);

-- inputs
    signal run_state_156            : run_state_t;
    signal merger_rate_count        : std_logic_vector(31 downto 0);
    signal reset_phase              : std_logic_vector(15 downto 0);
    signal arriaV_temperature       : std_logic_vector( 7 downto 0);
    signal fpga_type                : std_logic_vector( 5 downto 0);
    signal adc_reg                  : slv32_array_t( 4 downto 0);

-- R/W test signals
    signal test_read                : std_logic;
    signal test_write               : std_logic;
    signal test_read_data           : std_logic_vector(31 downto 0);
    signal test_write_data          : std_logic_vector(31 downto 0);

-- Prolong enable
    signal addr_ena_del             : std_logic_vector(5 downto 0);

    signal testout                  : std_logic_vector(31 downto 0);
    signal nios_reboot              : std_logic;
begin

    o_nios_reboot <= nios_reboot;

    process(i_clk, i_reset_n)
        variable regaddr : integer;
    begin
    if i_reset_n = '0' then
        o_programming_ctrl <= (others => '0');
        o_programming_data_ena  <= '0';
        o_programming_addr_ena  <= '0';
        nios_reboot             <= '0';
        --
    elsif rising_edge(i_clk) then
        o_reg_rdata         <= X"CCCCCCCC";
        regaddr             := to_integer(unsigned(i_reg_add));

        o_programming_data_ena  <= '0';
        if(addr_ena_del = "000000") then -- this is here so that the 50 MHz clock does not miss the ena signal ? (M.Mueller)
            o_programming_addr_ena  <= '0';
        else
            o_programming_addr_ena  <= '1';
        end if;

        addr_ena_del <= addr_ena_del(4 downto 0) & '0';

        test_read           <= '0';
        test_write          <= '0';

        o_reg_cmdlen                <= reg_cmdlen;
        o_reg_offset                <= reg_offset;
        o_reg_reset_bypass          <= reg_reset_bypass;
        o_reg_reset_bypass_payload  <= reg_reset_bypass_payload;
        o_fpga_id_reg               <= fpga_id_reg;
        --o_testout                   <= testout;
        testout                     <=i_testout;

        run_state_156               <= i_run_state_156;
        merger_rate_count           <= i_merger_rate_count;
        reset_phase                 <= i_reset_phase;
        arriaV_temperature          <= i_arriaV_temperature;
        adc_reg                     <= i_adc_reg;


        -- cmdlen
        if ( regaddr = CMD_LEN_REGISTER_RW and i_reg_re = '1' ) then
            o_reg_rdata <= reg_cmdlen;
        end if;
        if ( regaddr = CMD_LEN_REGISTER_RW and i_reg_we = '1' ) then
            reg_cmdlen <= i_reg_wdata;
        end if;

        -- offset
        if ( regaddr = CMD_OFFSET_REGISTER_RW and i_reg_re = '1' ) then
            o_reg_rdata <= reg_offset;
        end if;
        if ( regaddr = CMD_OFFSET_REGISTER_RW and i_reg_we = '1' ) then
            reg_offset <= i_reg_wdata;
        end if;

        -- reset bypass
        if ( regaddr = RUN_STATE_RESET_BYPASS_REGISTER_RW and i_reg_re = '1' ) then
            o_reg_rdata(15 downto 0) <= reg_reset_bypass(15 downto 0);
            o_reg_rdata(16+9 downto 16) <= run_state_156;
        end if;
        if ( regaddr = RUN_STATE_RESET_BYPASS_REGISTER_RW and i_reg_we = '1' ) then
            reg_reset_bypass(15 downto 0) <= i_reg_wdata(15 downto 0); -- upper bits are read-only status
        end if;

        -- reset payload
        if ( regaddr = RESET_PAYLOAD_REGISTER_RW and i_reg_re = '1' ) then
            o_reg_rdata <= reg_reset_bypass_payload;
        end if;
        if ( regaddr = RESET_PAYLOAD_REGISTER_RW and i_reg_we = '1' ) then
            reg_reset_bypass_payload <= i_reg_wdata;
        end if;

        -- rate measurement
        if ( regaddr = MERGER_RATE_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= merger_rate_count;
        end if;

        -- reset phase
        if ( regaddr = RESET_PHASE_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= x"0000" & reset_phase;
        end if;

        -- ArriaV temperature
        if ( regaddr = ARRIA_TEMP_REGISTER_RW and i_reg_re = '1' ) then
            o_reg_rdata <= x"000000" & arriaV_temperature;
        end if;
        if ( regaddr = ARRIA_TEMP_REGISTER_RW and i_reg_we = '1' ) then
            o_arriaV_temperature_clr  <= i_reg_wdata(0);
            o_arriaV_temperature_ce   <= i_reg_wdata(1);
        end if;

        -- mscb

        -- git head hash
        if ( regaddr = GIT_HASH_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= (others => '0');
            o_reg_rdata <= GIT_HEAD_INT32(work.cmp.GIT_HEAD);
        end if;
        -- fpga id
        if ( regaddr = FPGA_ID_REGISTER_RW and i_reg_re = '1' ) then
            o_reg_rdata <= (others => '0');
            o_reg_rdata(fpga_id_reg'range) <= fpga_id_reg;
        end if;
        if ( regaddr = FPGA_ID_REGISTER_RW and i_reg_we = '1' ) then
            o_reg_rdata <= (others => '0');
            fpga_id_reg(N_LINKS*16-1 downto 0) <= i_reg_wdata(N_LINKS*16-1 downto 0);
        end if;
        -- fpga type
        if ( regaddr = FPGA_TYPE_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= (others => '0');
            o_reg_rdata(i_fpga_type'range) <= i_fpga_type;
        end if;
        --max ADC data--
        if ( regaddr = MAX10_ADC_0_1_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= adc_reg(0);
        end if;
        if ( regaddr = MAX10_ADC_2_3_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= adc_reg(1);
        end if;
        if ( regaddr = MAX10_ADC_4_5_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= adc_reg(2);
        end if;
        if ( regaddr = MAX10_ADC_6_7_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= adc_reg(3);
        end if;
        if ( regaddr = MAX10_ADC_8_9_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= adc_reg(4);
        end if;
        -- Max firmware version
        if ( regaddr = MAX10_VERSION_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= i_max10_version;
        end if;
        -- Max status
        if ( regaddr = MAX10_STATUS_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= i_max10_status;
        end if;
        -- Programming
        if ( regaddr = PROGRAMMING_STATUS_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= i_programming_status;
        end if;
        if ( regaddr = PROGRAMMING_CTRL_REGISTER_W and i_reg_we = '1' ) then
            o_programming_ctrl  <= i_reg_wdata;
        end if;
        if ( regaddr = PROGRAMMING_ADDR_REGISTER_W and i_reg_we = '1' ) then
            o_programming_addr  <= i_reg_wdata;
            o_programming_addr_ena  <= '1';
            addr_ena_del <= "111111";
        end if;
        if ( regaddr = PROGRAMMING_DATA_REGISTER_W and i_reg_we = '1' ) then
            o_programming_data  <= i_reg_wdata;
            o_programming_data_ena  <= '1';
        end if;

        -- Fireflies
        if ( regaddr = FIREFLY1_TEMP_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= x"000000" & i_ffly_temp(7 downto 0);
        end if;
        if ( regaddr = FIREFLY2_TEMP_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= x"000000" & i_ffly_temp(15 downto 8);
        end if;
        if ( regaddr = FIREFLY1_VOLT_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= x"0000" & i_ffly_vcc(15 downto 0);
        end if;
        if ( regaddr = FIREFLY2_VOLT_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= x"0000" & i_ffly_vcc(31 downto 16);
        end if;
        if ( regaddr = FIREFLY1_RX1_POW_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= x"0000" & i_ffly_pwr(15 downto 0);
        end if;
        if ( regaddr = FIREFLY1_RX2_POW_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= x"0000" & i_ffly_pwr(31 downto 16);
        end if;
        if ( regaddr = FIREFLY1_RX3_POW_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= x"0000" & i_ffly_pwr(47 downto 32);
        end if;
        if ( regaddr = FIREFLY1_RX4_POW_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= x"0000" & i_ffly_pwr(63 downto 48);
        end if;
        if ( regaddr = FIREFLY2_RX1_POW_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= x"0000" & i_ffly_pwr(79 downto 64);
        end if;
        if ( regaddr = FIREFLY2_RX2_POW_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= x"0000" & i_ffly_pwr(95 downto 80);
        end if;
        if ( regaddr = FIREFLY2_RX3_POW_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= x"0000" & i_ffly_pwr(111 downto 96);
        end if;
        if ( regaddr = FIREFLY2_RX4_POW_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= x"0000" & i_ffly_pwr(127 downto 112);
        end if;
        if ( regaddr = FIREFLY1_ALARM_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= i_ffly_alarm(31 downto 0);
        end if;
        if ( regaddr = FIREFLY2_ALARM_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= i_ffly_alarm(63 downto 32);
        end if;

        -- SI chips
        if ( regaddr = SI_STATUS_REGISTER and i_reg_re = '1' ) then
            o_reg_rdata(1 downto 0) <= i_si45_intr_n;
            o_reg_rdata(3 downto 2) <= i_si45_lol_n;
            o_reg_rdata(31 downto 4) <= (others => '0');
        end if;

        if ( regaddr = REBOOT_REGISTER_RW and i_reg_re = '1' ) then
            o_reg_rdata(0)              <= nios_reboot;
            o_reg_rdata(31 downto 0)    <= (others => '0');
        end if;
        if ( regaddr = REBOOT_REGISTER_RW and i_reg_we = '1' ) then
            nios_reboot <= i_reg_wdata(0);
        end if;

        if ( regaddr = SHUTDOWN_REGISTER_RW and i_reg_we = '1' ) then
            o_shutdown <= '1';
        end if;

        if ( regaddr = RUN_START_DENIAL_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= i_run_start_denial_reason;
        end if;

        if ( regaddr = RUN_NUMBER_REGISTER_R and i_reg_re = '1' ) then
            o_reg_rdata <= i_run_number;
        end if;

        -- testout
        if ( regaddr = TEST_OUT_REGISTER and i_reg_re = '1' ) then
            o_reg_rdata <= testout;
        end if;
        if ( regaddr = TEST_OUT_REGISTER and i_reg_we = '1' ) then
            --testout <= i_reg_wdata;
        end if;

        -- NON-incrementing reads/writes TEST
--        if ( regaddr = NONINCREMENTING_TEST_REGISTER_RW and i_reg_re = '1' ) then
--            o_reg_rdata <= test_read_data;
--            test_read   <= '1';
--        end if;
--        if ( regaddr = NONINCREMENTING_TEST_REGISTER_RW and i_reg_we = '1' ) then
--            test_write_data <= i_reg_wdata;
--            test_write      <= '1';
--        end if;

    end if;
    end process;

    --nonincrementing_rw_test_fifo : entity work.ip_scfifo_v2
    --generic map (
    --    g_ADDR_WIDTH      => 4,
    --    g_DATA_WIDTH      => 32--,
    --)
    --port map (
    --    i_we        => test_write,
    --    i_wdata     => test_write_data,
    --
    --    i_rack      => test_read,
    --    o_rdata     => test_read_data,
    --
    --    i_reset_n   => '1',
    --    i_clk       => i_clk_156--,
    --);

end architecture;
