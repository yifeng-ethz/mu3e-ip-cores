-- Multiplexing between different asic input channels.
-- Data is registered at the input when valid flag is set.
-- Since total maximum production rate is equal or below the sink speed,
-- the data is passed through directly without backpressure or further buffering.
-- Konrad Briggl, June 2022

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.mutrig_hit_types.all;


entity channelmux is
generic(
	NPORTS : natural--;
);
port (
    i_clk    : in  std_logic;
    i_rst    : in  std_logic;   -- reset, active high
    i_mask   : in  std_logic_vector(NPORTS-1 downto 0);
    i_data   : in  t_v_hit_presort(NPORTS-1 downto 0);
    o_data   : out t_hit_presort
);
end channelmux;

architecture rtl of channelmux is

    signal s_data    : t_v_hit_presort(NPORTS-1 downto 0);
    signal s_select  : natural range 0 to NPORTS-1;
    signal s_init    : std_logic;

begin

    p_mux : process(i_clk)
    begin
    if rising_edge(i_clk) then
        if ( i_rst = '1' ) then
            s_select <= 0;
            s_init  <= '1';
        else
            --after reset, select first input link that gets data immediately, so no hit data is lost.
            if ( s_init = '1' ) then
                for i in i_data'range loop
                    if ( i_data(i).valid  = '1' and i_mask(i) = '0' ) then
                        s_select <= i;
                        s_init <= '0';
                    end if;
                end loop;
            end if;

            -- keep input data as it becomes available
            for i in i_data'range loop
                if ( s_select = i or (i_data(i).valid = '1' and i_mask(i) = '0') ) then
                    s_data(i) <= i_data(i);
                end if;
            end loop;

            -- select next
            if s_select = NPORTS-1 then
                s_select <= 0;
            else
                s_select <= s_select+1;
            end if;
        end if;
    end if;
    end process;

    o_data <= s_data(s_select);

end rtl;
