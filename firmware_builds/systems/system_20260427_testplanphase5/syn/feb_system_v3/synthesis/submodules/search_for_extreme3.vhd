-- File name: search_for_extreme3.vhd 
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Jul 4, 2025
-- =========
-- Description:	[Search For Extreme3] 
--      Debrief:
--		   Given the input array, find the maximum or minimum value of the array. 
--
--      Usage: 
--          Supply array to be search on <ingress> interface and retrieve the result on the <result> interface
--          New value at input will flush the output dangling result
--
-- ================ synthsizer configuration ===================	
-- altera vhdl_input_version vhdl_2008
-- ============================================================= 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.log2;
use IEEE.math_real.ceil;
use ieee.std_logic_misc.and_reduce;
use ieee.std_logic_misc.or_reduce;

entity search_for_extreme3 is 
generic (
    -- IP settings
    SEARCH_TARGET           : string := "MIN"; -- {MAX MIN}
    SEARCH_ARCH             : string := "LIN"; -- {LIN QUAD} LIN: linear talking search (time=O(N),space=O(N)); QUAD: pipeline binary search (time=O(log2(N)),space=O(2N))
    N_ELEMENT               : natural := 4; -- total number of elements 
    ELEMENT_SZ_BITS         : natural := 9; -- [bits] array is consists of equal size elements, the size of each element
    ARRAY_SZ_BITS           : natural := 36; -- [bits] total array size in bits
    ELEMENT_INDEX_BITS      : natural := 2

);
port(
    -- avst <ingress> : the input array to be searched on
    asi_ingress_data        : in  std_logic_vector(ARRAY_SZ_BITS-1 downto 0); -- pack of array, lsb and smallest array index in lower bits. ex: [array<3>[3 2 1 0] array<2>[3 2 1 0] array<1>[3 2 1 0] array<0>[3 2 1 0]]
    asi_ingress_valid       : in  std_logic; -- source should indicate whether the data is valid. it can happen that some lanes are been updated
    
    -- avst <result> : the output element find by the search
    aso_result_data         : out std_logic_vector(ELEMENT_SZ_BITS+ELEMENT_INDEX_BITS-1 downto 0); -- the result consists of [element_max/min element_index]
    aso_result_valid        : out std_logic; -- source indicate the availability of the search result
    
    -- clock <clk> : the clock interface of the whole IP
    i_clk                   : in  std_logic;
    -- reset <rst> : the reset interface of the whole IP
    i_rst                   : in  std_logic
);
end entity search_for_extreme3;

architecture rtl of search_for_extreme3 is 

    constant N_STAGES : natural := integer(ceil(log2(real(N_ELEMENT))));
    constant N_POW2   : natural := 2**N_STAGES;

    subtype value_t is unsigned(ELEMENT_SZ_BITS-1 downto 0);
    subtype index_t is unsigned(ELEMENT_INDEX_BITS-1 downto 0);

    type value_vec_t is array (0 to N_POW2-1) of value_t;
    type index_vec_t is array (0 to N_POW2-1) of index_t;

    type value_stage_t is array (0 to N_STAGES) of value_vec_t;
    type index_stage_t is array (0 to N_STAGES) of index_vec_t;

    signal stage_val  : value_stage_t;
    signal stage_idx  : index_stage_t;
    signal valid_pipe : std_logic_vector(N_STAGES downto 0);

begin
    assert N_ELEMENT <= N_POW2
        report "search_for_extreme3: N_ELEMENT must be <= 2**ceil(log2(N_ELEMENT))"
        severity failure;

    proc_pipeline : process (i_clk)
        variable used : natural;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                valid_pipe <= (others => '0');
                for s in 0 to N_STAGES loop
                    for e in 0 to N_POW2-1 loop
                        stage_val(s)(e) <= (others => '0');
                        stage_idx(s)(e) <= (others => '0');
                    end loop;
                end loop;
            else
                valid_pipe(0) <= asi_ingress_valid;

                if asi_ingress_valid = '1' then
                    for e in 0 to N_POW2-1 loop
                        if e < N_ELEMENT then
                            stage_val(0)(e) <= unsigned(asi_ingress_data((e+1)*ELEMENT_SZ_BITS-1 downto e*ELEMENT_SZ_BITS));
                            stage_idx(0)(e) <= to_unsigned(e, ELEMENT_INDEX_BITS);
                        else
                            if SEARCH_TARGET = "MAX" then
                                stage_val(0)(e) <= (others => '0');
                            else
                                stage_val(0)(e) <= (others => '1');
                            end if;
                            stage_idx(0)(e) <= (others => '0');
                        end if;
                    end loop;
                end if;

                for s in 0 to N_STAGES-1 loop
                    valid_pipe(s+1) <= valid_pipe(s);
                    used := N_POW2 / (2**(s+1));
                    for e in 0 to used-1 loop
                        if SEARCH_TARGET = "MAX" then
                            if stage_val(s)(2*e) >= stage_val(s)(2*e+1) then
                                stage_val(s+1)(e) <= stage_val(s)(2*e);
                                stage_idx(s+1)(e) <= stage_idx(s)(2*e);
                            else
                                stage_val(s+1)(e) <= stage_val(s)(2*e+1);
                                stage_idx(s+1)(e) <= stage_idx(s)(2*e+1);
                            end if;
                        else
                            if stage_val(s)(2*e) <= stage_val(s)(2*e+1) then
                                stage_val(s+1)(e) <= stage_val(s)(2*e);
                                stage_idx(s+1)(e) <= stage_idx(s)(2*e);
                            else
                                stage_val(s+1)(e) <= stage_val(s)(2*e+1);
                                stage_idx(s+1)(e) <= stage_idx(s)(2*e+1);
                            end if;
                        end if;
                    end loop;
                end loop;
            end if;
        end if;
    end process;

    aso_result_data  <= std_logic_vector(stage_val(N_STAGES)(0)) & std_logic_vector(stage_idx(N_STAGES)(0));
    aso_result_valid <= valid_pipe(N_STAGES);

end architecture;
