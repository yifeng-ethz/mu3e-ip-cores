library ieee;
use ieee.std_logic_1164.all;

entity legacy_firefly_mon_cdc_bridge is
    generic (
        g_FIFO_ADDR_WIDTH : positive := 2
    );
    port (
        i_s_clk              : in  std_logic;
        i_s_reset_n          : in  std_logic;
        o_s_waitrequest      : out std_logic;
        o_s_readdata         : out std_logic_vector(31 downto 0);
        o_s_readdatavalid    : out std_logic;
        o_s_response         : out std_logic_vector(1 downto 0);
        i_s_burstcount       : in  std_logic_vector(0 downto 0);
        i_s_writedata        : in  std_logic_vector(31 downto 0);
        i_s_address          : in  std_logic_vector(7 downto 0);
        i_s_write            : in  std_logic;
        i_s_read             : in  std_logic;
        i_s_byteenable       : in  std_logic_vector(3 downto 0);
        i_s_debugaccess      : in  std_logic;

        i_m_clk              : in  std_logic;
        i_m_reset_n          : in  std_logic;
        i_m_waitrequest      : in  std_logic;
        i_m_readdata         : in  std_logic_vector(31 downto 0);
        i_m_readdatavalid    : in  std_logic;
        i_m_response         : in  std_logic_vector(1 downto 0);
        o_m_burstcount       : out std_logic_vector(0 downto 0);
        o_m_writedata        : out std_logic_vector(31 downto 0);
        o_m_address          : out std_logic_vector(7 downto 0);
        o_m_write            : out std_logic;
        o_m_read             : out std_logic;
        o_m_byteenable       : out std_logic_vector(3 downto 0);
        o_m_debugaccess      : out std_logic
    );
end entity legacy_firefly_mon_cdc_bridge;

architecture rtl of legacy_firefly_mon_cdc_bridge is
    constant CMD_WIDTH_C : positive := 48;
    constant RSP_WIDTH_C : positive := 35;

    constant CMD_DEBUGACCESS_BIT_C : natural := 0;
    constant CMD_BYENABLE_LO_C     : natural := 1;
    constant CMD_BYENABLE_HI_C     : natural := 4;
    constant CMD_READ_BIT_C        : natural := 5;
    constant CMD_WRITE_BIT_C       : natural := 6;
    constant CMD_ADDRESS_LO_C      : natural := 7;
    constant CMD_ADDRESS_HI_C      : natural := 14;
    constant CMD_WRITEDATA_LO_C    : natural := 15;
    constant CMD_WRITEDATA_HI_C    : natural := 46;
    constant CMD_BURSTCOUNT_BIT_C  : natural := 47;

    constant RSP_READDATA_LO_C     : natural := 0;
    constant RSP_READDATA_HI_C     : natural := 31;
    constant RSP_RESPONSE_LO_C     : natural := 32;
    constant RSP_RESPONSE_HI_C     : natural := 33;
    constant RSP_IS_READ_BIT_C     : natural := 34;

    signal fifo_reset_n        : std_logic;
    signal s_reset_n           : std_logic;
    signal m_reset_n           : std_logic;

    signal cmd_wdata           : std_logic_vector(CMD_WIDTH_C - 1 downto 0);
    signal cmd_rdata           : std_logic_vector(CMD_WIDTH_C - 1 downto 0);
    signal cmd_wfull           : std_logic;
    signal cmd_wrreq           : std_logic;
    signal cmd_rempty          : std_logic;
    signal cmd_has_word        : std_logic;
    signal cmd_rdreq           : std_logic;

    signal rsp_wdata           : std_logic_vector(RSP_WIDTH_C - 1 downto 0) := (others => '0');
    signal rsp_rdata           : std_logic_vector(RSP_WIDTH_C - 1 downto 0);
    signal rsp_wfull           : std_logic;
    signal rsp_wrreq           : std_logic := '0';
    signal rsp_rempty          : std_logic;
    signal rsp_has_word        : std_logic;
    signal rsp_rdreq           : std_logic;

    signal s_busy              : std_logic := '0';
    signal s_readdata_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal s_readdatavalid_reg : std_logic := '0';
    signal s_response_reg      : std_logic_vector(1 downto 0) := (others => '0');

    signal m_cmd_burstcount    : std_logic_vector(0 downto 0) := (others => '0');
    signal m_cmd_writedata     : std_logic_vector(31 downto 0) := (others => '0');
    signal m_cmd_address       : std_logic_vector(7 downto 0) := (others => '0');
    signal m_cmd_write         : std_logic := '0';
    signal m_cmd_read          : std_logic := '0';
    signal m_cmd_byteenable    : std_logic_vector(3 downto 0) := (others => '0');
    signal m_cmd_debugaccess   : std_logic := '0';
    signal m_cmd_pending       : std_logic := '0';
    signal m_wait_read_rsp     : std_logic := '0';
    signal m_rsp_pending       : std_logic := '0';
    signal m_rsp_pending_data  : std_logic_vector(RSP_WIDTH_C - 1 downto 0) := (others => '0');
