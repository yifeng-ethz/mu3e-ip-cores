----------------------------------------------------------------------------
-- I2C reading of firefly regs, FEB V2
-- Martin Mueller muellem@uni-mainz.de
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.firefly_constants.all;

entity firefly_i2c is
generic (
	I2C_BAUD_RATE 		: natural := 400_000;
    g_DELAY_MS 			: integer := 1000;
    CLK_FREQ 			: natural := 156250_000--;
);
port (
    --I2C
    i_i2c_enable    : in    std_logic;
    o_Mod_Sel_n     : out   std_logic_vector(1 downto 0);
    io_scl          : inout std_logic;
    io_sda          : inout std_logic;
   
    o_pwr           : out   std_logic_vector(127 downto 0); -- RX optical power in mW
    o_temp          : out   std_logic_vector(15 downto 0);  -- temperature in °C
    o_alarm         : out   std_logic_vector(63 downto 0);  -- latched alarm bits
    o_vcc           : out   std_logic_vector(31 downto 0);  -- operating voltagein units of 100 uV

    i_clk           : in    std_logic;
    i_reset_n       : in    std_logic--;
);
end entity;

architecture rtl of firefly_i2c is

    -- i2c signals --------------------------------------------
    signal i2c_rw               : std_logic;
    signal i2c_ena              : std_logic;
    signal i2c_busy             : std_logic;
    signal i2c_busy_prev        : std_logic;
    signal i2c_addr             : std_logic_vector(6 downto 0);
    signal i2c_data_rd          : std_logic_vector(7 downto 0);
    signal i2c_data_wr          : std_logic_vector(7 downto 0);
    type   i2c_state_type         is (idle, waiting1, i2cffly1);
    signal i2c_state            : i2c_state_type;
    signal i2c_counter          : unsigned(31 downto 0);
    signal i2c_modSel           : integer range 0 to 2;
    signal i2c_ch               : integer range 0 to 4;
    signal busy_cnt             : integer := 0;

