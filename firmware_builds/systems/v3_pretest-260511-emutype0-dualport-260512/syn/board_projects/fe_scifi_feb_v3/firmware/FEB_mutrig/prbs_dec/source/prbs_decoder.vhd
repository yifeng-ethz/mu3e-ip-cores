---------------------------------------
--
-- On the fly PRBS decoder for mutrig/stic event data
-- Latency two CC.
-- data (or more precisely data_valid flag) is only passed after decoder memory has been initialized,
-- Initialization takes ~32k CC.
-- Frame header and trailer tags are passed as is, word after header (supposed to be second part of header payload) is passed as is
-- Konrad Briggl May 2019
--
-- konrad.briggl@unige.ch
--

-- [KB,6/2022] Changed block to use record types in datapath_v2.
--             Headers / Trailers are not present and dynamic bypassing is removed
--             Add generic parameter DECODE_E
-- [KB,9/2022] Deal with split div+rem coarse counter. The lower 15 bits (CC_div+CC_rem: 16 bits) are used.
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
library altera_mf;
use altera_mf.altera_mf_components.all;

use work.mutrig_hit_types.all;


entity prbs_decoder is
generic (
    DECODE_E_A : boolean := false;
    DECODE_E_B : boolean := false
);
port (
    --system
    i_coreclk       : in  std_logic;
    i_rst           : in  std_logic;
    o_initializing  : out std_logic;

    --data stream input
    i_A_data        : in t_hit_presort;
    i_B_data        : in t_hit_presort;

    --data stream output
    o_A_data        : out t_hit_presort;
    o_B_data        : out t_hit_presort;

    --disable block (make transparent)
    i_SC_disable_dec : in std_logic--;

);
end entity;

architecture impl of prbs_decoder is

    component decoder_mem
    PORT
    (
        address : IN STD_LOGIC_VECTOR (14 DOWNTO 0);
        clock   : IN STD_LOGIC  := '1';
        data    : IN STD_LOGIC_VECTOR (14 DOWNTO 0);
        wren    : IN STD_LOGIC  := '0';
        q       : OUT STD_LOGIC_VECTOR (14 DOWNTO 0)
    );
    end component;

    signal s_init : std_logic; --state vector, '1': Block is initializing
    signal s_init_prbs : std_logic_vector(14 downto 0); --initialization vector(original data)
    signal s_init_dec,s_init_dec_d : std_logic_vector(14 downto 0); --initialization vector(decoded data)

    signal s_A_addr : std_logic_vector(14 downto 0);    --r/w address on port a (init and T decoding)

    signal s_A_data_bypass  : t_v_hit_presort(2 downto 0);
    signal s_B_data_bypass  : t_v_hit_presort(2 downto 0);

    signal s_A_data_dec : std_logic_vector(14 downto 0); -- decoded data E timestamp
    signal s_B_data_dec : std_logic_vector(14 downto 0); -- decoded data E timestamp

    signal s_B_addr : std_logic_vector(14 downto 0);    --r/w address on port a (init and T decoding)

begin

    --decoder memory
    --u_mem: decoder_mem -- replaced by direct implementation
    u_mem : altsyncram
    GENERIC MAP (
        address_reg_b => "CLOCK0",
        clock_enable_input_a => "BYPASS",
        clock_enable_input_b => "BYPASS",
        clock_enable_output_a => "BYPASS",
        clock_enable_output_b => "BYPASS",
        indata_reg_b => "CLOCK0",
        intended_device_family => "Stratix IV",
        lpm_type => "altsyncram",
        numwords_a => 32768,
        numwords_b => 32768,
        operation_mode => "BIDIR_DUAL_PORT",
        outdata_aclr_a => "NONE",
        outdata_aclr_b => "NONE",
        outdata_reg_a => "CLOCK0",
        outdata_reg_b => "CLOCK0",
        power_up_uninitialized => "FALSE",
        read_during_write_mode_mixed_ports => "DONT_CARE",
        read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
        read_during_write_mode_port_b => "NEW_DATA_NO_NBE_READ",
        widthad_a => 15,
        widthad_b => 15,
        width_a => 15,
        width_b => 15,
        width_byteena_a => 1,
        width_byteena_b => 1,
        wrcontrol_wraddress_reg_b => "CLOCK0"
    )
    PORT MAP (
        address_a => s_A_addr,
        address_b => s_B_addr,
        clock0 => i_coreclk,
        data_a => s_init_dec_d,
        wren_a => s_init,
        q_a => s_A_data_dec,
        q_b => s_B_data_dec,
        data_b => (others => '-'),
        wren_b => '-'
    );

    -- decoder init and bypass registers
    p_sync : process(i_coreclk)
    begin
    if rising_edge(i_coreclk) then
        -- ram address and data input, data delay is only to compensate address pipelining.
        -- Address is PRBS data for TCC and ECC or initialization vector
        if (s_init ='1') then
            s_A_addr <= s_init_prbs;
            s_B_addr <= (others => '0');
        else
            if DECODE_E_A then
                s_A_addr <= i_A_data.E_CC;
            else
                s_A_addr <= i_A_data.T_CC;
            end if;
            if DECODE_E_B then
                s_B_addr <= i_B_data.E_CC;
            else
                s_B_addr <= i_B_data.T_CC;
            end if;
        end if;
        s_init_dec_d <= s_init_dec;

        --pipeline registers
        s_A_data_bypass(2)<=i_A_data;
        s_B_data_bypass(2)<=i_B_data;

        for i in s_A_data_bypass'high-1 downto 0 loop
            s_A_data_bypass(i) <= s_A_data_bypass(i+1);
            s_B_data_bypass(i) <= s_B_data_bypass(i+1);
        end loop;

        --initialization part
        if(i_rst='1') then
            -- init part
            s_init_prbs <= (0=>'1', others=>'0');
            s_init_dec  <= (0=>'1', others=>'0');
            s_init <='1';

            -- A_part
            for i in s_A_data_bypass'range loop
                s_A_data_bypass(i).valid <= '0';
                s_B_data_bypass(i).valid <= '0';
            end loop;
        else
            -- init part
            s_init_prbs<=s_init_prbs(13 downto 0) & not (s_init_prbs(14) xor s_init_prbs(13));
            --s_init_prbs<=std_logic_vector(unsigned(s_init_prbs)+1);  --simulation
            s_init_dec<=std_logic_vector(unsigned(s_init_dec)+1);
            if(s_init_dec=(0 to s_init_dec'length-1 =>'0')) then
                s_init<='0';
            end if;
        end if;
    end if;
    end process;


    p_outputs : process(s_A_data_bypass(0),s_B_data_bypass(0),s_A_data_dec,s_B_data_dec)
    begin
        o_A_data <= s_A_data_bypass(0);
        o_B_data <= s_B_data_bypass(0);
        if (i_SC_disable_dec = '0') then
            if ( s_A_data_bypass(0).valid = '1' ) then
                if DECODE_E_A then
                    o_A_data.E_CC <= s_A_data_dec;
                else
                    o_A_data.T_CC <= s_A_data_dec;
                end if;
            end if;
            if ( s_B_data_bypass(0).valid = '1' ) then
                if DECODE_E_B then
                    o_B_data.E_CC <= s_B_data_dec;
                else
                    o_B_data.T_CC <= s_B_data_dec;
                end if;
            end if;
        end if;
    end process;

    o_initializing <= s_init;

end architecture;

