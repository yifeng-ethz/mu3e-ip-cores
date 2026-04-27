-- File name: search_for_extreme.vhd 
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Apr 30, 2025
-- =========
-- Description:	[Search For Extreme] 
--      Debrief:
--		   Given the input array, find the maximum or minimum value of the array. 
--
--      Usage: 
--          Supply array to be search on <ingress> interface and retrieve the result on the <result> interface
--          New value at input will flush the output dangling result

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

entity search_for_extreme is 
generic (
    -- IP settings
    SEARCH_TARGET           : string := "MIN"; -- {MAX MIN}
    SEARCH_ARCH             : string := "LIN"; -- {LIN QUAD} LIN: linear talking search (time=O(N),space=O(N)); QUAD: pipeline binary search (time=O(log2(N)),space=O(2N))
    N_ELEMENT               : natural := 4; -- [] total number of elements 
    ELEMENT_SZ_BITS         : natural := 8; -- [bits] array is consists of equal size elements, the size of each element
    ARRAY_SZ_BITS           : natural := 32; -- [bits] total array size in bits
    ELEMENT_INDEX_BITS      : natural := 2

);
port(
    -- avst <ingress> : the input array to be searched on
    asi_ingress_data        : in  std_logic_vector(ARRAY_SZ_BITS-1 downto 0); -- pack of array, lsb and smallest array index in lower bits. ex: [array<3>[3 2 1 0] array<2>[3 2 1 0] array<1>[3 2 1 0] array<0>[3 2 1 0]]
    asi_ingress_valid       : in  std_logic; -- source should indicate whether the data is valid. it can happen that some lanes are been updated
    asi_ingress_ready       : out std_logic; -- (optional) sink can inform source about its status of busy or idle. otherwise, also available on the <result> interface
    
    -- avst <result> : the output element find by the search
    aso_result_data         : out std_logic_vector(ELEMENT_SZ_BITS+ELEMENT_INDEX_BITS-1 downto 0); -- the result consists of [element_max/min element_index]
    aso_result_valid        : out std_logic; -- source indicate the availability of the search result
    aso_result_ready        : in  std_logic; -- sink can indicate the receiption of the node. upon this, valid will be deasserted, but data will remain there until the next result is calculated
    
    -- clock <clk> : the clock interface of the whole IP
    i_clk                   : in  std_logic;
    -- reset <rst> : the reset interface of the whole IP
    i_rst                   : in  std_logic
);
end entity search_for_extreme;

architecture rtl of search_for_extreme is 
    -- -----------------------------------
    -- walking_searcher (comb+reg)
    -- -----------------------------------
    type walking_searcher_state_t is (IDLE,BUSY);
    signal walking_searcher_state       : walking_searcher_state_t;
    
    type compare_node_t is array (0 to N_ELEMENT-1) of std_logic_vector(ELEMENT_SZ_BITS-1 downto 0);
    signal compare_node                 : compare_node_t;
    
    signal current_extreme_value        : std_logic_vector(ELEMENT_SZ_BITS-1 downto 0);
    signal current_extreme_index        : std_logic_vector(ELEMENT_INDEX_BITS-1 downto 0);
    signal walker_progress_counter      : unsigned(ELEMENT_INDEX_BITS downto 0); -- one more bit
    signal walker_result_value          : std_logic_vector(ELEMENT_SZ_BITS-1 downto 0);
    signal walker_result_index          : std_logic_vector(ELEMENT_INDEX_BITS-1 downto 0);
    signal walker_result_found          : std_logic;
    signal update_swap                  : std_logic;
    signal current_def                  : std_logic_vector(ELEMENT_SZ_BITS-1 downto 0);