begin
    fifo_reset_n <= i_s_reset_n and i_m_reset_n;

    u_s_reset_sync : entity work.reset_sync
        port map (
            i_reset_n => i_s_reset_n,
            o_reset_n => s_reset_n,
            i_clk     => i_s_clk
        );

    u_m_reset_sync : entity work.reset_sync
        port map (
            i_reset_n => i_m_reset_n,
            o_reset_n => m_reset_n,
            i_clk     => i_m_clk
        );

    cmd_wdata(CMD_BURSTCOUNT_BIT_C)               <= i_s_burstcount(0);
    cmd_wdata(CMD_WRITEDATA_HI_C downto CMD_WRITEDATA_LO_C) <= i_s_writedata;
    cmd_wdata(CMD_ADDRESS_HI_C downto CMD_ADDRESS_LO_C)     <= i_s_address;
    cmd_wdata(CMD_WRITE_BIT_C)                    <= i_s_write;
    cmd_wdata(CMD_READ_BIT_C)                     <= i_s_read;
    cmd_wdata(CMD_BYENABLE_HI_C downto CMD_BYENABLE_LO_C)   <= i_s_byteenable;
    cmd_wdata(CMD_DEBUGACCESS_BIT_C)              <= i_s_debugaccess;

    cmd_wrreq <= '1'
        when (
            s_busy = '0' and
            cmd_wfull = '0' and
            (i_s_read = '1' or i_s_write = '1')
        )
        else '0';

    o_s_waitrequest <= '1' when (s_busy = '1' or cmd_wfull = '1') else '0';
    o_s_readdata <= s_readdata_reg;
    o_s_readdatavalid <= s_readdatavalid_reg;
    o_s_response <= s_response_reg;

    cmd_has_word <= not cmd_rempty;
    rsp_has_word <= not rsp_rempty;
    rsp_rdreq <= rsp_has_word;

    process (i_s_clk, s_reset_n)
    begin
        if s_reset_n /= '1' then
            s_busy <= '0';
            s_readdata_reg <= (others => '0');
            s_readdatavalid_reg <= '0';
            s_response_reg <= (others => '0');
        elsif rising_edge(i_s_clk) then
            s_readdatavalid_reg <= '0';

            if cmd_wrreq = '1' then
                s_busy <= '1';
            end if;

            if rsp_has_word = '1' then
                s_busy <= '0';
                s_readdata_reg <= rsp_rdata(RSP_READDATA_HI_C downto RSP_READDATA_LO_C);
                s_readdatavalid_reg <= rsp_rdata(RSP_IS_READ_BIT_C);
                s_response_reg <= rsp_rdata(RSP_RESPONSE_HI_C downto RSP_RESPONSE_LO_C);
            end if;
        end if;
    end process;

    o_m_burstcount <= m_cmd_burstcount;
    o_m_writedata <= m_cmd_writedata;
    o_m_address <= m_cmd_address;
    o_m_write <= m_cmd_pending and m_cmd_write;
    o_m_read <= m_cmd_pending and m_cmd_read;
    o_m_byteenable <= m_cmd_byteenable;
    o_m_debugaccess <= m_cmd_debugaccess;

    process (i_m_clk, m_reset_n)
    begin
        if m_reset_n /= '1' then
            cmd_rdreq <= '0';
            rsp_wrreq <= '0';
            rsp_wdata <= (others => '0');
            m_cmd_burstcount <= (others => '0');
            m_cmd_writedata <= (others => '0');
            m_cmd_address <= (others => '0');
            m_cmd_write <= '0';
            m_cmd_read <= '0';
            m_cmd_byteenable <= (others => '0');
            m_cmd_debugaccess <= '0';
            m_cmd_pending <= '0';
            m_wait_read_rsp <= '0';
            m_rsp_pending <= '0';
            m_rsp_pending_data <= (others => '0');
        elsif rising_edge(i_m_clk) then
            cmd_rdreq <= '0';
            rsp_wrreq <= '0';

            if m_rsp_pending = '1' and rsp_wfull = '0' then
                rsp_wrreq <= '1';
                rsp_wdata <= m_rsp_pending_data;
                m_rsp_pending <= '0';
            end if;

            if m_cmd_pending = '1' then
                if i_m_waitrequest = '0' then
                    m_cmd_pending <= '0';
                    if m_cmd_read = '1' then
                        m_wait_read_rsp <= '1';
                    else
                        m_rsp_pending <= '1';
                        m_rsp_pending_data <= (others => '0');
                    end if;
                end if;
            elsif m_wait_read_rsp = '1' then
                if i_m_readdatavalid = '1' then
                    m_wait_read_rsp <= '0';
                    m_rsp_pending <= '1';
                    m_rsp_pending_data(RSP_IS_READ_BIT_C) <= '1';
                    m_rsp_pending_data(RSP_RESPONSE_HI_C downto RSP_RESPONSE_LO_C) <= i_m_response;
                    m_rsp_pending_data(RSP_READDATA_HI_C downto RSP_READDATA_LO_C) <= i_m_readdata;
                end if;
            elsif m_rsp_pending = '0' and cmd_has_word = '1' then
                cmd_rdreq <= '1';
                m_cmd_pending <= '1';
                m_cmd_burstcount(0) <= cmd_rdata(CMD_BURSTCOUNT_BIT_C);
                m_cmd_writedata <= cmd_rdata(CMD_WRITEDATA_HI_C downto CMD_WRITEDATA_LO_C);
                m_cmd_address <= cmd_rdata(CMD_ADDRESS_HI_C downto CMD_ADDRESS_LO_C);
                m_cmd_write <= cmd_rdata(CMD_WRITE_BIT_C);
                m_cmd_read <= cmd_rdata(CMD_READ_BIT_C);
                m_cmd_byteenable <= cmd_rdata(CMD_BYENABLE_HI_C downto CMD_BYENABLE_LO_C);
                m_cmd_debugaccess <= cmd_rdata(CMD_DEBUGACCESS_BIT_C);
            end if;
        end if;
    end process;

    u_cmd_fifo : entity work.ip_dcfifo_v2
        generic map (
            g_ADDR_WIDTH    => g_FIFO_ADDR_WIDTH,
            g_DATA_WIDTH    => CMD_WIDTH_C,
            g_SHOWAHEAD     => "ON",
            g_DEVICE_FAMILY => "Arria V"
        )
        port map (
            i_we       => cmd_wrreq,
            i_wdata    => cmd_wdata,
            o_wfull    => cmd_wfull,
            o_wfull_n  => open,
            o_wusedw   => open,
            i_wclk     => i_s_clk,
            i_rack     => cmd_rdreq,
            o_rdata    => cmd_rdata,
            o_rempty   => cmd_rempty,
            o_rempty_n => open,
            o_rusedw   => open,
            i_rclk     => i_m_clk,
            i_reset_n  => fifo_reset_n
        );

    u_rsp_fifo : entity work.ip_dcfifo_v2
        generic map (
            g_ADDR_WIDTH    => g_FIFO_ADDR_WIDTH,
            g_DATA_WIDTH    => RSP_WIDTH_C,
            g_SHOWAHEAD     => "ON",
            g_DEVICE_FAMILY => "Arria V"
        )
        port map (
            i_we       => rsp_wrreq,
            i_wdata    => rsp_wdata,
            o_wfull    => rsp_wfull,
            o_wfull_n  => open,
            o_wusedw   => open,
            i_wclk     => i_m_clk,
            i_rack     => rsp_rdreq,
            o_rdata    => rsp_rdata,
            o_rempty   => rsp_rempty,
            o_rempty_n => open,
            o_rusedw   => open,
            i_rclk     => i_s_clk,
            i_reset_n  => fifo_reset_n
        );
end architecture rtl;
