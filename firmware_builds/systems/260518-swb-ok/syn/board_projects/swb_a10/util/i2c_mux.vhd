--

library ieee;
use ieee.std_logic_1164.all;

entity i2c_mux is
generic (
    -- number of lines
    g_N : positive := 32--;
);
port (
    -- to i2c lines
    io_scl      : inout std_logic_vector(g_N-1 downto 0);
    io_sda      : inout std_logic_vector(g_N-1 downto 0);

    -- from i2c master
    o_scl       : out   std_logic;
    i_scl_oe    : in    std_logic;
    o_sda       : out   std_logic;
    i_sda_oe    : in    std_logic;

    -- line select
    i_mask      : in    std_logic_vector(g_N-1 downto 0)--;
);
end entity;

architecture arch of i2c_mux is

    -- https://www.altera.com/support/support-resources/knowledge-base/solutions/rd01262015_264.html
    signal ZERO : std_logic := '0';
    attribute keep : boolean;
    attribute keep of ZERO : signal is true;

begin

    generate_i2c : for i in i_mask'range generate
    begin
        io_scl(i) <= ZERO when ( i_scl_oe = '1' and i_mask(i) = '1' ) else 'Z';
        io_sda(i) <= ZERO when ( i_sda_oe = '1' and i_mask(i) = '1' ) else 'Z';
        --
    end generate;

    process(i_mask, io_scl, io_sda)
    begin
        o_scl <= '1';
        o_sda <= '1';
        for i in i_mask'range loop
            if ( io_scl(i) = '0' and i_mask(i) = '1' ) then o_scl <= '0'; end if;
            if ( io_sda(i) = '0' and i_mask(i) = '1' ) then o_sda <= '0'; end if;
        end loop;
    end process;

end architecture;
