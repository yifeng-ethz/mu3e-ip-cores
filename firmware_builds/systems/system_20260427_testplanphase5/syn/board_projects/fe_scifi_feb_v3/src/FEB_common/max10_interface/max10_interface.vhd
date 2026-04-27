--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

use work.mudaq.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity max10_interface is
port (
    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic;
    i_clk_156           : in    std_logic;

    o_SPI_csn           : out   std_logic;
    o_SPI_clk           : out   std_logic;
    io_SPI_mosi         : inout std_logic;
    io_SPI_miso         : inout std_logic;
    io_SPI_D1           : inout std_logic;
    io_SPI_D2           : inout std_logic;
    io_SPI_D3           : inout std_logic;

    adc_reg             : out   slv32_array_t( 4 downto 0);
    o_max10_version     : out   std_logic_vector(31 downto 0);
    o_max10_status      : out   std_logic_vector(31 downto 0);
    o_programming_status: out   std_logic_vector(31 downto 0);

    programming_ctrl    : in    std_logic_vector(31 downto 0);
    programming_data    : in    std_logic_vector(31 downto 0);
    programming_data_ena: in    std_logic;
    programming_addr    : in    std_logic_vector(31 downto 0);
    programming_addr_ena: in    std_logic--;
);
end entity;

architecture rtl of max10_interface is

    signal max_spi_strobe           : std_logic;
    signal max_spi_addr             : std_logic_vector(6 downto 0);
    signal max_spi_rw               : std_logic;
    signal max_spi_data_to_max      : std_logic_vector(31 downto 0);
    signal max_spi_numbytes         : std_logic_vector(8 downto 0);
    signal max_spi_next_data        : std_logic;
    signal max_spi_word_from_max    : std_logic_vector(31 downto 0);
    signal max_spi_word_en          : std_logic;
    signal max_spi_byte_from_max    : std_logic_vector(7 downto 0);
    signal max_spi_byte_en          : std_logic;
    signal max_spi_busy             : std_logic;

    signal max_spi_counter          : integer;
    signal max10_spiflash_cmdaddr   : reg32;
    signal max10_status             : std_logic_vector(31 downto 0);
    signal max10_version            : std_logic_vector(31 downto 0);
    signal programming_status       : std_logic_vector(31 downto 0);

    type max_spi_state_t            is (idle, programming, fifocopy, control, controlwait, programmingaddrwait, programmingaddr,
                                    flashwait, busyread, programmingend, maxversion, statuswait, maxstatus, adcwait, maxadc, endwait);
    signal max_spi_state            : max_spi_state_t;
    signal program_req              : std_logic;
    signal flash_busy               : std_logic;
    signal busy_last                : std_logic;

    signal read_programming_fifo    : std_logic;
    signal programming_data_from_fifo   : reg32;
    signal programming_addr_ena_reg : std_logic;
    signal wordcounter              : integer;

