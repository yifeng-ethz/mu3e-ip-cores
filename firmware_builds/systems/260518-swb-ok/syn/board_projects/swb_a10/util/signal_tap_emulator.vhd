-- entity to emulate signal-tap like behavior
-- M. Mueller, June 2022

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity signal_tap_emulator is
GENERIC (
    g_SAMPLE_WIDTH             : positive := 10;
    g_DATA_WIDTH               : positive := 1
);
port (
    i_data                  : in    std_logic_vector(g_DATA_WIDTH-1 downto 0);
    i_data_ena              : in    std_logic := '1';
    i_reset_trigger         : in    std_logic;

    o_trigger_cnt           : out   std_logic_vector(31 downto 0);
    o_trigger_data          : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);
    i_trigger_re            : in    std_logic := '0'; -- only read here if trigger_cnt is not 0. in this case you will read data before and after the first of those triggers

    i_reset_n               : in    std_logic;
    i_clk                   : in    std_logic--;
);
end entity;

architecture arch of signal_tap_emulator is

    signal trigger      : boolean := false;
    signal triggered    : boolean := false;
    signal trigger_cnt  : unsigned(31 downto 0) := (others => '0');

    signal fifo_read    : std_logic;
    signal fifo_write   : std_logic;
    signal fifo_usedw   : std_logic_vector(g_SAMPLE_WIDTH-1 downto 0);
    signal fifo_empty   : std_logic;
    signal fifo_full    : std_logic;
    signal fifo_halffull: std_logic;
    signal data_reg     : std_logic_vector(g_DATA_WIDTH-1 downto 0);
    signal fifo_dataout : std_logic_vector(g_DATA_WIDTH-1 downto 0);

    type trigger_state_t  is (idle, recording_2nd_half_of_triggerdata, wait_for_readout_and_reset);
    signal trigger_state: trigger_state_t;

begin

    o_trigger_cnt <= std_logic_vector(trigger_cnt);
    fifo_halffull <= fifo_usedw(g_SAMPLE_WIDTH-1);
    o_trigger_data <= fifo_dataout when fifo_empty = '0' else (others => '1');

    -- copy the file and insert your trigger condition (or condition entity) here
    -- trigger <= true when ..... else false;


    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        trigger_cnt <= (others => '0');
        fifo_read   <= '0';
        fifo_write  <= '0';
        trigger_state <= idle;

    elsif rising_edge(i_clk) then
        -- defaults
        fifo_write  <= '0';
        fifo_read   <= '0';
        data_reg    <= i_data;

        if(i_reset_trigger = '1') then
            trigger_cnt <= (others => '0');
            trigger_state <= idle;
        elsif(trigger = true) then
            trigger_cnt <= trigger_cnt + 1;
        end if;

        case trigger_state is
        when idle =>
            -- make sure fifo is always halffull
            if(fifo_halffull = '0') then
                fifo_write <= i_data_ena;
            else
                fifo_write <= i_data_ena;
                fifo_read  <= '1';
            end if;

            if(trigger = true) then
                trigger_state <= recording_2nd_half_of_triggerdata;
            end if;

        when recording_2nd_half_of_triggerdata =>
            if(fifo_full = '0') then
                fifo_write <= i_data_ena;
            else
                trigger_state <= wait_for_readout_and_reset;
            end if;

        when wait_for_readout_and_reset =>
            fifo_read <= i_trigger_re;
        when others =>
            trigger_state <= idle;
        end case;

    end if;
    end process;

    e_fifo : entity work.ip_scfifo_v2
    generic map (
        g_ADDR_WIDTH => g_SAMPLE_WIDTH,
        g_DATA_WIDTH => g_DATA_WIDTH--,
    )
    port map (
        i_we        => fifo_write,
        i_wdata     => data_reg,
        o_wfull     => fifo_full,

        i_rack      => fifo_read,
        o_rdata     => fifo_dataout,
        o_rempty    => fifo_empty,

        o_usedw     => fifo_usedw,

        i_reset_n   => not i_reset_trigger,
        i_clk       => i_clk--,
    );

end architecture;
