
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

ENTITY histogram_generic_tb IS
end entity;

ARCHITECTURE arch OF histogram_generic_tb IS

    -- constants
    -- signals
    SIGNAL busy_n : STD_LOGIC;
    SIGNAL can_overflow : STD_LOGIC;
    SIGNAL data_in : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL ena : STD_LOGIC;
    SIGNAL q_out : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL raddr_in : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL rclk : STD_LOGIC;
    SIGNAL rst_n : STD_LOGIC;
    SIGNAL valid_in : STD_LOGIC;
    SIGNAL wclk : STD_LOGIC;
    SIGNAL zeromem : STD_LOGIC;
    signal injections : std_logic_vector(31 downto 0);
    signal counter    : std_logic_vector(31 downto 0);

BEGIN

    i1 : entity work.histogram_generic
    port map (
-- list connections between master ports and signals
        i_raddr => raddr_in,
        o_rdata => q_out,
        i_rclk => rclk,

        o_busy_n => busy_n,
        i_can_overflow => can_overflow,
        i_wdata => data_in,
        i_ena => ena,
        i_valid => valid_in,
        i_wclk => wclk,

        i_zeromem => zeromem,
        i_reset_n => rst_n--,
    );

    PROCESS
    -- variable declarations
    BEGIN
            -- code that executes only once
        rst_n           <= '0';
        ena             <= '0';
        can_overflow    <= '0';
        zeromem         <= '0';
        raddr_in        <= (others => '0');
        injections      <= x"0000FFFF";
        wait for 20 ns;
        rst_n           <= '1';
        wait for 20 ns;
     --   zeromem         <= '1';
        wait for 20 ns;
        ena             <= '1';
        wait for 10 us;
        ena             <= '0';
        wait for 100 ns;
        raddr_in        <= raddr_in+1;
        wait for 10 ns;
        raddr_in        <= raddr_in+1;
        wait for 10 ns;
        raddr_in        <= raddr_in+1;
        wait for 10 ns;
        raddr_in        <= raddr_in+1;
        wait for 10 ns;
        zeromem         <= '1';

    WAIT;
    end process;

    process
    begin
        wclk <= '0';
        wait for 2 ns;
        wclk <= '1';
        wait for 2 ns;
    end process;

    process
    begin
        rclk <= '0';
        wait for 2.5 ns;
        rclk <= '1';
        wait for 2.5 ns;
    end process;

    PROCESS(wclk)
    BEGIN
    if rising_edge(wclk) then
        if ( rst_n = '0' ) then
            valid_in <= '0';
            data_in <= (others => '0');
            counter <= (others => '0');
        else
            if(ena = '1' and counter < injections)then
                valid_in <= '1';
                data_in <= data_in + 31;
                counter <= counter + 1;
                if ( to_integer(unsigned(counter)) mod 29 = 0 ) then
                    valid_in <= '0';
                end if;
            else
                valid_in <= '0';
            end if;
        end if;
    end if;
    END PROCESS;

end architecture;
