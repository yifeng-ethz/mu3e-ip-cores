library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity max10_spi is
port (
    -- Max10 SPI
    o_SPI_csn    : out std_logic;
    o_SPI_clk   : out std_logic;
    io_SPI_mosi : inout std_logic;
    io_SPI_miso : inout std_logic;
    io_SPI_D1   : inout std_logic;
    io_SPI_D2   : inout std_logic;
    io_SPI_D3   : inout std_logic;

    -- Interface to Arria
    clk50      : in std_logic;
    reset_n     : in std_logic;
    strobe      : in std_logic;
    addr        : in std_logic_vector(6 downto 0);
    rw          : in std_logic;
    data_to_max : in std_logic_vector(31 downto 0);
    numbytes    : in std_logic_vector(8 downto 0);
    next_data   : out std_logic;
    word_from_max : out std_logic_vector(31 downto 0);
    word_en       : out std_logic;
    byte_from_max : out std_logic_vector(7 downto 0);
    byte_en       : out std_logic;
    busy          : out std_logic
);
end entity;

architecture RTL of max10_spi is

    type spistate_type is (idle, address, writing, waiting, reading);
    signal spistate : spistate_type;
    signal addrshiftregister : std_logic_vector(7 downto 0);
    signal datashiftregister : std_logic_vector(31 downto 0);
    signal datareadshiftregister : std_logic_vector(31 downto 0);
    signal toggle: std_logic;
    signal nibblecount : integer;
    signal strobe_last  : std_logic;
    signal haveread : std_logic;

    begin

    process(clk50, reset_n)
    begin
    if(reset_n = '0')then
        o_SPI_csn        <= '1';
        o_SPI_clk       <= '0';
        io_SPI_mosi     <= 'Z';
        io_SPI_miso     <= 'Z';
        io_SPI_D1       <= 'Z';
        io_SPI_D2       <= 'Z';
        io_SPI_D3       <= 'Z';
        spistate        <= idle;
        word_en         <= '0';
        byte_en         <= '0';
        next_data       <= '0';
        strobe_last     <= '0';
        busy            <= '0';
    elsif rising_edge(clk50) then
        word_en         <= '0';
        byte_en         <= '0';
        next_data       <= '0';
        strobe_last     <= strobe;
        case spistate is
        when idle =>
            o_SPI_csn        <= '1';
            o_SPI_clk       <= '0';
            io_SPI_mosi     <= 'Z';
            io_SPI_miso     <= 'Z';
            io_SPI_D1       <= 'Z';
            io_SPI_D2       <= 'Z';
            io_SPI_D3       <= 'Z';
            busy            <= '0';
            if(strobe = '1' and strobe_last = '0')then
                spistate    <= address;
                busy        <= '1';
                o_SPI_csn    <= '0';
                addrshiftregister <= rw & addr;
                toggle <= '0';
                nibblecount <= 0;
            end if;
        when address =>
            toggle <= not toggle;
            if(toggle = '0')then
                o_SPI_clk       <= '0';
                io_SPI_mosi     <= addrshiftregister(0);
                io_SPI_D1       <= addrshiftregister(1);
                io_SPI_D2       <= addrshiftregister(2);
                io_SPI_D3       <= addrshiftregister(3);
                addrshiftregister(3 downto 0) <= addrshiftregister(7 downto 4);
                nibblecount     <= nibblecount +1;
            else
                o_SPI_clk       <= '1';
            end if;
            if(nibblecount = 2)then
                if(rw = '1')then
                    spistate <= writing;
                    datashiftregister   <= data_to_max;
                    next_data           <= '1';
                    nibblecount         <= 0;
                else
                    spistate <= waiting;
                    nibblecount         <= 0;
                end if;
            end if;
        when writing =>
            toggle <= not toggle;
            if(toggle = '0')then
                o_SPI_clk       <= '0';
                io_SPI_mosi     <= datashiftregister(0);
                io_SPI_D1       <= datashiftregister(1);
                io_SPI_D2       <= datashiftregister(2);
                io_SPI_D3       <= datashiftregister(3);
                datashiftregister(27 downto 0) <= datashiftregister(31 downto 4);
                nibblecount     <= nibblecount +1;
                if(nibblecount/2 = to_integer(unsigned(numbytes)))then
                    spistate <= idle;
                end if;
            else
                o_SPI_clk       <= '1';
                if(nibblecount mod 8 = 0)then
                    datashiftregister   <= data_to_max;
                    if(nibblecount/2 < to_integer(unsigned(numbytes)))then
                        next_data           <= '1';
                    end if;
                end if;
            end if;


            if(nibblecount/2 = to_integer(unsigned(numbytes)) and toggle = '0')then
                spistate <= idle;
            end if;
        when waiting =>
            toggle <= not toggle;
            io_SPI_mosi     <= 'Z';
            io_SPI_D1       <= 'Z';
            io_SPI_D2       <= 'Z';
            io_SPI_D3       <= 'Z';
            if(toggle = '0')then
                o_SPI_clk       <= '0';
                nibblecount     <= nibblecount + 1;
            else
                o_SPI_clk       <= '1';
                if(nibblecount = 3) then
                    spistate        <= reading;
                    nibblecount     <= 0;
                end if;
            end if;
        when reading =>
            haveread <= '0';
            toggle <= not toggle;
            if(toggle = '0')then
                o_SPI_clk       <= '0';
                datareadshiftregister(28)   <= io_SPI_mosi;
                datareadshiftregister(29)   <= io_SPI_D1;
                datareadshiftregister(30)   <= io_SPI_D2;
                datareadshiftregister(31)   <= io_SPI_D3;
                datareadshiftregister(27 downto 0) <= datareadshiftregister(31 downto 4);
                nibblecount     <= nibblecount +1;
                haveread        <= '1';
            else
                o_SPI_clk       <= '1';
            end if;

            if(nibblecount mod 2 = 0 and nibblecount > 0 and haveread = '1')then
                byte_from_max   <= datareadshiftregister(31 downto 24);
                byte_en         <= '1';
            end if;

            if(nibblecount mod 8 = 0 and nibblecount > 0 and haveread = '1')then
                word_from_max   <= datareadshiftregister;
                word_en         <= '1';
            end if;

            if(nibblecount/2 = to_integer(unsigned(numbytes)))then
                spistate    <= idle;
            end if;

        when others =>
            o_SPI_csn        <= '1';
            o_SPI_clk       <= '0';
            io_SPI_mosi     <= 'Z';
            io_SPI_miso     <= 'Z';
            io_SPI_D1       <= 'Z';
            io_SPI_D2       <= 'Z';
            io_SPI_D3       <= 'Z';
            spistate        <= idle;
        end case;
    end if;
    end process;

end architecture;
