---------------------------------------
--
-- On the fly PRBS decoder for mutrig/stic event data
-- Variant for post-sorter E-decoding: first port is used in presort, second in post sort.
-- Makes use of converter functions postsort -> presort type -> [decoder] -> postsort , this makes only sense for E-decoding
-- [KB,9/2022] Implemented block
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

use work.mutrig_hit_types.all;


entity prbs_decoder_mixedtypes is
generic (
    DECODE_E_A : boolean := false;
    DECODE_E_B : boolean := true
);
port (
    --system
    i_coreclk       : in  std_logic;
    i_rst           : in  std_logic;
    o_initializing  : out std_logic;

    --data stream input
    i_A_data        : in  t_hit_presort;
    i_B_data        : in  t_hit_postsort;

    --data stream output
    o_A_data        : out t_hit_presort;
    o_B_data        : out t_hit_postsort;

    --disable block (make transparent)
    i_SC_disable_dec : in std_logic--;

);
end prbs_decoder_mixedtypes;



architecture impl of prbs_decoder_mixedtypes is
    signal s_decoded : t_hit_presort;

    function conv_hit_pre2post(rec_in : t_hit_presort) return t_hit_postsort --{{{
    is
        variable rec_out : t_hit_postsort;
    begin
        rec_out.asic     := rec_in.asic;  
        rec_out.channel  := rec_in.channel;
        rec_out.T_CC_div := rec_in.T_CC(5 downto 3);
        rec_out.T_CC_rem := rec_in.T_CC(2 downto 0);
        rec_out.T_Fine   := rec_in.T_fine;
        rec_out.E_CC     := rec_in.E_CC;
        rec_out.valid   := rec_in.valid;
        return rec_out;
    end;    --}}}


    function conv_hit_post2pre(rec_in : t_hit_postsort) return t_hit_presort --{{{
    is
        variable rec_out : t_hit_presort;
    begin
        rec_out.asic     := rec_in.asic;  
        rec_out.channel  := rec_in.channel;
        rec_out.T_CC     := "---------" & rec_in.T_CC_div & rec_in.T_CC_rem;
        rec_out.T_Fine   := rec_in.T_fine;
        rec_out.E_CC     := rec_in.E_CC;
        rec_out.valid    := rec_in.valid;
        return rec_out;
    end;    --}}}


begin

    u_decoder: entity work.prbs_decoder
    generic map (
        DECODE_E_A => DECODE_E_A,
        DECODE_E_B => DECODE_E_B--,
    )
    port map (
        i_coreclk      => i_coreclk,
        i_rst          => i_rst,
        o_initializing => o_initializing,
        i_A_data       => i_A_data,
        i_B_data       => conv_hit_post2pre(i_B_data),
        o_A_data       => o_A_data,
        o_B_data       => s_decoded,
        i_SC_disable_dec => i_SC_disable_dec--,
    );
    o_B_data <= conv_hit_pre2post(s_decoded);
    
end architecture;

