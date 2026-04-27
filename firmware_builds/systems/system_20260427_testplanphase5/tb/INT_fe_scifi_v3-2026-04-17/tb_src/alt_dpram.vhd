library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alt_dpram is
  port (
    data      : in  std_logic_vector(31 downto 0);
    rdaddress : in  std_logic_vector(13 downto 0);
    rdclock   : in  std_logic;
    wraddress : in  std_logic_vector(8 downto 0);
    wrclock   : in  std_logic := '1';
    wren      : in  std_logic := '0';
    q         : out std_logic_vector(0 downto 0)
  );
end entity alt_dpram;

architecture SYN of alt_dpram is
  subtype ram_addr_t is integer range 0 to 16383;

  signal ram_bits     : std_logic_vector(16383 downto 0) := (others => '0');
  signal rdaddress_q  : unsigned(13 downto 0) := (others => '0');
begin
  -- QuestaOne 2026 rejects the legacy VHDL altsyncram wrapper used by the
  -- generated MuTRiG configuration RAM. Keep synthesis sources untouched and
  -- use a narrow simulation-only model with the same bit layout:
  -- bit address N maps to write word floor(N/32), bit index N mod 32.
  process (wrclock)
    variable base_idx : integer;
  begin
    if rising_edge(wrclock) then
      if wren = '1' then
        base_idx := to_integer(unsigned(wraddress)) * 32;
        for bit_idx in 0 to 31 loop
          ram_bits(base_idx + bit_idx) <= data(bit_idx);
        end loop;
      end if;
    end if;
  end process;

  process (rdclock)
  begin
    if rising_edge(rdclock) then
      rdaddress_q <= unsigned(rdaddress);
    end if;
  end process;

  q(0) <= ram_bits(ram_addr_t(to_integer(rdaddress_q)));
end architecture SYN;
