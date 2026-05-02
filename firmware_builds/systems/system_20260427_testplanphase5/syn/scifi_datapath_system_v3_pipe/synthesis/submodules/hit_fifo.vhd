-- File name: hit_fifo.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.0 (file created)
--		Date: Mar 20, 2026
-- =========
-- Revision: 1.1
--		Date: Apr 27, 2026
--		Change: Register the FIFO head word and add write-bypass for
--		        first/replacement entries. This removes the asynchronous
--		        MLAB read path from the round-robin arbiter timing cone.
-- Revision: 1.2
--		Date: Apr 27, 2026
--		Change: Keep the head register stable when the FIFO becomes empty.
--		        The valid contract is carried by o_empty, so clearing stale
--		        data only created a long read-pop to synchronous-clear path.
-- Revision: 1.3
--		Date: Apr 29, 2026
--		Change: Update the diagnostic peak-level register from the already
--		        registered FIFO level instead of the same-cycle next-level
--		        variable. This keeps the arbiter pop/read cone out of the
--		        max-level comparator while preserving exact peak tracking
--		        with one-cycle reporting latency.
-- =========
-- Description:	[Small single-clock FIFO for serialized hit keys]
--
--			MLAB-based FIFO with parameterised depth (2**FIFO_ADDR_WIDTH).
--			Tracks current fill level and peak level for diagnostics. One
--			instance per ingress port buffers extracted keys before the
--			round-robin arbiter. The output is the registered current head.
--

-- ================ synthsizer configuration ===================
-- altera vhdl_input_version vhdl_2008
-- =============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.histogram_statistics_v2_pkg.all;

entity hit_fifo is
    generic (
        DATA_WIDTH      : natural := 32;
        FIFO_ADDR_WIDTH : natural := 4
    );
    port (
        i_clk        : in  std_logic;
        i_rst        : in  std_logic;
        i_clear      : in  std_logic;
        i_write      : in  std_logic;
        i_write_data : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        i_read       : in  std_logic;
        o_read_data  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        o_empty      : out std_logic;
        o_full       : out std_logic;
        o_level      : out unsigned(FIFO_ADDR_WIDTH downto 0);
        o_level_max  : out unsigned(FIFO_ADDR_WIDTH downto 0)
    );
end entity hit_fifo;

architecture rtl of hit_fifo is

    constant FIFO_DEPTH_CONST : natural := 2 ** FIFO_ADDR_WIDTH;

    subtype fifo_ptr_t   is unsigned(FIFO_ADDR_WIDTH - 1 downto 0);
    subtype fifo_level_t is unsigned(FIFO_ADDR_WIDTH downto 0);

    type fifo_mem_t is array (0 to FIFO_DEPTH_CONST - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);

    signal mem       : fifo_mem_t   := (others => (others => '0'));
    signal rd_ptr    : fifo_ptr_t   := (others => '0');
    signal wr_ptr    : fifo_ptr_t   := (others => '0');
    signal level_reg : fifo_level_t := (others => '0');
    signal max_reg   : fifo_level_t := (others => '0');
    signal empty_q   : std_logic    := '1';
    signal full_q    : std_logic    := '0';
    signal read_data_q : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');

    attribute ramstyle : string;
    attribute ramstyle of mem : signal is "MLAB,no_rw_check";
    attribute preserve : boolean;
    attribute preserve of read_data_q : signal is true;
    attribute dont_retime : boolean;
    attribute dont_retime of read_data_q : signal is true;

begin

    o_read_data <= read_data_q;
    o_empty     <= empty_q;
    o_full      <= full_q;
    o_level     <= level_reg;
    o_level_max <= max_reg;

    fifo_reg : process (i_clk)
        variable rd_ptr_v : fifo_ptr_t;
        variable wr_ptr_v : fifo_ptr_t;
        variable wr_addr_v : fifo_ptr_t;
        variable level_v  : fifo_level_t;
        variable read_v   : boolean;
        variable write_v  : boolean;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or i_clear = '1' then
                rd_ptr    <= (others => '0');
                wr_ptr    <= (others => '0');
                level_reg <= (others => '0');
                max_reg   <= (others => '0');
                empty_q   <= '1';
                full_q    <= '0';
                read_data_q <= (others => '0');
            else
                rd_ptr_v := rd_ptr;
                wr_ptr_v := wr_ptr;
                wr_addr_v := wr_ptr;
                level_v  := level_reg;

                read_v  := (i_read = '1') and (level_reg /= 0);
                write_v := (i_write = '1') and (to_integer(level_v) < FIFO_DEPTH_CONST);

                if read_v then
                    rd_ptr_v := rd_ptr_v + 1;
                    level_v  := level_v - 1;
                end if;

                if write_v then
                    wr_addr_v := wr_ptr_v;
                    mem(to_integer(wr_addr_v)) <= i_write_data;
                    wr_ptr_v := wr_ptr_v + 1;
                    level_v  := level_v + 1;
                end if;

                rd_ptr    <= rd_ptr_v;
                wr_ptr    <= wr_ptr_v;
                level_reg <= level_v;
                empty_q   <= bool_to_sl(level_v = 0);
                full_q    <= bool_to_sl(to_integer(level_v) = FIFO_DEPTH_CONST);
                if level_reg > max_reg then
                    max_reg <= level_reg;
                end if;

                if write_v and (wr_addr_v = rd_ptr_v) then
                    read_data_q <= i_write_data;
                elsif read_v and (level_reg > 1) then
                    read_data_q <= mem(to_integer(rd_ptr_v));
                end if;
            end if;
        end if;
    end process fifo_reg;

end architecture rtl;
