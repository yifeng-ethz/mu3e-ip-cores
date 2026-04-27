library ieee;
use ieee.std_logic_1164.all;

entity sc_downlink_cdc_bridge is
    generic (
        g_ADDR_WIDTH : positive := 9
    );
    port (
        i_in_clk      : in  std_logic;
        i_in_reset_n  : in  std_logic;
        i_in_data     : in  std_logic_vector(31 downto 0);
        i_in_datak    : in  std_logic_vector(3 downto 0);
        i_out_clk     : in  std_logic;
        i_out_reset_n : in  std_logic;
        i_out_ready   : in  std_logic;
        o_out_data    : out std_logic_vector(31 downto 0);
        o_out_datak   : out std_logic_vector(3 downto 0)
    );
end entity sc_downlink_cdc_bridge;

architecture rtl of sc_downlink_cdc_bridge is
    constant IDLE_DATA_C  : std_logic_vector(31 downto 0) := (others => '0');
    constant IDLE_DATAK_C : std_logic_vector(3 downto 0)  := (others => '0');
    constant SKIP_DATA_C  : std_logic_vector(31 downto 0) := x"000000BC";
    constant SKIP_DATAK_C : std_logic_vector(3 downto 0)  := "0001";

    signal fifo_wdata    : std_logic_vector(35 downto 0);
    signal fifo_rdata    : std_logic_vector(35 downto 0);
    signal fifo_wfull    : std_logic;
    signal fifo_rempty   : std_logic;
    signal fifo_wrreq    : std_logic;
    signal fifo_rdreq    : std_logic;
    signal fifo_reset_n  : std_logic;
    signal in_reset_n    : std_logic;
    signal in_packet     : std_logic := '0';
    signal fifo_has_word : std_logic;
    signal load_out_word : std_logic;
    signal out_reset_n   : std_logic;
    signal out_valid     : std_logic := '0';
    signal out_data      : std_logic_vector(31 downto 0) := (others => '0');
    signal out_datak     : std_logic_vector(3 downto 0)  := (others => '0');

    function is_idle_word(
        data_in  : std_logic_vector(31 downto 0);
        datak_in : std_logic_vector(3 downto 0)
    ) return boolean is
    begin
        return data_in = IDLE_DATA_C and datak_in = IDLE_DATAK_C;
    end function is_idle_word;

    function is_skip_word(
        data_in  : std_logic_vector(31 downto 0);
        datak_in : std_logic_vector(3 downto 0)
    ) return boolean is
    begin
        return data_in = SKIP_DATA_C and datak_in = SKIP_DATAK_C;
    end function is_skip_word;

    function is_sc_preamble_word(
        data_in  : std_logic_vector(31 downto 0);
        datak_in : std_logic_vector(3 downto 0)
    ) return boolean is
    begin
        return data_in(31 downto 26) = "000111" and
            data_in(7 downto 0) = x"BC" and
            datak_in = "0001";
    end function is_sc_preamble_word;

    function is_sc_trailer_word(
        data_in  : std_logic_vector(31 downto 0);
        datak_in : std_logic_vector(3 downto 0)
    ) return boolean is
    begin
        return data_in(7 downto 0) = x"9C" and
            datak_in = "0001";
    end function is_sc_trailer_word;
begin
    fifo_reset_n <= i_in_reset_n and i_out_reset_n;

    u_in_reset_sync : entity work.reset_sync
        port map (
            i_reset_n => i_in_reset_n,
            o_reset_n => in_reset_n,
            i_clk     => i_in_clk
        );

    u_out_reset_sync : entity work.reset_sync
        port map (
            i_reset_n => i_out_reset_n,
            o_reset_n => out_reset_n,
            i_clk     => i_out_clk
        );

    fifo_wdata(35 downto 4) <= i_in_data;
    fifo_wdata(3 downto 0)  <= i_in_datak;

    -- The 156.25 MHz firefly receive side carries mostly idle / skip fill
    -- words.  Drop fill outside packets, but keep every non-skip word between
    -- the SC preamble and trailer; zero is a legal address/data/length word.
    fifo_wrreq <= '1'
        when (
            in_reset_n = '1' and
            fifo_wfull = '0' and
            not is_skip_word(i_in_data, i_in_datak) and
            (
                in_packet = '1' or
                is_sc_preamble_word(i_in_data, i_in_datak)
            ) and
            not (
                in_packet = '0' and
                is_idle_word(i_in_data, i_in_datak)
            )
        )
        else '0';

    process (i_in_clk)
    begin
        if rising_edge(i_in_clk) then
            if in_reset_n /= '1' then
                in_packet <= '0';
            elsif fifo_wfull = '0' then
                if is_sc_preamble_word(i_in_data, i_in_datak) then
                    in_packet <= '1';
                elsif in_packet = '1' and is_sc_trailer_word(i_in_data, i_in_datak) then
                    in_packet <= '0';
                end if;
            end if;
        end if;
    end process;

    fifo_has_word <= not fifo_rempty;
    load_out_word <= '1'
        when (
            out_reset_n = '1' and
            fifo_has_word = '1' and
            (out_valid = '0' or i_out_ready = '1')
        )
        else '0';
    fifo_rdreq <= load_out_word;

    o_out_data <= out_data when (out_valid = '1') else SKIP_DATA_C;
    o_out_datak <= out_datak when (out_valid = '1') else SKIP_DATAK_C;

    -- Register the read-side word before presenting it to sc_hub so the
    -- 125 MHz timing only sees local flops, not live dcfifo RAM output.
    process (i_out_clk)
    begin
        if rising_edge(i_out_clk) then
            if out_reset_n /= '1' then
                out_valid <= '0';
                out_data  <= SKIP_DATA_C;
                out_datak <= SKIP_DATAK_C;
            elsif load_out_word = '1' then
                out_valid <= '1';
                out_data  <= fifo_rdata(35 downto 4);
                out_datak <= fifo_rdata(3 downto 0);
            elsif i_out_ready = '1' then
                out_valid <= '0';
                out_data  <= SKIP_DATA_C;
                out_datak <= SKIP_DATAK_C;
            end if;
        end if;
    end process;

    u_fifo : entity work.ip_dcfifo_v2
        generic map (
            g_ADDR_WIDTH   => g_ADDR_WIDTH,
            g_DATA_WIDTH   => fifo_wdata'length,
            g_SHOWAHEAD    => "ON",
            g_DEVICE_FAMILY => "Arria V"
        )
        port map (
            i_we       => fifo_wrreq,
            i_wdata    => fifo_wdata,
            o_wfull    => fifo_wfull,
            o_wfull_n  => open,
            o_wusedw   => open,
            i_wclk     => i_in_clk,
            i_rack     => fifo_rdreq,
            o_rdata    => fifo_rdata,
            o_rempty   => fifo_rempty,
            o_rempty_n => open,
            o_rusedw   => open,
            i_rclk     => i_out_clk,
            i_reset_n  => fifo_reset_n
        );
end architecture rtl;