begin

    firefly_i2c_master: entity work.i2c_master
    generic map (
        input_clk   => CLK_FREQ,  --input clock speed from user logic in Hz
        bus_clk     => I2C_BAUD_RATE--,   --speed the i2c bus (scl) will run at in Hz
    )
    port map (
        clk         => i_clk,
        reset_n     => i_reset_n,
        ena         => i2c_ena,
        addr        => i2c_addr,
        rw          => i2c_rw,
        data_wr     => i2c_data_wr,
        busy        => i2c_busy,
        data_rd     => i2c_data_rd,
        ack_error   => open,
        sda         => io_sda,
        scl         => io_scl--,
    );

    process(i_clk, i_reset_n)
    begin
    if(i_reset_n = '0') then
        i2c_state       <= idle;
        i2c_ena         <= '0';
        i2c_modSel      <=  0;
        i2c_rw          <= '1';
        i2c_busy_prev   <= '0';
        i2c_counter     <= (others => '0');
        i2c_ch          <=  0;
        busy_cnt        <=  0;

    elsif rising_edge(i_clk) then
        if i2c_modSel = 1 then
            o_Mod_Sel_n <= "10";
        elsif i2c_modSel = 2 then
            o_Mod_Sel_n <= "01";
        else
            o_Mod_Sel_n <= "11";
        end if;

        case i2c_state is
        when idle =>
            i2c_counter     <= (others => '0');
            if(i_i2c_enable = '1') then
                i2c_state       <= waiting1;
                if i2c_modSel = 1 then
                    i2c_modSel <= 2;
                elsif i2c_modSel = 2 then
                    i2c_modSel <= 1;
                else
                    i2c_modSel <= 1;
                end if;
			else -- add to avoid latch and prevent bug
				i2c_state		<= idle;
				i2c_modSel		<= 0;
            end if;
        when waiting1 =>
            i2c_ch          <= 0;
            i2c_counter     <= i2c_counter + 1;
            if(i2c_counter > integer(real(g_DELAY_MS)*real(CLK_FREQ)/1000.0)) then -- wait for assert time of mod_sel (a few hundred ms)
                i2c_state       <= i2cffly1;
            end if;

        when i2cffly1 => -- i2c transaction with firefly modSel
            i2c_busy_prev   <= i2c_busy;
            i2c_counter     <= (others => '0');
            if(i2c_busy_prev = '0' AND i2c_busy = '1') then
                busy_cnt    <= busy_cnt + 1;
            end if;

            case busy_cnt is
            when 0 =>
                i2c_ena     <= '1';
                i2c_addr    <= FFLY_DEV_ADDR_7;
                i2c_rw      <= '0'; -- 0: write, 1: read
                i2c_data_wr <= ADDR_TEMPERATURE;
            when 1 =>
                i2c_rw      <= '1';
            when 2 =>
                i2c_rw      <= '0';
                i2c_data_wr <= ADDR_RX_PWR(0);
                if(i2c_busy = '0') then
                    o_temp((i2c_modSel-1)*8+7 downto (i2c_modSel-1)*8) <= i2c_data_rd; -- read data from busy_cnt = 1
                    --i2c_ch <= 1;
                end if;
            when 3 =>
                i2c_rw      <= '1';
            when 4 =>
                i2c_rw      <= '0';
                i2c_data_wr <= ADDR_RX_PWR(1);
                if(i2c_busy = '0') then
                    o_pwr((i2c_modSel-1)*64+15 downto (i2c_modSel-1)*64+8) <= i2c_data_rd;
                end if;
            when 5 =>
                i2c_rw      <= '1';
            when 6 =>
                i2c_rw      <= '0';
                i2c_data_wr <= ADDR_RX_PWR(2);
                if(i2c_busy = '0') then
                    o_pwr((i2c_modSel-1)*64+7 downto (i2c_modSel-1)*64) <= i2c_data_rd;
                end if;
            when 7 =>
                i2c_rw      <= '1';
            when 8 =>
                i2c_rw      <= '0';
                i2c_data_wr <= ADDR_RX_PWR(3);
                if(i2c_busy = '0') then
                    o_pwr((i2c_modSel-1)*64+31 downto (i2c_modSel-1)*64+24) <= i2c_data_rd;
                end if;
            when 9 =>
                i2c_rw      <= '1';
            when 10 =>
                i2c_rw      <= '0';
                i2c_data_wr <= ADDR_RX_PWR(4);
                if(i2c_busy = '0') then
                    o_pwr((i2c_modSel-1)*64+23 downto (i2c_modSel-1)*64+16) <= i2c_data_rd;
                end if;
            when 11 =>
                i2c_rw      <= '1';
            when 12 =>
                i2c_rw      <= '0';
                i2c_data_wr <= ADDR_RX_PWR(5);
                if(i2c_busy = '0') then
                    o_pwr((i2c_modSel-1)*64+47 downto (i2c_modSel-1)*64+40) <= i2c_data_rd;
                end if;
            when 13 =>
                i2c_rw      <= '1';
            when 14 =>
                i2c_rw      <= '0';
                i2c_data_wr <= ADDR_RX_PWR(6);
                if(i2c_busy = '0') then
                    o_pwr((i2c_modSel-1)*64+39 downto (i2c_modSel-1)*64+32) <= i2c_data_rd;
                end if;
            when 15 =>
                i2c_rw      <= '1';
            when 16 =>
                i2c_rw      <= '0';
                i2c_data_wr <= ADDR_RX_PWR(7);
                if(i2c_busy = '0') then
                    o_pwr((i2c_modSel-1)*64+63 downto (i2c_modSel-1)*64+56) <= i2c_data_rd;
                end if;
            when 17 =>
                i2c_rw      <= '1';
            when 18 =>
                i2c_rw      <= '0';
                i2c_data_wr <= ADDR_ALARM(0);
                if(i2c_busy = '0') then
                    o_pwr((i2c_modSel-1)*64+55 downto (i2c_modSel-1)*64+48) <= i2c_data_rd;
                end if;
            when 19 =>
                i2c_rw      <= '1';
            when 20 =>
                i2c_rw      <= '0';
                i2c_data_wr <= ADDR_ALARM(1);
                if(i2c_busy = '0') then
                    o_alarm((i2c_modSel-1)*32+7 downto (i2c_modSel-1)*32)  <= i2c_data_rd;
                end if;
            when 21 =>
                i2c_rw      <= '1';
            when 22 =>
                i2c_rw      <= '0';
                i2c_data_wr <= ADDR_ALARM(2);
                if(i2c_busy = '0') then
                    o_alarm((i2c_modSel-1)*32+15 downto (i2c_modSel-1)*32+8)  <= i2c_data_rd;
                end if;
            when 23 =>
                i2c_rw      <= '1';
            when 24 =>
                i2c_rw      <= '0';
                i2c_data_wr <= ADDR_ALARM(3);
                if(i2c_busy = '0') then
                    o_alarm((i2c_modSel-1)*32+23 downto (i2c_modSel-1)*32+16)  <= i2c_data_rd;
                end if;
            when 25 =>
                i2c_rw      <= '1';
            when 26 =>
                i2c_rw      <= '0';
                i2c_data_wr <= ADDR_VCC_1;
                if(i2c_busy = '0') then
                    o_alarm((i2c_modSel-1)*32+31 downto (i2c_modSel-1)*32+24)  <= i2c_data_rd;
                end if;
            when 27 =>
                i2c_rw     <= '1';
            when 28 =>
                i2c_rw     <= '0';
                i2c_data_wr <= ADDR_VCC_2;
                if(i2c_busy = '0') then
                    o_vcc((i2c_modSel-1)*16+15 downto (i2c_modSel-1)*16+8)  <= i2c_data_rd;
                end if;
            when 29 =>
                i2c_rw      <= '1';
            when 30 =>
                i2c_ena     <= '0';
                if(i2c_busy = '0') then
                    o_vcc((i2c_modSel-1)*16+7 downto (i2c_modSel-1)*16)  <= i2c_data_rd;
                    busy_cnt                <= 0;
                    i2c_state               <= idle;
                    i2c_ch                  <= 0;
                end if;
            when others =>
                busy_cnt <= 0;
            end case;

        when others =>
            i2c_state       <= idle;
        end case;
    end if;
    end process;

end architecture;
