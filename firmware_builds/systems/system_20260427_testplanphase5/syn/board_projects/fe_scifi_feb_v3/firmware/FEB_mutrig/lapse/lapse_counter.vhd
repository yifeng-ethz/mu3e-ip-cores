
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- This entity should correct the early lapsing of the Mutrig cc counter
-- assuming the Mutrig should count from 0 to 3 but it only counts from 0 to 2
-- we have the following "correction":

-- FPGA 2^15-1 counter: 0 1 2 0 1 2 0 1 2
-- nLapse:              0 0 0 1 1 1 2 2 2
-- FPGA CC_ASIC:        - - 1 2 0 1 2 0 1
-- Corrected:           - - 1 2 3 0 1 2 3
-- Corrected <= CC - nLapse when CC < FPGA counter else CC - (nLapse - 1);

-- The correction is done by counting according to the Mutrig by increasing a counter
-- on the FPGA by 5 when we count with the 125MHz clk.

entity lapse_counter is
generic (
    N_CC : positive := 32--;
);
port (
    i_reset_n   : in  std_logic;                            -- i_run_state(RUN_STATE_BITPOS_SYNC)
    i_clk       : in  std_logic;                            -- 125 MHz

    i_upper_bnd : in  std_logic_vector(N_CC - 1 downto 0);  -- upper bnd for the correction (default: 30000)
    i_lower_bnd : in  std_logic_vector(N_CC - 1 downto 0);  -- upper bnd for the correction (default:  2767)

    i_CC        : in  std_logic_vector(N_CC - 1 downto 0);  -- counter from the Mutrig @625MHz
    o_cnt       : out std_logic_vector(63 downto 0);        -- cnt for nLapses (63 downto 32) and CC_fpga <= 32767 case
    o_CC        : out std_logic_vector(N_CC - 1 downto 0)   -- corrected Mutrig counter
);
end entity;

architecture arch of lapse_counter is

    signal s_o_CC, i_CC_u : unsigned(N_CC - 1 downto 0);
    signal upper, lower, CC_fpga, nLapses, cntCCsmaller : natural range 0 to 32767 := 0;

begin

    -- cnt output
    o_cnt <= std_logic_vector(to_unsigned(nLapses, 32)) & std_logic_vector(to_unsigned(cntCCsmaller, 32));

    -- counting lapsing of coarse counter
    -- CC lapses every 2^15-1 cycles @ 625MHz.
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        nLapses <= 0;
        CC_fpga <= 0;
        cntCCsmaller <= 0;
    elsif rising_edge(i_clk) then
        -- in the following we have 5 different edge cases where
        -- the internal CC_fpga counter runs away from the Mutrig
        -- counter. To counter this we set the correct next value
        if ( CC_fpga = 32765 ) then
            nLapses <= nLapses + 1;
            CC_fpga <= 3;
        elsif ( CC_fpga = 32763 ) then
            nLapses <= nLapses + 1;
            CC_fpga <= 1;
        elsif ( CC_fpga = 32766 ) then
            nLapses <= nLapses + 1;
            CC_fpga <= 4;
        elsif ( CC_fpga = 32764 ) then
            nLapses <= nLapses + 1;
            CC_fpga <= 2;
        elsif ( CC_fpga = 32767 ) then
            nLapses <= nLapses + 1;
            CC_fpga <= 5;
        else
            CC_fpga <= CC_fpga + 5;
        end if;
        if (CC_fpga < 32768 and CC_fpga > upper and i_CC_u < lower) then
            cntCCsmaller <= cntCCsmaller + 1;
        end if;
        -- for simulation
        -- synthesis translate_off
        if (i_CC_u < 32767 and i_CC_u > upper and CC_fpga < lower) then
            report "i_CC_u " & work.util.to_hstring(std_logic_vector(i_CC_u));
            report "nLapses " & work.util.to_hstring(std_logic_vector(to_unsigned(nLapses, o_CC'length)));
            report "s_o_CC " & work.util.to_hstring(std_logic_vector(s_o_CC));
        end if;
        if (CC_fpga < 32768 and CC_fpga > upper and i_CC_u < lower) then
            report "this case should never happen";
        end if;
        -- synthesis translate_on
    end if;
    end process;

    -- assuming that the default delay is in the range of
    -- upper=30000 to 32766/7 and 0 to lower=2767
    -- get upper lower bnd
    upper       <=  to_integer(unsigned(i_upper_bnd));
    lower       <=  to_integer(unsigned(i_lower_bnd));

    -- convert i_CC to unsigned
    i_CC_u      <=  unsigned(i_CC);

                    -- check if i_CC_u did not lapse but the interal counter did
--    s_o_CC      <=  i_CC_u - (nLapses - 1) when i_CC_u  < 32767 and i_CC_u  > upper and CC_fpga < lower and nLapses > 0 else
--                    -- this case should never happen
--                    i_CC_u - (nLapses + 1) when CC_fpga < 32768 and CC_fpga > upper and i_CC_u  < lower else
--                    i_CC_u - nLapses;
    s_o_CC      <= i_CC_u - nLapses;
    o_CC        <=  std_logic_vector(s_o_CC);

end architecture;
