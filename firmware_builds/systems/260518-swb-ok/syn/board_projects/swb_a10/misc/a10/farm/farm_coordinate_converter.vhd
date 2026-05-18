--

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity farm_coordinate_converter is
generic (
    NCHIPS : integer := 252;
    g_DATA_WIDTH : positive := 8;
    g_ADDR_WIDTH : positive := 8--;
);
port (
    i_chip      : in    std_logic_vector(7 downto 0);
    i_row       : in    std_logic_vector(7 downto 0);
    i_col       : in    std_logic_vector(7 downto 0);
    i_ena       : in    std_logic;

    o_x         : out   std_logic_vector(31 downto 0);
    o_y         : out   std_logic_vector(31 downto 0);
    o_z         : out   std_logic_vector(31 downto 0);
    o_ena       : out   std_logic;

    i_ramaddr   : in    std_logic_vector(7+4 downto 0);
    i_ramdata   : in    std_logic_vector(31 downto 0);
    i_ramwren   : in    std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture rtl of farm_coordinate_converter is

    signal ramin : std_logic_vector(287 downto 0);
    signal ramout : std_logic_vector(287 downto 0);
    signal ramwren : std_logic;

    signal aclr : std_logic_vector(1 downto 0);

    signal sx : std_logic_vector(31 downto 0);
    signal sy : std_logic_vector(31 downto 0);
    signal sz : std_logic_vector(31 downto 0);

    signal cx : std_logic_vector(31 downto 0);
    signal cy : std_logic_vector(31 downto 0);
    signal cz : std_logic_vector(31 downto 0);

    signal rx : std_logic_vector(31 downto 0);
    signal ry : std_logic_vector(31 downto 0);
    signal rz : std_logic_vector(31 downto 0);

    signal rxdel1 : std_logic_vector(31 downto 0);
    signal rydel1 : std_logic_vector(31 downto 0);
    signal rzdel1 : std_logic_vector(31 downto 0);

    signal rxdel2 : std_logic_vector(31 downto 0);
    signal rydel2 : std_logic_vector(31 downto 0);
    signal rzdel2 : std_logic_vector(31 downto 0);

    signal rxdel3 : std_logic_vector(31 downto 0);
    signal rydel3 : std_logic_vector(31 downto 0);
    signal rzdel3 : std_logic_vector(31 downto 0);

    signal rxdel4 : std_logic_vector(31 downto 0);
    signal rydel4 : std_logic_vector(31 downto 0);
    signal rzdel4 : std_logic_vector(31 downto 0);


    signal coldel : std_logic_vector(7 downto 0);
    signal rowdel1 : std_logic_vector(7 downto 0);
    signal rowdel2 : std_logic_vector(7 downto 0);
    signal rowdel3 : std_logic_vector(7 downto 0);
    signal rowdel4 : std_logic_vector(7 downto 0);
    signal rowdel5 : std_logic_vector(7 downto 0);

    signal row : std_logic_vector(31 downto 0);
    signal col : std_logic_vector(31 downto 0);

    signal sx_plus_col_x_cx : std_logic_vector(31 downto 0);
    signal sy_plus_col_x_cy : std_logic_vector(31 downto 0);
    signal sz_plus_col_x_cz : std_logic_vector(31 downto 0);

    signal enadel : std_logic_vector(8 downto 0);

begin

    -- logic for multiplexing into our wide ram
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        ramwren <= '0';
        ramin   <= (others => '0');
    elsif rising_edge(i_clk) then
        ramwren <= '0';
        if(i_ramwren = '1') then
            case i_ramaddr(3 downto 0) is
            when "0000" =>
                ramin(31 downto  0) <=  i_ramdata;
            when "0001" =>
                ramin(63 downto  32) <=  i_ramdata;
            when "0010" =>
                ramin(95 downto  64) <=  i_ramdata;
            when "0011" =>
                ramin(127 downto  96) <=  i_ramdata;
            when "0100" =>
                ramin(159 downto  128) <=  i_ramdata;
            when "0101" =>
                ramin(191 downto  160) <=  i_ramdata;
            when "0110" =>
                ramin(223 downto  192) <=  i_ramdata;
            when "0111" =>
                ramin(255 downto  224) <=  i_ramdata;
            when "1000" =>
                ramin(287 downto  256) <=  i_ramdata;
                ramwren <=  '1';
            when others =>
            end case;
        end if;
    end if;
    end process;

    -- setup ram
    e_ram : entity work.ram_1r1w
    generic map (
        g_DATA_WIDTH => g_DATA_WIDTH,
        g_ADDR_WIDTH => g_ADDR_WIDTH--,
    )
    port map (
        i_waddr => i_ramaddr(11 downto 4),
        i_wdata => ramin,
        i_we    => ramwren,
        i_wclk  => i_clk,

        i_raddr => i_chip,
        o_rdata => ramout,
        i_rclk  => i_clk--,
    );

    -- Renaming for convenience and profit
    aclr(0)  <= not i_reset_n;
    aclr(1)  <= not i_reset_n;
    sx <= ramout(31 downto 0);
    sy <= ramout(63 downto 32);
    sz <= ramout(95 downto 64);

    cx <= ramout(127 downto 96);
    cy <= ramout(159 downto 128);
    cz <= ramout(191 downto 160);

    rx <= ramout(223 downto 192);
    ry <= ramout(255 downto 224);
    rz <= ramout(287 downto 256);

    -- delays
    process(i_clk)
    begin
    if rising_edge(i_clk) then
        coldel <= i_col;
        rowdel1 <= i_row;
        rowdel2 <= rowdel1;
        rowdel3 <= rowdel2;
        rowdel4 <= rowdel3;
        rowdel5 <= rowdel4;

        rxdel1 <= rx;
        rxdel2 <= rxdel1;
        rxdel3 <= rxdel2;
        rxdel4 <= rxdel3;

        rydel1 <= ry;
        rydel2 <= rydel1;
        rydel3 <= rydel2;
        rydel4 <= rydel3;

        rzdel1 <= rz;
        rzdel2 <= rzdel1;
        rzdel3 <= rzdel2;
        rzdel4 <= rzdel3;

        enadel(0) <= i_ena;
        enadel(8 downto 1) <= enadel(7 downto 0);
        o_ena <= enadel(8);
    end if;
    end process;

    -- int to float converters
    e_ctof : entity work.int_to_float
    port map (
        i_int       => coldel,
        o_float     => col,
        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    e_rtof : entity work.int_to_float
    port map (
        i_int       => rowdel5,
        o_float     => row,
        i_reset_n   => i_reset_n,
        i_clk       => i_clk--,
    );

    e_madd_x_col : component work.cmp.ip_madd
    port map (
        result => sx_plus_col_x_cx,
        ax     => sx,
        ay     => col,
        az     => cx,
        ena    => '1',
        aclr   => aclr,
        clk    => i_clk--,
    );

    e_madd_y_col : component work.cmp.ip_madd
    port map (
        aclr   => aclr,
        ax     => sy,
        ay     => col,
        az     => cy,
        clk    => i_clk,
        ena    => '1',
        result => sy_plus_col_x_cy--,
    );

    e_madd_z_col : component work.cmp.ip_madd
    port map (
        aclr   => aclr,
        ax     => sz,
        ay     => col,
        az     => cz,
        clk    => i_clk,
        ena    => '1',
        result => sz_plus_col_x_cz--,
    );

    e_madd_x_row : component work.cmp.ip_madd
    port map (
        aclr   => aclr,
        ax     => sx_plus_col_x_cx,
        ay     => row,
        az     => rxdel4,
        clk    => i_clk,
        ena    => '1',
        result => o_x--,
    );

    e_madd_y_row : component work.cmp.ip_madd
    port map (
        aclr   => aclr,
        ax     => sy_plus_col_x_cy,
        ay     => row,
        az     => rydel4,
        clk    => i_clk,
        ena    => '1',
        result => o_y--,
    );

    e_madd_z_row : component work.cmp.ip_madd
    port map (
        aclr   => aclr,
        ax     => sz_plus_col_x_cz,
        ay     => row,
        az     => rzdel4,
        clk    => i_clk,
        ena    => '1',
        result => o_z--,
    );

end architecture;
