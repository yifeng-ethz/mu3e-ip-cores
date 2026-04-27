-- File name: rr_arbiter.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Mar 20, 2026
-- =========
-- Description:	[Round-robin arbiter across coalescing-port FIFOs]
--
--			Scans N_PORTS input FIFOs in round-robin order and forwards one
--			data word per clock when the downstream sink is ready.  Outputs the
--			selected port index alongside the data for downstream key computation.
--

-- ================ synthsizer configuration ===================
-- altera vhdl_input_version vhdl_2008
-- =============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.histogram_statistics_v2_pkg.all;

entity rr_arbiter is
    generic (
        N_PORTS    : natural := HS_MAX_PORTS_CONST;
        DATA_WIDTH : natural := 32
    );
    port (
        i_clk        : in  std_logic;
        i_rst        : in  std_logic;
        i_clear      : in  std_logic;
        i_sink_ready : in  std_logic;
        i_fifo_valid : in  std_logic_vector(N_PORTS - 1 downto 0);
        i_fifo_data  : in  hs_slv_array_t(0 to N_PORTS - 1)(DATA_WIDTH - 1 downto 0);
        o_fifo_pop   : out std_logic_vector(N_PORTS - 1 downto 0);
        o_out_valid  : out std_logic;
        o_out_port   : out unsigned(clog2(N_PORTS) - 1 downto 0);
        o_out_data   : out std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
end entity rr_arbiter;

architecture rtl of rr_arbiter is

    constant PORT_WIDTH_CONST : natural := clog2(N_PORTS);

    signal last_served : unsigned(PORT_WIDTH_CONST - 1 downto 0) := (others => '0');
    signal grant_idx_c : unsigned(PORT_WIDTH_CONST - 1 downto 0) := (others => '0');
    signal grant_valid_c : std_logic := '0';
    signal out_valid_q : std_logic := '0';
    signal out_port_q  : unsigned(PORT_WIDTH_CONST - 1 downto 0) := (others => '0');
    signal out_data_q  : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');

begin

    arbiter_comb : process (all)
        variable found_v : boolean;
        variable probe_v : natural;
        variable start_v : natural;
    begin
        found_v    := false;
        grant_idx_c   <= (others => '0');
        grant_valid_c <= '0';

        start_v := (to_integer(last_served) + 1) mod N_PORTS;
        for offset in 0 to N_PORTS - 1 loop
            probe_v := (start_v + offset) mod N_PORTS;
            if (i_fifo_valid(probe_v) = '1')
               and (not found_v)
               and not ((out_valid_q = '1') and (probe_v = to_integer(out_port_q))) then
                found_v     := true;
                grant_valid_c <= '1';
                grant_idx_c   <= to_unsigned(probe_v, PORT_WIDTH_CONST);
            end if;
        end loop;
    end process arbiter_comb;

    o_out_valid <= out_valid_q;
    o_out_port  <= out_port_q;
    o_out_data  <= out_data_q;
    pop_comb : process (all)
        variable pop_v : std_logic_vector(N_PORTS - 1 downto 0);
    begin
        pop_v := (others => '0');
        if (out_valid_q = '1') and (i_sink_ready = '1') then
            pop_v(to_integer(out_port_q)) := '1';
        end if;
        o_fifo_pop <= pop_v;
    end process pop_comb;

    arbiter_reg : process (i_clk)
        variable load_new_v : boolean;
        variable grant_int_v : natural;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or i_clear = '1' then
                last_served <= (others => '0');
                out_valid_q <= '0';
                out_port_q  <= (others => '0');
                out_data_q  <= (others => '0');
            else
                load_new_v := (out_valid_q = '0') or (i_sink_ready = '1');

                if load_new_v then
                    if grant_valid_c = '1' then
                        grant_int_v := to_integer(grant_idx_c);
                        out_valid_q <= '1';
                        out_port_q  <= grant_idx_c;
                        out_data_q  <= i_fifo_data(grant_int_v);
                        last_served <= grant_idx_c;
                    else
                        out_valid_q <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process arbiter_reg;

end architecture rtl;