begin

    assert ARRAY_SZ_BITS = N_ELEMENT * ELEMENT_SZ_BITS report "array total size (bits), element size (bits) and element number mismatch" severity error;
    assert ELEMENT_INDEX_BITS >= integer(ceil(log2(real(N_ELEMENT)))) report "index has no enough bits for the number of elements" severity error;

    -- ///////////////////////////////////////////////////////////////////////
    -- @name        walking_searcher_comb
    -- @berief      derive the interface signals based on internal state
    -- @input       walking_searcher_state, walker_result_found
    -- @output      asi_ingress_ready, aso_result_valid
    -- ///////////////////////////////////////////////////////////////////////
    proc_walking_searcher_comb : process (all)
    begin
        -- indicate ready at ingress
        if (walking_searcher_state = IDLE) then 
            asi_ingress_ready       <= '1';
        else 
            asi_ingress_ready       <= '0';
        end if;
        
        -- post result at egress
        aso_result_data         <= walker_result_value & walker_result_index;
    end process;
    
    
    -- ////////////////////////////////////////////////////////////////////////////////////////////
    -- @name        walking_searcher
    -- @berief      walk through the nodes and update the current extreme value
    -- @input       asi_ingress_<data/valid/ready>
    -- @output      walker_result_<value/index/found>
    -- ////////////////////////////////////////////////////////////////////////////////////////////
    proc_walking_searcher : process (i_clk,i_rst)
    begin
        if (rising_edge(i_clk)) then 
            if (i_rst = '1') then 
                walking_searcher_state          <= IDLE;
                walker_progress_counter         <= (others => '0');
                walker_result_found             <= '0';
                walker_result_value             <= (others => '0');
                walker_result_index             <= (others => '0');
            else 
                -- indicate the data has been taken
                if (aso_result_ready = '1' and aso_result_valid = '1') then 
                    walker_result_found         <= '0';
                end if;
                -- clear posted result (if new data is available, will not clear <= this is correct)
                if (aso_result_ready = '1') then 
                    aso_result_valid        <= '0';
                end if;
                
                
                -- fsm 
                case walking_searcher_state is 
                    when IDLE => 
                        if (asi_ingress_valid = '1') then 
                            -- latch array
                            gen_offload : for i in 0 to N_ELEMENT-1 loop
                                compare_node(i)             <= asi_ingress_data((i+1)*ELEMENT_SZ_BITS-1 downto i*ELEMENT_SZ_BITS);
                            end loop;
                            -- state change
                            walking_searcher_state          <= BUSY;
                        end if;
                        -- reset reg
                        current_extreme_value           <= current_def; -- depends on the search target
                        current_extreme_index           <= (others => '0'); 
                        walker_result_found             <= '0';
          
                    when BUSY => 
                        -- shift
                        gen_shift : for i in 0 to N_ELEMENT-2 loop
                            compare_node(i+1)        <= compare_node(i);
                        end loop;
                        -- compare and update
                        if (update_swap = '1') then 
                            current_extreme_value       <= compare_node(N_ELEMENT-1);
                            current_extreme_index       <= std_logic_vector(to_unsigned(N_ELEMENT - 1 - to_integer(walker_progress_counter), current_extreme_index'length));
                        end if;
                        -- state change 
                        walker_progress_counter <= walker_progress_counter + 1;
                        if (walker_progress_counter = N_ELEMENT) then -- exit 
                            walking_searcher_state          <= IDLE;
                            walker_progress_counter         <= (others => '0');
                            -- latch result 
                            walker_result_value         <= current_extreme_value; -- post result - high bits
                            walker_result_index         <= current_extreme_index; -- post result - low bits
                            aso_result_valid            <= '1'; -- post result valid
                            walker_result_found         <= '1';
                        end if;
                        
                    when others => 
                        null;
                end case;
            end if;  
        end if;
    end process;
    
    
    -- generate the comparator for small or large
    gen_comparator_sign_max : if (SEARCH_TARGET = "MAX") generate 
        update_swap         <= '1' when compare_node(N_ELEMENT-1) > current_extreme_value else '0';
        current_def         <= (others => '0'); -- default will be 0, as the smallest value
    end generate;
    
    gen_comparator_sign_min : if (SEARCH_TARGET = "MIN") generate 
        update_swap         <= '1' when compare_node(N_ELEMENT-1) < current_extreme_value else '0';
        current_def         <= (others => '1'); -- default will be 511, as the largest value 
    end generate;
    
    
    
    
    
    


end architecture rtl;






