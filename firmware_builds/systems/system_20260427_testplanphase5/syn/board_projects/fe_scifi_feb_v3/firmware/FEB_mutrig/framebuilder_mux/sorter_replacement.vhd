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
use work.mutrig.all;


entity sorter_replacement is
generic (
    IS_SHORT : boolean := false;
    N        : positive--;
);
port (
    -- event data input
    i_data       : in  work.mutrig_hit_types.t_v_hit_presort(N-1 downto 0);
    i_mask       : in  std_logic_vector(N-1 downto 0);
    i_short      : in  std_logic;
    i_rempty     : in  std_logic_vector(N-1 downto 0);
    o_ren        : out std_logic_vector(N-1 downto 0);

    -- event data output, asic number appended
    o_data       : out std_logic_vector(35 downto 0);
    i_wfull      : in  std_logic;
    o_wen        : out std_logic;

    i_clk        : in  std_logic;
    i_ts_reset_n : in  std_logic;
    i_reset_n    : in  std_logic--;
);
end entity;

architecture rtl of sorter_replacement is

    -- global timestamp
    signal global_timestamp : std_logic_vector(47 downto 0);
    signal package_counter : std_logic_vector(31 downto 0);
    signal eop : std_logic;

    -- round robin
    signal ro_data, ro_q : work.mutrig_hit_types.t_hit_presort;
    signal rempty_mask : std_logic_vector(N-1 downto 0);
    signal wfull, we, rempty, ren : std_logic;

    -- readout logic
    constant IDLE   : std_logic_vector(3 downto 0) := x"1";
    constant T0     : std_logic_vector(3 downto 0) := x"2";
    constant T1     : std_logic_vector(3 downto 0) := x"3";
    constant D0     : std_logic_vector(3 downto 0) := x"4";
    constant D1     : std_logic_vector(3 downto 0) := x"5";
    constant HIT    : std_logic_vector(3 downto 0) := x"6";
    constant WAITING: std_logic_vector(3 downto 0) := x"7";
    constant TRAILER: std_logic_vector(3 downto 0) := x"8";
    signal rd_state, rd_state_last : std_logic_vector(3 downto 0) := IDLE;

    -- hit logic
    signal Epart : std_logic;
    signal h_t0, h_t1, h_d0, h_d1, h_trailer, h_hit : std_logic_vector(35 downto 0);

    signal h_hit_help : std_logic_vector(20 downto 0);
    signal h_d0_data, header_counter, debug_subheadercounter : std_logic_vector(31 downto 0);

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

    --! round robin of hit stream
    rempty_mask <= i_rempty or i_mask;
    u_stream_merger_mutrig : entity work.stream_merger_mutrig
    generic map (
        N => N--;
    )
    port map (
        -- input streams
        i_rdata     => i_data,
        i_rempty    => rempty_mask,
        o_rack      => o_ren,
    
        -- output stream
        o_wdata     => ro_data,
        i_wfull     => wfull,
        o_we        => we,
    
        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    e_stream_merger_fifo : entity work.mutrig_rec1_scfifo
    generic map (
        g_ADDR_WIDTH => 8,
        g_WREG_N => 2,
        g_RREG_N => 2--,
    )
    port map (
        i_wdata         => ro_data,
        i_we            => we,
        o_wfull         => wfull,

        o_rdata         => ro_q,
        o_rempty        => rempty,
        i_rack          => ren,

        i_clk           => i_clk,
        i_reset_n       => i_reset_n--,
    );

    --! readout state
    rd_state <= WAITING when i_wfull = '1' or i_reset_n /= '1' or rempty = '1' else
                T0  when ro_q.valid = '1' and (rd_state_last = IDLE or rd_state_last = TRAILER) else
                T1      when rd_state_last = T0 else
                D0      when rd_state_last = T1 else
                D1      when rd_state_last = D0 else
                TRAILER when eop = '1' and (rd_state_last = D1 or rd_state_last = HIT) else
                HIT     when ro_q.valid = '1' and (rd_state_last = D1 or rd_state_last = HIT) else
                IDLE    when ro_q.valid = '0' else
                WAITING;

    --! generate write signal
    o_wen <=    '1'  when rd_state = T0 or rd_state = T1 or rd_state = D0 or rd_state = D1 or rd_state = HIT or rd_state = TRAILER else
                '0';

    ren   <=    -- read from inputs until we have a valid hit
                '1' when rd_state = IDLE else
                -- read when we have a hit and we are in short mode
                '1' when rd_state = HIT and i_short = '1' else
                -- read when we have the E hit send and we are in long mode
                '1' when rd_state = HIT and i_short = '0' and Epart = '1' else
                '0';

    --! generate output data
    h_t0     <= "0010" & global_timestamp(47 downto 16);
    h_t1     <= "0000" & global_timestamp(15 downto 0) & header_counter;
    h_d0     <= "0000" & x"00000000";
    h_d1     <= "0000" & x"00000000";
    h_hit    <= "0000" & ro_q.asic & Epart & ro_q.channel & '0' & h_hit_help;
    h_hit_help <=    ro_q.T_CC & ro_q.T_Fine & '0' when i_short = '1' else   -- T event data: ttime, eflag        - short event
                     ro_q.T_CC & ro_q.T_Fine & '0' when Epart = '0'   else   -- T event data: etime, eflag(redun) - long event
                     ro_q.E_CC & ro_q.T_Fine & '1' when Epart = '1'   else   -- E event data: etime, eflag(redun) - long event
                     (others => '0');
    h_trailer<= "0011" & x"00000000";


    --! output data word
    o_data <=   h_t0        when rd_state = T0       else
                h_t1        when rd_state = T1       else
                h_d0        when rd_state = D0       else
                h_d1        when rd_state = D1       else
                h_hit       when rd_state = HIT      else
                h_trailer   when rd_state = TRAILER  else
                (others => '0');

    --! memory of readout state
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        rd_state_last   <= IDLE;
        Epart           <= '0';
        package_counter <= (others => '0');
        eop             <= '0';
        --
    elsif rising_edge(i_clk) then

        -- remember last state
        if ( rd_state /= WAITING ) then
            rd_state_last <= rd_state;
        end if;

        if ( rd_state = T1 ) then
            header_counter <= header_counter + '1';
        end if;

        if ( rd_state = T0 ) then
            package_counter <= (others => '0');
            eop             <= '0';
        else
            package_counter <= package_counter + '1';
            -- we count 1500 x 8ns = 12us to force to end the package
            if ( package_counter = x"5DC" ) then
                eop <= '1';
            end if;
        end if;

        -- Epart / Tpart logic
        Epart <= '0';
        if ( rd_state = HIT and i_short = '0' and Epart = '0' ) then
            Epart <= '1';
        end if;
        --
    end if;
    end process;

end architecture;
