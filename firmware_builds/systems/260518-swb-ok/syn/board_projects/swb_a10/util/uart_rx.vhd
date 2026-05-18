--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

-- uart receiver
--
-- - start bit is logic low
-- - stop bits are logic high
-- - LSB first
entity uart_rx is
generic (
    -- PARITY = 0 - none
    -- PARITY = 1 - odd
    -- PARITY = 2 - even
    g_PARITY : integer := 0;
    g_DATA_BITS : positive := 8;
    g_STOP_BITS : positive := 1;
    g_BAUD_RATE : positive := 115200; -- bps
    g_FIFO_ADDR_WIDTH : positive := 2;
    g_CLK_MHZ : real--;
);
port (
    -- serial data
    i_data      : in    std_logic;

    o_rdata     : out   std_logic_vector(g_DATA_BITS-1 downto 0);
    i_rack      : in    std_logic;
    o_rempty    : out   std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of uart_rx is

    signal d : std_logic_vector(1 downto 0);

    signal wdata : std_logic_vector(g_DATA_BITS-1 downto 0);
    signal we, wfull : std_logic;

    constant CNT_MAX : positive := positive(1000000.0 * g_CLK_MHZ / real(g_BAUD_RATE)) - 1;
    signal cnt : integer range 0 to CNT_MAX;

    type state_t is (
        STATE_START,
        STATE_DATA,
        STATE_PARITY,
        STATE_STOP,
        STATE_IDLE--,
    );
    signal state : state_t;

    signal data_bit : integer range 0 to g_DATA_BITS-1;
    signal parity : std_logic;
    signal stop_bit : integer range 0 to g_STOP_BITS-1;

begin

    -- psl default clock is rising_edge(i_clk);
    -- psl assert always ( o_rempty = '0' or i_rack = '0' );

    d(0) <= i_data;
    process(i_clk, i_reset_n)
    begin
    if rising_edge(i_clk) then
        d(1) <= d(0);
    end if;
    end process;

    -- use fifo to buffer output data
    e_fifo : entity work.fifo_sc
    generic map (
        g_DATA_WIDTH => g_DATA_BITS,
        g_ADDR_WIDTH => g_FIFO_ADDR_WIDTH--,
    )
    port map (
        o_rdata         => o_rdata,
        i_rack          => i_rack,
        o_rempty        => o_rempty,

        i_wdata         => wdata,
        i_we            => we,
        o_wfull         => wfull,

        i_reset_n       => i_reset_n,
        i_clk           => i_clk--,
    );

    parity <=
        -- total parity odd
        '1' xor xor_reduce(wdata) when ( g_PARITY = 1 ) else
        -- total parity even
        '0' xor xor_reduce(wdata) when ( g_PARITY = 2 ) else
        '-';

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        we <= '0';
        cnt <= 0;
        state <= STATE_IDLE;
        --
    elsif rising_edge(i_clk) then
        we <= '0';

        -- baud rate counter
        if ( cnt = CNT_MAX ) then
            cnt <= 0;
        else
            cnt <= cnt + 1;
        end if;

        if ( d(0) /= d(1) and d(1) = '1' and state = STATE_IDLE ) then
            cnt <= 0;
            state <= STATE_START;
        end if;

        -- change state and sample data at baud half-phase
        if ( cnt = CNT_MAX / 2 ) then
            case state is
            when STATE_START =>
                if ( wfull = '1' ) then
                    -- TODO : overrun error
                end if;

                data_bit <= 0;
                stop_bit <= 0;
                state <= STATE_DATA;
                --
            when STATE_DATA =>
                wdata(data_bit) <= i_data;

                if ( data_bit /= g_DATA_BITS-1) then
                    data_bit <= data_bit + 1;
                elsif ( g_PARITY /= 0 ) then
                    state <= STATE_PARITY;
                else
                    we <= '1';
                    state <= STATE_STOP;
                end if;
                --
            when STATE_PARITY =>
                if ( i_data /= parity ) then
                    -- TODO : parity error
                end if;

                we <= '1';
                state <= STATE_STOP;
                --
            when STATE_STOP =>
                if ( i_data /= '1' ) then
                    -- TODO : framing error
                    if ( wdata = 0 ) then
                        -- TODO : break condition
                    end if;
                end if;

                if ( stop_bit /= g_STOP_BITS-1) then
                    stop_bit <= stop_bit + 1;
                else
                    state <= STATE_IDLE;
                end if;
                --
            when others =>
                null;
            end case;
        end if;
        --
    end if;
    end process;

end architecture;
