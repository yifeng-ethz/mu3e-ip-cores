library IEEE;
use IEEE.std_logic_1164.all;

entity obuf_config is
generic (
    bits : integer := 6;
    datawidth : integer := 1
);
port (
    i_cclk : in std_logic;
    i_reset_n : in std_logic;
    i_cdata : in std_logic_vector(bits-1 downto 0); --incoming configurational data
    o_cclkena : out std_logic_vector(datawidth-1 downto 0); --not sure what this does
    i_cstart : in std_logic;
    o_cdata : out std_logic := '0'; --serial data input
    o_cupdate : out std_logic := '0';
    o_datashift : out std_logic := '0' --half clock shift
);
end entity;

architecture bhv of obuf_config is

	type conf_state is ( fs_idle, fs_rec, fs_send, fs_update );

	constant dstream : integer := 1;

	signal s_ccnt : integer := 0;
	signal s_state : conf_state;

	signal s_cclk : std_logic := '0'; -- clkin
	signal s_cclkena : std_logic_vector(dstream-1 downto 0) := "1";
	signal s_cdata : std_logic_vector(0 to bits-2) := (others => '0'); -- datain
	signal s_cstart : std_logic := '0'; -- initializing signal for fsm
	signal s_startcheck : std_logic := '0'; -- indicator for the "right" start signa
	signal s_cconfout : std_logic := '0'; -- dataout (serialized)
	signal s_cupdateout : std_logic := '0';

begin

	state_machine_conf : process (i_cclk, i_reset_n)
	begin
	if rising_edge(i_cclk) then
		s_cstart <= i_cstart;
		s_cclkena <= "1";
		s_startcheck <= s_cstart;
		if i_reset_n = '1' then
			s_cconfout <= s_cdata(0);
			case s_state is
			when fs_idle =>
				s_cupdateout <= '0';
				s_cconfout <= '0';
				if s_cstart ='1' and s_startcheck = '0' then
					s_state <= fs_rec;
				end if;
			when fs_rec =>
				s_state <= fs_send;
				s_ccnt <= 0;
				s_cdata <= i_cdata(bits-2 downto 0);
			when fs_send =>
				if s_ccnt < 5 then
					s_ccnt <= s_ccnt + 1;
				else
					s_ccnt <= 0;
					s_cconfout <= '0';
					s_cclkena <= "0";
					-- return to idle
					s_state <= fs_update;
				end if;
				for i in 0 to bits-3 loop
					s_cdata(i) <= s_cdata(i+1);
				end loop;
			when fs_update =>
				s_cdata <= (others => '0');
				s_cconfout <= '0';
				if s_ccnt < 10 then
					s_ccnt <= s_ccnt + 1;
				-- send update signal after 10 clock cycles
				elsif s_ccnt = 10 then
					s_ccnt <= s_ccnt + 1;
					s_cupdateout <= '1';
				-- return to idle
				else
					s_ccnt <= 0;
					s_cupdateout <= '0';
					s_state <= fs_idle;
				end if;
			end case;
		else
			s_state <= fs_idle;
		end if;
	end if;
	end process;

    o_datashift <= i_cdata(bits-1);
    o_cdata <= s_cconfout;
    o_cupdate <= s_cupdateout;
    o_cclkena <= s_cclkena;

end architecture;
