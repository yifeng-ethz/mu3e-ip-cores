---------------------------------------
--
-- Data unpacker to convert the the mutrig
-- data into 32bit data words
--
-- mkoeppel@uni-mainz.de
--
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.mudaq.all;


entity data_unpacker is
generic (
    asicnum  : std_logic_vector(3 downto 0)--;
);
port (
    -- event data input
    i_data       : in  std_logic_vector(55 downto 0);
    i_mask       : in  std_logic;
    i_rempty     : in  std_logic;
    o_ren        : out std_logic;

    -- event data output, asic number appended
    o_data       : out std_logic_vector(33 downto 0);
    i_wfull      : in  std_logic;
    o_wen        : out std_logic;

    i_clk        : in  std_logic;
    i_ts_reset_n : in  std_logic;
    i_reset_n    : in  std_logic--;
);
end entity;

architecture rtl of data_unpacker is

    -- global timestamp
    signal global_timestamp : std_logic_vector(47 downto 0);

    -- readout logic
    constant IDLE   : std_logic_vector(3 downto 0) := x"1";
    constant HEADER : std_logic_vector(3 downto 0) := x"2";
    constant T1     : std_logic_vector(3 downto 0) := x"3";
    constant HIT    : std_logic_vector(3 downto 0) := x"4";
    constant WAITING: std_logic_vector(3 downto 0) := x"5";
    constant TRAILER: std_logic_vector(3 downto 0) := x"6";
    signal rd_state, rd_state_last : std_logic_vector(3 downto 0) := IDLE;

    -- hit logic
    signal Epart : std_logic;
    signal h_t0, h_t1, h_trailer, h_hit : std_logic_vector(33 downto 0);

begin

    --! global timestamp generation
    process(i_clk, i_ts_reset_n)
    begin
    if ( i_ts_reset_n /= '1' ) then
        global_timestamp <= (others => '0');
    elsif rising_edge(i_clk) then
        global_timestamp <= global_timestamp + '1';
    end if;
    end process;

    --! readout state
    rd_state <= WAITING when i_wfull = '1' or i_reset_n /= '1' or i_mask = '1' or i_rempty = '1' else
                HEADER  when i_data(51 downto 50) = MERGER_FIFO_PAKET_START_MARKER(1 downto 0) and (rd_state_last = IDLE or rd_state_last = TRAILER) else
                T1      when rd_state_last = HEADER else
                TRAILER when i_data(51 downto 50) = MERGER_FIFO_PAKET_END_MARKER(1 downto 0) and (rd_state_last = T1 or rd_state_last = HIT) else
                HIT     when rd_state_last = T1 or rd_state_last = HIT else
                IDLE    when i_data(51 downto 50) /= MERGER_FIFO_PAKET_START_MARKER(1 downto 0) else
                WAITING;

    --! generate write signal
    o_wen <=    '1'  when rd_state = HEADER or rd_state = T1 or rd_state = TRAILER or rd_state = HIT else
                '0';

    o_ren <=    -- read when when we are in state T1 or TRAILER
                '1' when rd_state = T1 or rd_state = TRAILER else
                -- read from inputs until we have a header
                '1' when rd_state = IDLE else
                -- read when we have a hit and we are in short mode
                '1' when rd_state = HIT and i_data(48) = '1' else
                -- read when we have the E hit send and we are in long mode
                '1' when rd_state = HIT and i_data(48) = '0' and Epart = '1' else
                '0';

    --! generate output data
    -- header word
    h_t0(33 downto 32)      <= MERGER_FIFO_PAKET_START_MARKER(1 downto 0);    --identifier (type header)
    h_t0(31 downto 0)       <= global_timestamp(47 downto 16);                --global timestamp
    -- t1 word
    h_t1(33 downto 32)      <= MERGER_FIFO_PAKET_T1_MARKER(1 downto 0);       --identifier for t1
    h_t1(31 downto 16)      <= global_timestamp(15 downto 0);                 --global timestamp
    h_t1(15)                <= '0';                                           --frameID nonsync
    h_t1(14 downto 0)       <= i_data(14 downto 0);                           --frameID
    -- trailer word
    h_trailer(33 downto 32)  <= MERGER_FIFO_PAKET_END_MARKER(1 downto 0);   --identifier for trailer
    h_trailer(31 downto 19)  <= (others => '0');                            --filler
    h_trailer(18 downto 4)   <= i_data(14 downto 0);                        --frameID
    h_trailer(3)             <= i_data(19);                                 --asic package had a bad trailer
    h_trailer(2)             <= i_data(18);                                 --fpga fifo overflow flag
    h_trailer(1)             <= i_data(17);                                 --asic fifo overflow flag
    h_trailer(0)             <= i_data(16);                                 --crc error flag
    -- hit word
    h_hit(33 downto 32) <= "00";                                            --identifier for data
    h_hit(31 downto 28) <= asicnum;                                         --asic number
    h_hit(27)           <= Epart;                                           -- type (0=TPART, 1=EPART)
    h_hit(26 downto 22) <= i_data(47 downto 43);                            -- event data: chnum
    h_hit(21 downto 0)  <= i_data(42 downto 21)                 when i_data(48) = '1' else  --T event data: ttime, eflag        - short event
                           i_data(42 downto 21)                 when Epart = '0' else       --T event data: etime, eflag(redun) - long event
                           i_data(20 downto 0) & i_data(21)     when Epart = '1' else       --E event data: etime, eflag(redun) - long event
                           (others => '0');

     --! output data word
    o_data <=   h_t0        when rd_state = HEADER else
                h_t1        when rd_state = T1 else
                h_trailer   when rd_state = TRAILER else
                h_hit;

    --! memory of readout state
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        rd_state_last   <= IDLE;
        Epart           <= '0';
        --
    elsif rising_edge(i_clk) then

        -- remember last state
        if ( rd_state /= WAITING ) then
            rd_state_last <= rd_state;
        end if;

        -- Epart / Tpart logic
        Epart <= '0';
        if ( rd_state = HIT and i_data(48) = '0' and Epart = '0' ) then
            Epart <= '1';
        end if;
        --
    end if;
    end process;

end architecture;
