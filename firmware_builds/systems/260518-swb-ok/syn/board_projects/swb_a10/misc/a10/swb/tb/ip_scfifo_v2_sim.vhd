library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ip_scfifo_v2 is
generic (
    g_ADDR_WIDTH : positive := 8;
    g_DATA_WIDTH : positive := 8;
    g_WREG_N : natural := 0;
    g_RREG_N : natural := 0;
    g_SHOWAHEAD : string := "ON";
    g_RAM_OUTREG : string := "OFF";
    g_DEVICE_FAMILY : string := "Arria 10";
    g_LPM_HINT : string := "UNUSED"--;
);
port (
    i_we            : in    std_logic;
    i_wdata         : in    std_logic_vector(g_DATA_WIDTH-1 downto 0);
    o_wfull         : out   std_logic;
    o_wfull_n       : out   std_logic;
    o_almost_full   : out   std_logic;

    i_rack          : in    std_logic;
    o_rdata         : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);
    o_rempty        : out   std_logic;
    o_rempty_n      : out   std_logic;
    o_almost_empty  : out   std_logic;

    o_usedw         : out   std_logic_vector(g_ADDR_WIDTH-1 downto 0);

    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic--;
);
end entity;

architecture sim of ip_scfifo_v2 is
  constant c_DEPTH : positive := 2**g_ADDR_WIDTH;
  type mem_t is array (0 to c_DEPTH-1) of std_logic_vector(g_DATA_WIDTH-1 downto 0);

  signal mem   : mem_t := (others => (others => '0'));
  signal wptr  : natural range 0 to c_DEPTH-1 := 0;
  signal rptr  : natural range 0 to c_DEPTH-1 := 0;
  signal count : natural range 0 to c_DEPTH := 0;
begin
  p_fifo : process(i_clk)
    variable do_write_v : boolean;
    variable do_read_v  : boolean;
    variable next_wptr_v : natural range 0 to c_DEPTH-1;
    variable next_rptr_v : natural range 0 to c_DEPTH-1;
  begin
    if rising_edge(i_clk) then
      if i_reset_n /= '1' then
        mem   <= (others => (others => '0'));
        wptr  <= 0;
        rptr  <= 0;
        count <= 0;
      else
        do_write_v := (i_we = '1') and (count < c_DEPTH);
        do_read_v  := (i_rack = '1') and (count > 0);

        next_wptr_v := wptr;
        next_rptr_v := rptr;

        if do_write_v then
          mem(wptr) <= i_wdata;
          if wptr = c_DEPTH-1 then
            next_wptr_v := 0;
          else
            next_wptr_v := wptr + 1;
          end if;
        end if;

        if do_read_v then
          if rptr = c_DEPTH-1 then
            next_rptr_v := 0;
          else
            next_rptr_v := rptr + 1;
          end if;
        end if;

        wptr <= next_wptr_v;
        rptr <= next_rptr_v;

        if do_write_v and not do_read_v then
          count <= count + 1;
        elsif do_read_v and not do_write_v then
          count <= count - 1;
        end if;
      end if;
    end if;
  end process;

  o_rdata <= mem(rptr) when count > 0 else (others => '0');
  o_wfull <= '1' when count = c_DEPTH else '0';
  o_wfull_n <= '0' when count = c_DEPTH else '1';
  o_almost_full <= '1' when count >= c_DEPTH-1 else '0';
  o_rempty <= '1' when count = 0 else '0';
  o_rempty_n <= '0' when count = 0 else '1';
  o_almost_empty <= '1' when count <= 1 else '0';
  o_usedw <= std_logic_vector(to_unsigned(count mod c_DEPTH, g_ADDR_WIDTH));
end architecture;
