---------------------------------------
--
-- Adapt coarse counter binning to 8ns, keeping a 3 bit remainder for the 1.6ns coarse counter LSBs.
-- Latency one clock cycle.
-- Konrad Briggl 6/22
----------------------------------
-- data flow (° denotes explicit flip flop):
--        0           1                    2                             3                4               5
--
-- E_CC ----> [DIV5] --{E_WC,E_REM}->[-]--°---{D_WC,D_REM}--[D_REM<0?]--°--[D_WC < 0 ?]--°--[Overflow?]--°--[Cut MSB]
-- T_CC -----[+]-°--------------------^                     [ D_WC-1 ]     [Add 2^15-1]     [ Set max ]
-- T_NLps ----^
-- Other ---> °N -------------------------°-----------------------------°----------------°---------------°------> 




library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;
LIBRARY lpm;
USE lpm.all;
USE lpm.lpm_components.all;

use work.mutrig_hit_types.all;


entity E_CC_adapt is
port (
    --system
    i_clk       : in  std_logic;
    i_rst           : in  std_logic;

    --data stream
    i_data        : in std_logic_vector(35 downto 0);
    i_N_lapse     : in std_logic_vector(14 downto 0);

    o_data        : out std_logic_vector(35 downto 0)--;
);
end E_CC_adapt;




architecture impl of E_CC_adapt is

type t_pair is record
    div : signed (15 downto 0);
    remain : signed (3 downto 0); -- was called "rem" before, rem is a vhdl operator and therefore reserved
end record;
type t_v_pair is array(natural range <>) of t_pair;


signal s_EnergyPipe : t_v_pair (1 to 5);
signal s_recordPipe : t_v_hit_postsort (0 to 5);

--   component LPM_DIVIDE
--     generic ( LPM_WIDTHN : natural;    -- MUST be greater than 0
--               LPM_WIDTHD : natural;    -- MUST be greater than 0
              
--               LPM_NREPRESENTATION : string := "UNSIGNED";
--               LPM_DREPRESENTATION : string := "UNSIGNED";
              
--               LPM_PIPELINE : natural := 0;
--               LPM_TYPE : string := L_DIVIDE;
--               LPM_HINT : string := "UNUSED"
--               );
--     port (NUMER     : in std_logic_vector(LPM_WIDTHN-1 downto 0);
--           DENOM     : in std_logic_vector(LPM_WIDTHD-1 downto 0);
--           ACLR      : in std_logic := '0';
--           CLOCK     : in std_logic := '0';
--           CLKEN     : in std_logic := '1';
--           QUOTIENT  : out std_logic_vector(LPM_WIDTHN-1 downto 0);
--           REMAIN    : out std_logic_vector(LPM_WIDTHD-1 downto 0)
--           );
--   end component LPM_DIVIDE;

begin

-- -- DIV5 block for energy
--     LPM_DIVIDE_component : LPM_DIVIDE
--     GENERIC MAP (
--         lpm_drepresentation => "UNSIGNED",
--         lpm_hint => "MAXIMIZE_SPEED=6,LPM_REMAINDERPOSITIVE=TRUE",
--         lpm_nrepresentation => "UNSIGNED",
--         lpm_pipeline => 1,
--         lpm_type => "LPM_DIVIDE",
--         lpm_widthd => 3,
--         lpm_widthn => 15 -- change to 16 ????? (MM)
--     )
--     PORT MAP (
--         clock => i_clk,
--         denom => "101",
--         numer => i_data.E_CC,
--         quotient => std_logic_vector(s_EnergyPipe(1).div)(14 downto 0),  ------ ?????? this is most likely wrong but i want to compile it (MM)
--         remain   => std_logic_vector(s_EnergyPipe(1).remain)(14 downto 0)
--     );

    -- s_recordPipe(0) <= i_data;

    -- p_pipeline : process(i_clk)
    -- begin
    --     if rising_edge(i_clk) then
    --         -- default assignments of pipelines
    --         for i in s_EnergyPipe'low+1 to s_EnergyPipe'high loop
    --             s_EnergyPipe(i) <= s_EnergyPipe(i-1);
    --         end loop;
    --         for i in s_recordPipe'low+1 to s_recordPipe'high loop
    --             s_recordPipe(i) <= s_recordPipe(i-1);
    --         end loop;

    --         -- stage 1 : T-div in lpm instance, n-lapse correction of E
    --         --s_recordPipe(1).T_CC(14 downto 3) <=  s_recordPipe(1).T_CC(14 downto 3) - i_N_lapse(14 downto 3);
    --         -- s_recordPipe(1).T_CC(2 downto 0) <=  s_recordPipe(1).T_CC(14 downto 3) - i_N_lapse(14 downto 3);




    --         -- stage 2 : difference E-T
    --         --s_EnergyPipe(2).div <= s_EnergyPipe(1).div - signed(s_recordPipe.T_CC(14 downto 3));
    --         --s_EnergyPipe(2).remain <= s_EnergyPipe(1).remain - signed(s_recordPipe.T_CC(2 downto 0));


    --         -- stage 3 : add remainder overflow
    --         if ( s_EnergyPipe(2).remain < 0 ) then
    --             s_EnergyPipe(3).div <= s_EnergyPipe(2).div - 1;
    --         end if;

    --         -- stage 4 : add CC lapse
    --         if ( s_EnergyPipe(3).div < 0 ) then
    --             s_EnergyPipe(4).div <= s_EnergyPipe(3).div + ((2**15)-1);
    --         end if;

    --         -- stage 5 : overflow
    --         if ( s_EnergyPipe(4).div > 1023 ) then
    --             s_EnergyPipe(5).div <= 1023;
    --         end if;

    --     end if;
    -- end process;

    --o_data <= s_recordPipe(5);
    --o_data.E_CC <= s_EnergyPipe(5).div(9 downto 0) & s_EnergyPipe(5).remain;

    -- remove me (MM)
    o_data <= i_data;

end architecture;

