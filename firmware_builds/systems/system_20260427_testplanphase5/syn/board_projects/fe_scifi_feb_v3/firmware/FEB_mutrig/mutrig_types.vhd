library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


package mutrig_hit_types is

    -- Hit type (long) before sorter, before TCC division
    constant len_hit_presort : natural := 4 + 5 + 15 + 5 + 15 + 1 + 1;
    type t_hit_presort is record
        asic            : std_logic_vector(3 downto 0);  --ASIC ID
        channel         : std_logic_vector(4 downto 0);  --Channel number
        T_CC            : std_logic_vector(14 downto 0); --T-Trigger coarse time value (1.6ns)
        T_Fine          : std_logic_vector(4 downto 0);  --T-Trigger fine time value
        E_CC            : std_logic_vector(14 downto 0); --Energy coarse time value (in units of 1.6ns)
        E_Flag          : std_logic;                     --E-Flag valid flag
        valid           : std_logic;                     --data word valid flag
    end record;
    type t_v_hit_presort is array (natural range <>) of t_hit_presort;

    constant t_hit_presort_zero : t_hit_presort := (
        asic      => "0000",
        channel   => "00000",
        T_CC      => (others => '0'),
        T_Fine    => "00000",
        E_CC      => "000000000000000",
        E_Flag    => '0',
        valid     => '0'
    );
    function vector_to_pre_sorter(vec : std_logic_vector(len_hit_presort-1 downto 0)) return t_hit_presort;
    function pre_sorter_to_vector(rec : t_hit_presort) return std_logic_vector;


    -- Hit type (long) before sorter, after TCC division
    constant len_hit_presort_div : natural := 4 + 5 + 13 + 3 + 5 + 1 + 15 + 1;
    constant len_hit_presort_div_no_ts : natural :=     2 + 5   + 2   + 3   + 5  + 1;
    --                                               ASIC  CH  T_UP  T_RE  FINE  E-F
    type t_hit_presort_div is record
        asic            : std_logic_vector(3 downto 0);  --ASIC ID
        channel         : std_logic_vector(4 downto 0);  --Channel number
        T_CC_div        : std_logic_vector(12 downto 0); --T-Trigger coarse time value (in units of 8ns)
        T_CC_rem        : std_logic_vector(2 downto 0);  --T-Trigger coarse time value (in units of 1.6ns)
        T_Fine          : std_logic_vector(4 downto 0);  --T-Trigger fine time value
        E_Flag          : std_logic;                     --data word is E-Part
        E_CC            : std_logic_vector(14 downto 0); --Energy coarse time value (in units of 1.6ns)
        valid           : std_logic;                     --data word valid flag
    end record;
    type t_v_hit_presort_div is array (natural range <>) of t_hit_presort_div;

    constant t_hit_presort_div_zero : t_hit_presort_div := (
        asic            => "0000",
        channel         => "00000",
        T_CC_div        => (others => '0'),
        T_CC_rem        => (others => '0'),
        T_Fine          => "00000",
        E_Flag          => '0',
        E_CC            => "000000000000000",
        valid           => '0'
    );

    function conv_hit_pre2prediv(rec_in : t_hit_presort) return t_hit_presort_div;

    function presort_div_to_vector_no_ts(rec : t_hit_presort_div) return std_logic_vector;

    -- Hit type after sorter: shorter TCC divider part, ECC is the same
    constant len_hit_postsort : natural := 4 + 5 + 3 + 3 + 5 + 15 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1;
    type t_hit_postsort is record
        asic            : std_logic_vector(3 downto 0);
        channel         : std_logic_vector(4 downto 0);
        T_CC_div        : std_logic_vector(2 downto 0);     -- T-Trigger coarse time value (in units of 8ns)
        T_CC_rem        : std_logic_vector(2 downto 0);     -- T-Trigger coarse time value (in units of 1.6ns)
        T_Fine          : std_logic_vector(4 downto 0);     -- T-Trigger fine time
        E_CC            : std_logic_vector(14 downto 0);    -- Energy; full dynamic range. Only 12 bits to be kept for serialization
        sop             : std_logic;                        -- start of packet (preamble)
        sbhdr           : std_logic;                        -- SuB HeaDeR
        eop             : std_logic;                        -- end of packet (trailer)
        err             : std_logic;                        -- package has an error
        t0              : std_logic;                        -- time stamp upper bits
        t1              : std_logic;                        -- time stamp lower bits
        d0              : std_logic;                        -- sorter debug word 0
        d1              : std_logic;                        -- sorter debug word 1
        valid           : std_logic;                        -- hit valid flag if zero than we have another type
    end record;
    type t_v_hit_postsort is array (natural range <>) of t_hit_postsort;

    function post_sorter_to_vector(rec : t_hit_postsort) return std_logic_vector;
    function vector_to_post_sorter(vec : std_logic_vector(len_hit_postsort-1 downto 0)) return t_hit_postsort;



    -- Converter / Mapping pre-sort -> post_sort and vice versa (loosing T dynamic range)
    -- this is a bit of a hack to use the same PRBS decoder for the post sorter type
    -- to be used ONLY for this purpose
    function conv_hit_prediv2post(rec_in : t_hit_presort_div) return t_hit_postsort;
    function conv_hit_post2prediv(rec_in : t_hit_postsort) return t_hit_presort_div;


    --sorter replacement conversions (temporary. two words per hit)
    function conv_hit_prediv2post_w1(rec_in : t_hit_presort_div) return t_hit_postsort; --first word
    function conv_hit_prediv2post_w2(rec_in : t_hit_presort_div) return t_hit_postsort; --second word for long event

