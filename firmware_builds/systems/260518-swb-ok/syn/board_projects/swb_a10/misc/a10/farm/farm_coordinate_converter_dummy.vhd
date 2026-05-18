-------------------------------------------------------
--! @farm_coordinate_converter_dummy.vhd
--! @brief the farm_coordinate_converter_dummy can be used
--! to simple pack the injected hits
--! Author: mkoeppel@uni-mainz.de
-------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.util_slv.all;

entity farm_coordinate_converter_dummy is
port (
    --! hits per layer input
    i_hits          : in  work.mu3e.link32_array_t(3 downto 0);

    --! hits output
    o_float_hit     : out slv128_array_t(3 downto 0);
    o_sop           : out std_logic_vector(3 downto 0);
    o_eop           : out std_logic_vector(3 downto 0);
    o_valid         : out std_logic_vector(3 downto 0);

    --! 250 MHz clock pice / reset_n
    i_reset_n       : in  std_logic;
    i_clk           : in  std_logic--;
);
end entity;

architecture arch of farm_coordinate_converter_dummy is

    signal counters : slv2_array_t(3 downto 0);
    signal float_hit : slv128_array_t(3 downto 0);
    signal sop, sop_written, valid, sop_reg, eop : std_logic_vector(3 downto 0);

begin

    -- set output
    o_float_hit <= float_hit;
    o_sop <= sop_reg;
    o_eop <= eop;
    o_valid <= valid;

    --! assign output hits
    gen_assign_outputs : FOR i in 0 to 3 GENERATE
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        float_hit(i)    <= (others => '0');
        counters(i)     <= (others => '0');
        sop(i)          <= '0';
        sop_written(i)  <= '0';
        sop_reg(i)      <= '0';
        eop(i)          <= '0';
        valid(i)        <= '0';
        --
    elsif rising_edge(i_clk) then
        sop_reg(i) <= '0';
        -- NOTE: valid(i) and eop(i) can be both '1'
        eop(i) <= i_hits(i).eop;
        valid(i) <= '0';

        sop(i) <= i_hits(i).sop;
        if ( sop(i) = '0' and i_hits(i).sop = '1' ) then
            sop_written(i) <= '1';
        end if;

        if ( i_hits(i).idle = '0' ) then
            if ( counters(i) = "11" ) then
                valid(i) <= '1';
                counters(i) <= (others => '0');
                if ( sop_written(i) = '1' ) then
                    sop_reg(i) <= '1';
                    sop_written(i) <= '0';
                end if;
            else
                counters(i) <= counters(i) + '1';
            end if;
            -- shift register for hit packing LSB is x last one is pixelID
            float_hit(i)(127 downto 96) <= i_hits(i).data;
            float_hit(i)( 95 downto 64) <= float_hit(i)(127 downto 96);
            float_hit(i)( 63 downto 32) <= float_hit(i)(95 downto 64);
            float_hit(i)( 31 downto 0)  <= float_hit(i)(63 downto 32);
        end if;
    end if;
    end process;
    end generate;

end architecture;