begin

    e_max10_spi : entity work.max10_spi
    port map (
        -- Max10 SPI
        o_SPI_csn           => o_SPI_csn,
        o_SPI_clk           => o_SPI_clk,
        io_SPI_mosi         => io_SPI_mosi,
        io_SPI_miso         => io_SPI_miso,
        io_SPI_D1           => io_SPI_D1,
        io_SPI_D2           => io_SPI_D2,
        io_SPI_D3           => io_SPI_D3,

        -- Interface to Arria
        clk50               => i_clk,
        reset_n             => i_reset_n,
        strobe              => max_spi_strobe,
        addr                => max_spi_addr,
        rw                  => max_spi_rw,
        data_to_max         => max_spi_data_to_max,
        numbytes            => max_spi_numbytes,
        next_data           => max_spi_next_data,
        word_from_max       => max_spi_word_from_max,
        word_en             => max_spi_word_en,
        byte_from_max       => max_spi_byte_from_max,
        byte_en             => max_spi_byte_en,
        busy                => max_spi_busy
    );

    program_req <= programming_ctrl(0);

    process(i_clk, i_reset_n)
    begin
    if(i_reset_n = '0')then
        max_spi_strobe          <= '0';
        max_spi_counter         <= 0;
        max_spi_state           <= idle;
        max_spi_numbytes        <= "000000000";
        max_spi_rw              <= '0';
        read_programming_fifo   <= '0';
        busy_last               <= '0';
        programming_status(0)   <= '0';
        programming_status(1)   <= '0';
        flash_busy              <= '0';
        programming_addr_ena_reg<= '0';

    elsif rising_edge(i_clk) then
        max_spi_counter <= max_spi_counter + 1;
        max_spi_strobe <= '0';

        -- Note that this comes from a different clock domain, we register to avoid
        -- messing up the SM (as observed with signal tap)
        programming_addr_ena_reg <= programming_addr_ena;

        programming_status(0)           <= '0';
        programming_status(31 downto 4) <= (others => '0');

        read_programming_fifo   <= '0';
        busy_last               <= max_spi_busy;

        case max_spi_state is
        when idle =>
                programming_status(4) <= '1';
                max_spi_rw <= '0';
            if(program_req = '1') then
                max_spi_state <= programming;
            elsif(max_spi_counter > 5000000) then
                max_spi_state <= maxversion;
                max_spi_counter <= 0;
            end if;
                programming_status(0) <= '0';
                programming_status(1) <= '0';

        when programming =>
            programming_status(5) <= '1';
            -- Idea for programming:
            -- - go to programming state by setting programming_ctrl(0) = 1
            -- - Fill at least 256 byte into the programming FIFO
            -- - Set the address - this will copy the FIFO to the MAX, then trigger
            --   flash programming
            -- - Status is polled and reflected in MAX10 status until busy goes low
            -- - Rinse and repeat

            programming_status(0) <= '1';
            if(program_req = '0') then
                max_spi_state <= idle;
            end if;

            if(programming_addr_ena_reg = '1') then
                max_spi_state <= fifocopy;
                programming_status(1) <= '1';
            end if;

        when fifocopy =>
            programming_status(6) <= '1';
            max_spi_addr    <= FEBSPI_ADDR_PROGRAMMING_WFIFO;
            max_spi_numbytes <= "100000000";
            max_spi_strobe   <= '1';
            max_spi_rw       <= '1';
            max_spi_data_to_max     <= programming_data_from_fifo;
            read_programming_fifo   <= max_spi_next_data;
            max_spi_state           <= programmingaddrwait;

        when programmingaddrwait =>
            programming_status(7)   <= '1';
            max_spi_data_to_max     <= programming_data_from_fifo;
            read_programming_fifo   <= max_spi_next_data;
            if(max_spi_busy = '0' and busy_last = '1') then
                max_spi_rw       <= '0';
                max_spi_strobe   <= '0';
                max_spi_state    <= programmingaddr;
                read_programming_fifo   <= '0';
            end if;

        when programmingaddr =>
            programming_status(8) <= '1';
            max_spi_addr     <= FEBSPI_ADDR_PROGRAMMING_ADDR;
            max_spi_numbytes <= "000000100";
            max_spi_strobe   <= '1';
            max_spi_rw       <= '1';
            max_spi_data_to_max     <= programming_addr;
            max_spi_state           <= controlwait;

        when controlwait =>
            programming_status(9) <= '1';
            if(max_spi_busy = '0' and busy_last = '1') then
                max_spi_rw        <= '0';
                max_spi_strobe    <= '0';
                max_spi_state     <= control;
            end if;

        when control =>
            programming_status(10) <= '1';
            max_spi_addr     <= FEBSPI_ADDR_PROGRAMMING_CTRL;
            max_spi_numbytes <= "000000100";
            max_spi_strobe   <= '1';
            max_spi_rw       <= '1';
            max_spi_data_to_max     <= X"00000001";
            max_spi_state    <= flashwait;
            flash_busy       <= '1';

        when flashwait =>
            programming_status(11) <= '1';
            if(max_spi_busy = '0' and busy_last = '1') then
                max_spi_rw         <= '0';
                max_spi_strobe     <= '0';
                if(flash_busy = '1') then
                    max_spi_state  <= busyread;
                else
                    max_spi_state  <= programmingend;
                end if;
            end if;

        when busyread =>
            programming_status(12) <= '1';
            max_spi_addr     <= FEBSPI_ADDR_PROGRAMMING_STATUS;
            max_spi_numbytes <= "000000100";
            max_spi_strobe   <= '1';
            if(max_spi_word_en = '1') then
                flash_busy       <= max_spi_word_from_max(0);
                max_spi_strobe   <= '0';
                max_spi_state    <= flashwait;
            end if;

        when programmingend =>
            programming_status(13) <= '1';
            max_spi_addr        <= FEBSPI_ADDR_PROGRAMMING_CTRL;
            max_spi_numbytes    <= "000000100";
            max_spi_strobe      <= '1';
            max_spi_rw          <= '1';
            max_spi_data_to_max <= (others => '0');
            if(max_spi_busy = '0' and busy_last = '1') then
                max_spi_rw              <= '0';
                max_spi_strobe          <= '0';
                max_spi_state           <= programming;
                programming_status(1)   <= '0';
            end if;

        when maxversion =>
            programming_status(14)  <= '1';
            max_spi_addr            <= FEBSPI_ADDR_GITHASH;
            max_spi_numbytes        <= "000000100";
            max_spi_strobe          <= '1';
            if(max_spi_word_en = '1') then
                max10_version       <= max_spi_word_from_max;
                max_spi_strobe      <= '0';
                max_spi_state       <= statuswait;
            end if;

        when statuswait =>
            programming_status(15) <= '1';
            if(max_spi_busy = '0')then
                max_spi_state <= maxstatus;
            end if;

        when maxstatus =>
            programming_status(16) <= '1';
            max_spi_addr        <= FEBSPI_ADDR_STATUS;
            max_spi_numbytes    <= "000000100";
            max_spi_strobe      <= '1';
            if(max_spi_word_en = '1') then
                max10_status    <= max_spi_word_from_max;
                max_spi_strobe  <= '0';
                max_spi_state   <= adcwait;
                wordcounter     <= 0;
            end if;

        when adcwait =>
            programming_status(17) <= '1';
            if(max_spi_busy = '0')then
                max_spi_state      <= maxadc;
            end if;

        when maxadc =>
            programming_status(18)  <= '1';
            max_spi_addr            <= FEBSPI_ADDR_ADCDATA;
            max_spi_numbytes        <= "000010100";
            max_spi_strobe          <= '1';
            if(max_spi_word_en = '1') then
                wordcounter         <= wordcounter + 1;
                if(wordcounter = 0) then
                    adc_reg(0)      <= max_spi_word_from_max;
                elsif(wordcounter = 1) then
                    adc_reg(1)      <= max_spi_word_from_max;
                elsif(wordcounter = 2) then
                    adc_reg(2)      <= max_spi_word_from_max;
                    elsif(wordcounter = 3) then
                    adc_reg(3)      <= max_spi_word_from_max;
                    elsif(wordcounter = 4) then
                    adc_reg(4)      <= max_spi_word_from_max;
                    max_spi_strobe  <= '0';
                    max_spi_state   <= endwait;
                end if;
            end if;

        when endwait =>
            programming_status(19) <= '1';
            if(max_spi_busy = '0')then
                max_spi_state      <= idle;
            end if;

        when others =>
            programming_status(20) <= '1';
            max_spi_state <= idle;
            max_spi_strobe <= '0';

        end case;
        --
    end if;
    end process;

    scfifo_component : altera_mf.altera_mf_components.dcfifo
    GENERIC MAP (
        add_ram_output_register => "ON",
        intended_device_family => "Arria V",
        lpm_numwords => 512,
        lpm_showahead => "ON",
        lpm_type => "dcfifo",
        lpm_width => 32,
        lpm_widthu => 9,
        overflow_checking => "ON",
        underflow_checking => "ON",
        use_eab => "ON"
    )
    PORT MAP (
        wrclk => i_clk_156,
        rdclk => i_clk,
        data => programming_data,
        rdreq => read_programming_fifo,
        aclr => programming_ctrl(1),
        wrreq => programming_data_ena,
        rdempty => programming_status(2),
        rdfull  => programming_status(3),
        q => programming_data_from_fifo
    );

    process(i_clk_156)
    begin
    if rising_edge(i_clk_156) then
        -- register once in clk156 domain, set false path between max10_status and o_max10_status
        -- should be fine for these signals .. i think (M.Mueller)
        o_max10_status          <= max10_status;
        o_max10_version         <= max10_version;
        o_programming_status    <= programming_status;
    end if;
    end process;

end architecture;
