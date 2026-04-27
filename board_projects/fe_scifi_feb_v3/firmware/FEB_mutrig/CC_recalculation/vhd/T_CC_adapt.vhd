---------------------------------------
--
-- Adapt coarse counter binning to 8ns, keeping a 3 bit remainder for the 1.6ns coarse counter LSBs.
-- Latency one clock cycle.
-- Konrad Briggl 6/22
----------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;
LIBRARY lpm;
USE lpm.all;

use work.mutrig_hit_types.all;


entity T_CC_adapt is
port (
    --system
    i_clk       : in  std_logic;
    i_rst           : in  std_logic;

    --data stream
    i_data        : in t_hit_presort;
    o_data        : out t_hit_presort_div--;

);
end T_CC_adapt;

architecture impl of T_CC_adapt is
signal s_data : t_v_hit_presort(0 downto 0);
signal s_TCC_div : std_logic_vector(14 DOWNTO 0);
signal s_TCC_rem : std_logic_vector(2 DOWNTO 0);

  component LPM_DIVIDE
    generic ( LPM_WIDTHN : natural;    -- MUST be greater than 0
              LPM_WIDTHD : natural;    -- MUST be greater than 0
              
              LPM_NREPRESENTATION : string := "UNSIGNED";
              LPM_DREPRESENTATION : string := "UNSIGNED";
              
              LPM_PIPELINE : natural := 0;
              LPM_TYPE : string := "LPM_DIVIDE";
              LPM_HINT : string := "UNUSED"
              );
    port (NUMER     : in std_logic_vector(LPM_WIDTHN-1 downto 0);
          DENOM     : in std_logic_vector(LPM_WIDTHD-1 downto 0);
          ACLR      : in std_logic := '0';
          CLOCK     : in std_logic := '0';
          CLKEN     : in std_logic := '1';
          QUOTIENT  : out std_logic_vector(LPM_WIDTHN-1 downto 0);
          REMAIN    : out std_logic_vector(LPM_WIDTHD-1 downto 0)
          );
  end component LPM_DIVIDE;

begin
    LPM_DIVIDE_component : LPM_DIVIDE
    GENERIC MAP (
        lpm_drepresentation => "UNSIGNED",
        lpm_hint => "MAXIMIZE_SPEED=6,LPM_REMAINDERPOSITIVE=TRUE",
        lpm_nrepresentation => "UNSIGNED",
        lpm_pipeline => 1,
        lpm_type => "LPM_DIVIDE",
        lpm_widthd => 3,
        lpm_widthn => 15
    )
    PORT MAP (
        clock => i_clk,
        denom => "101",
        numer => i_data.T_CC,
        quotient => s_TCC_div,
        remain => s_TCC_rem
    );

    p_delay : process(i_clk)
    begin
        if rising_edge(i_clk) then
            s_data(0) <= i_data;
        end if;
    end process;

    p_outputs : process(s_data,s_TCC_div,s_TCC_rem)
    begin
        o_data <= conv_hit_pre2prediv(s_data(0));
        o_data.T_CC_div <= s_TCC_div(12 downto 0);
        o_data.T_CC_rem <= s_TCC_rem;
    end process;
end architecture;