end;

package body mutrig_hit_types is

---------------------------------------
-- Converters for pre-sorter data types
---------------------------------------

    function vector_to_pre_sorter(vec : std_logic_vector(len_hit_presort-1 downto 0)) return t_hit_presort --{{{
    is
        variable rec : t_hit_presort;
    begin
        rec.asic        := vec(45 downto 42);
        rec.channel     := vec(41 downto 37);
        rec.T_CC        := vec(36 downto 22);
        rec.T_Fine      := vec(21 downto 17);
        rec.E_CC        := vec(16 downto 2);
        rec.E_Flag      := vec(1);
        rec.valid       := vec(0);
        return rec;
    end;

    function pre_sorter_to_vector(rec : t_hit_presort) return std_logic_vector --{{{
    is
        variable vec : std_logic_vector(len_hit_presort-1 downto 0);
    begin
        vec(45 downto 42) := rec.asic;
        vec(41 downto 37) := rec.channel;
        vec(36 downto 22) := rec.T_CC;
        vec(21 downto 17) := rec.T_Fine;
        vec(16 downto 2)  := rec.E_CC;
        vec(1)            := rec.E_Flag;
        vec(0)            := rec.valid;
        return vec;
    end;

    function conv_hit_pre2prediv(rec_in : t_hit_presort) return t_hit_presort_div --{{{
    is
        variable rec_out : t_hit_presort_div;
    begin
        rec_out.asic    := rec_in.asic;
        rec_out.channel := rec_in.channel;
        --rec_out.T_CC_div := rec_in.T_CC(); -- this conversion is supposed to happen in the divider block
        --rec_out.T_CC_rem := rec_in.T_CC();
        rec_out.T_Fine  := rec_in.T_fine;
        rec_out.E_CC    := rec_in.E_CC;
        rec_out.E_Flag  := rec_in.E_Flag;
        rec_out.valid   := rec_in.valid;
        return rec_out;
    end;

    function presort_div_to_vector_no_ts(rec : t_hit_presort_div) return std_logic_vector
    is
        variable vec : std_logic_vector(len_hit_presort_div_no_ts - 1 downto 0);
    begin
        -- NOTE: we remove this for scifi need it for tile
        vec(17 downto 16)  := rec.asic(1 downto 0);
        vec(15 downto 11)  := rec.channel;
        vec(10 downto  9)  := rec.T_CC_div(12 downto 11);
        vec( 8 downto  6)  := rec.T_CC_rem;
        vec( 5 downto  1)  := rec.T_Fine;
        vec(0)             := rec.E_Flag;
        return vec;
    end;

----------------------------------------
-- Converters for post-sorter data types
----------------------------------------

    function vector_to_post_sorter(vec : std_logic_vector(len_hit_postsort-1 downto 0)) return t_hit_postsort --{{{
    is
        variable rec : t_hit_postsort;
    begin
        rec.asic       := vec(31 downto 28);
        rec.channel    := vec(27 downto 23);
        rec.T_CC_div   := vec(22 downto 20);
        rec.T_CC_rem   := vec(19 downto 17);
        rec.T_Fine     := vec(16 downto 12);
        rec.E_CC       := ('-' & '-' & '-' & vec(11 downto 0));
        rec.valid     := '0';
        return rec;
    end;

    function post_sorter_to_vector(rec : t_hit_postsort) return std_logic_vector --{{{
    is
        variable vec : std_logic_vector(len_hit_postsort-1 downto 0);
    begin
        vec(31 downto 28) := rec.asic;
        vec(27 downto 23) := rec.channel;
        vec(22 downto 20) := rec.T_CC_div;
        vec(19 downto 17) := rec.T_CC_rem;
        vec(16 downto 12) := rec.T_Fine;
        vec(11 downto 0)  := rec.E_CC(11 downto 0);
        return vec;
    end;


-----------------------------------------
-- Converter functions pre -> post sorter
-----------------------------------------

    function conv_hit_prediv2post(rec_in : t_hit_presort_div) return t_hit_postsort --{{{
    is
        variable rec_out : t_hit_postsort;
    begin
        rec_out.asic     := rec_in.asic;  
        rec_out.channel  := rec_in.channel;
        rec_out.T_CC_div := rec_in.T_CC_div(2 downto 0);
        rec_out.T_CC_rem := rec_in.T_CC_rem;
        rec_out.T_Fine   := rec_in.T_fine;
        rec_out.E_CC     := rec_in.E_CC;
        rec_out.valid   := rec_in.valid;
        return rec_out;
    end;


    function conv_hit_post2prediv(rec_in : t_hit_postsort) return t_hit_presort_div --{{{
    is
        variable rec_out : t_hit_presort_div;
    begin
        rec_out.asic     := rec_in.asic;  
        rec_out.channel  := rec_in.channel;
        rec_out.T_CC_div := ("----------" & rec_in.T_CC_div);
        rec_out.T_CC_rem := rec_in.T_CC_rem;
        rec_out.T_Fine   := rec_in.T_fine;
        rec_out.E_CC     := rec_in.E_CC;
        rec_out.valid    := rec_in.valid;
        return rec_out;
    end;


-----------------------------------------
-- Sorter replacement conversions
-----------------------------------------

    function conv_hit_prediv2post_w1(rec_in : t_hit_presort_div) return t_hit_postsort --{{{
    is
        variable rec_out : t_hit_postsort := conv_hit_prediv2post(rec_in);
    begin
        rec_out.E_CC      := "00000" & rec_in.T_CC_div(12 downto 3);
        return rec_out;
    end;

    function conv_hit_prediv2post_w2(rec_in : t_hit_presort_div) return t_hit_postsort --{{{
    is
        variable rec_out : t_hit_postsort := conv_hit_prediv2post(rec_in);
    begin
        rec_out.T_Fine    := "000" & rec_in.E_CC(14 downto 13);
        rec_out.E_CC      := rec_in.E_CC;
        return rec_out;
    end;


end package body;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


package mutrig_sc_types is

    -- sc type of mutrig datapath
    constant len_sc_mutrig : natural := 5 + 4 + 8 + 3 + 32 + 1 + 32 + 26 + 1 + 13 + 13 + 2 + 1 + 1 + 15 + 15 + 1 + 13 + 13 + 1 + 1 + 10 + 1 + 1;
    type t_sc_mutrig is record
        ch_select               : std_logic_vector(4 downto 0);     -- select asic for ch rate
        asic_select             : std_logic_vector(3 downto 0);     -- select channel for ch rate
        pll_test_mode           : std_logic_vector(7 downto 0);     -- test mode selection for the pll test
        subdet_reset            : std_logic_vector(2 downto 0);     -- reset different parts of the subdec firmeware
        subdet_resetdly         : std_logic_vector(31 downto 0);    -- reset delay register
        subdet_resetdly_written : std_logic;                        -- reset delay written signal
        debug_path              : std_logic_vector(31 downto 0);    -- control signals for the different debug paths
        rx_state                : std_logic_vector(25 downto 0);    -- state of data decoder of receiver block
        receivers_pll_lock      : std_logic;                        -- pll lock flag
        receivers_dpa_lock      : std_logic_vector(12 downto 0);    -- dpa lock flag per channel
        receivers_ready         : std_logic_vector(12 downto 0);    -- receiver output ready flag
        frame_desync            : std_logic_vector(1 downto 0);     -- desync of the different frames
        reset_counters          : std_logic;                        -- reset counters
        en_lapse_counter        : std_logic;                        -- enable lapse correction
        upper_bnd               : std_logic_vector(14 downto 0);    -- upper bnd of lapse correction
        lower_bnd               : std_logic_vector(14 downto 0);    -- lower bnd of lapse correction
        disable_dec             : std_logic;                        -- disable PRBS decoding
        mask                    : std_logic_vector(12 downto 0);    -- mask tile asics
        mask_rx                 : std_logic_vector(12 downto 0);    -- mask rx tile asics
        datagen_enable          : std_logic;                        -- enable data generator
        datagen_shortmode       : std_logic;                        -- enable short mode of data generator
        datagen_count           : std_logic_vector(9 downto 0);     -- number of hits per frame in data generator
        rx_wait_for_all         : std_logic;                        -- wait for all RX ready
        rx_wait_for_all_sticky  : std_logic;                        -- wait for all RX ready sticky
    end record;
    type t_v_sc_mutrig is array (natural range <>) of t_sc_mutrig;

    constant t_sc_mutrig_zero : t_sc_mutrig := (
        ch_select => "00000",
        asic_select => "0000",
        pll_test_mode => "00000000",
        subdet_reset => "000",
        subdet_resetdly => "00000000000000000000000000000000",
        subdet_resetdly_written => '0',
        debug_path => "00000000000000000000000000000000",
        rx_state => "00000000000000000000000000",
        receivers_pll_lock => '0',
        receivers_dpa_lock => "0000000000000",
        receivers_ready => "0000000000000",
        frame_desync => "00",
        reset_counters => '0',
        en_lapse_counter => '0',
        upper_bnd => "000000000000000",
        lower_bnd => "000000000000000",
        disable_dec => '0',
        mask => "0000000000000",
        mask_rx => "0000000000000",
        datagen_enable => '0',
        datagen_shortmode => '0',
        datagen_count => "0000000000",
        rx_wait_for_all => '0',
        rx_wait_for_all_sticky => '0'
    );

    function sc_mutrig_to_vector(rec : t_sc_mutrig) return std_logic_vector;
    function vector_to_sc_mutrig(vec : std_logic_vector(len_sc_mutrig-1 downto 0)) return t_sc_mutrig;

end;

package body mutrig_sc_types is

    -- converters vector to sc type
    function vector_to_sc_mutrig(vec : std_logic_vector(len_sc_mutrig-1 downto 0)) return t_sc_mutrig
    is
        variable rec : t_sc_mutrig;
    begin
        rec.ch_select               := vec(212 downto 208);
        rec.asic_select             := vec(207 downto 204);
        rec.pll_test_mode           := vec(203 downto 196);
        rec.subdet_reset            := vec(195 downto 193);
        rec.subdet_resetdly         := vec(192 downto 161);
        rec.subdet_resetdly_written := vec(160);
        rec.debug_path              := vec(159 downto 128);
        rec.rx_state                := vec(127 downto 102);
        rec.receivers_pll_lock      := vec(101);
        rec.receivers_dpa_lock      := vec(100 downto 88);
        rec.receivers_ready         := vec(87 downto 75);
        rec.frame_desync            := vec(74 downto 73);
        rec.reset_counters          := vec(72);
        rec.en_lapse_counter        := vec(71);
        rec.upper_bnd               := vec(70 downto 56);
        rec.lower_bnd               := vec(55 downto 41);
        rec.disable_dec             := vec(40);
        rec.mask                    := vec(39 downto 27);
        rec.mask_rx                 := vec(26 downto 14);
        rec.datagen_enable          := vec(13);
        rec.datagen_shortmode       := vec(12);
        rec.datagen_count           := vec(11 downto 2);
        rec.rx_wait_for_all         := vec(1);
        rec.rx_wait_for_all_sticky  := vec(0);
        return rec;
    end;

    function sc_mutrig_to_vector(rec : t_sc_mutrig) return std_logic_vector
    is
        variable vec : std_logic_vector(len_sc_mutrig-1 downto 0);
    begin
        vec(212 downto 208) := rec.ch_select;
        vec(207 downto 204) := rec.asic_select;
        vec(203 downto 196) := rec.pll_test_mode;
        vec(195 downto 193) := rec.subdet_reset;
        vec(192 downto 161) := rec.subdet_resetdly;
        vec(160)            := rec.subdet_resetdly_written; 
        vec(159 downto 128) := rec.debug_path;
        vec(128 downto 103) := rec.rx_state;
        vec(101)            := rec.receivers_pll_lock;
        vec(100 downto 88)  := rec.receivers_dpa_lock;
        vec(87 downto 75)   := rec.receivers_ready;
        vec(74 downto 73)   := rec.frame_desync;
        vec(72)             := rec.reset_counters;
        vec(71)             := rec.en_lapse_counter;
        vec(70 downto 56)   := rec.upper_bnd;
        vec(55 downto 41)   := rec.lower_bnd;
        vec(40)             := rec.disable_dec;
        vec(39 downto 27)   := rec.mask;
        vec(26 downto 14)   := rec.mask_rx;
        vec(13)             := rec.datagen_enable;
        vec(12)             := rec.datagen_shortmode;
        vec(11 downto 2)    := rec.datagen_count;
        vec(1)              := rec.rx_wait_for_all;
        vec(0)              := rec.rx_wait_for_all_sticky;
        return vec;
    end;

end package body;




