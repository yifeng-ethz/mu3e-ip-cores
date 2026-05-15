-- Sorter reg mapping, fairly generic
-- M. Mueller, Nov 2021

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sorter_registers.all; 
use work.mudaq.all;

entity sorter_reg_mapping is
generic (
    IS_SORTER_TWO   : integer := 0;
    NSORTERINPUTS   : integer := 12; -- If larger than 12, the register mapping needs to be adapted
    TIMESTAMPSIZE   : integer := 11 -- should not be larger than 32
 );
port (
    i_clk156                    : in  std_logic;
    i_reset_n                   : in  std_logic;

    i_reg_add                   : in  std_logic_vector(15 downto 0);
    i_reg_re                    : in  std_logic;
    o_reg_rdata                 : out std_logic_vector(31 downto 0);
    i_reg_we                    : in  std_logic;
    i_reg_wdata                 : in  std_logic_vector(31 downto 0);

    i_nintime                   : in  reg32array(NSORTERINPUTS-1 downto 0);
    i_noutoftime                : in  reg32array(NSORTERINPUTS-1 downto 0);
    i_noverflow                 : in  reg32array(NSORTERINPUTS-1 downto 0);
    i_nout                      : in  reg32;
    i_credit                    : in  reg32;
    i_sorter_debug              : in  reg32;

    o_sorter_delay              : out std_logic_vector(TIMESTAMPSIZE-1 downto 0)--;
);
end entity;

architecture rtl of sorter_reg_mapping is
    signal sorter_delay              : std_logic_vector(TIMESTAMPSIZE-1 downto 0);

    signal nintime                   : reg32array(NSORTERINPUTS-1 downto 0);
    signal noutoftime                : reg32array(NSORTERINPUTS-1 downto 0);
    signal noverflow                 : reg32array(NSORTERINPUTS-1 downto 0);
    signal nout                      : reg32;
    signal credit                    : reg32;

    begin
    process (i_clk156, i_reset_n)
        variable regaddr : integer;
    begin
        if (i_reset_n = '0') then 
            o_sorter_delay              <= (others => '0');
            sorter_delay                <= (others => '0');--"101" & x"FC";
        elsif(rising_edge(i_clk156)) then
            o_sorter_delay              <= sorter_delay;

            -- register sorter signals once in 156 Mhz domain and put a false path between i_nintime and nintime, ...
            nintime                     <= i_nintime;
            noutoftime                  <= i_noutoftime;
            noverflow                   <= i_noverflow;
            nout                        <= i_nout;
            credit                      <= i_credit;

            if ( IS_SORTER_TWO = 1 ) then
                regaddr                 := to_integer(unsigned(i_reg_add))+112;
            else
                regaddr                 := to_integer(unsigned(i_reg_add));
            end if;
            o_reg_rdata                 <= (others => '0');

            -----------------------------------------------------------------
            ---- sorter regs ------------------------------------------------
            -----------------------------------------------------------------
            for I in 0 to NSORTERINPUTS-1 loop 
                if ( regaddr = I + SORTER_NINTIME_REGISTER_R and i_reg_re = '1' ) then
                    o_reg_rdata <= nintime(I);
                end if;
            end loop;

            for I in 0 to NSORTERINPUTS-1 loop 
                if ( regaddr = I + SORTER_NOUTOFTIME_REGISTER_R and i_reg_re = '1' ) then
                    o_reg_rdata <= noutoftime(I);
                end if;
            end loop;

            for I in 0 to NSORTERINPUTS-1 loop 
                if ( regaddr = I + SORTER_NOVERFLOW_REGISTER_R and i_reg_re = '1' ) then
                    o_reg_rdata <= noverflow(I);
                end if;
            end loop;

            if ( regaddr = SORTER_DEBUG_REGISTER_R and i_reg_re = '1' ) then
                o_reg_rdata <= i_sorter_debug;
            end if;

            if ( regaddr = SORTER_NOUT_REGISTER_R and i_reg_re = '1' ) then
                o_reg_rdata <= nout;
            end if;

            if ( regaddr = SORTER_CREDIT_REGISTER_R and i_reg_we = '1' ) then
                o_reg_rdata <= credit;
            end if;

            if ( regaddr = SORTER_DELAY_REGISTER_W and i_reg_we = '1' ) then
                sorter_delay <= i_reg_wdata(TIMESTAMPSIZE-1 downto 0);
            end if;
            if ( regaddr = SORTER_DELAY_REGISTER_W and i_reg_re = '1' ) then
                o_reg_rdata(TIMESTAMPSIZE-1 downto 0) <= sorter_delay;
            end if;
        end if;
    end process;
end architecture;
