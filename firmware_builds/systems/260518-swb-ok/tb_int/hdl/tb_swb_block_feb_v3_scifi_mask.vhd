library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.env.finish;

use work.a10_pcie_registers.all;
use work.util_slv.all;

entity tb_swb_block_feb_v3_scifi_mask is
end entity;

architecture sim of tb_swb_block_feb_v3_scifi_mask is
    constant CLK_PERIOD                 : time := 8 ns;
    constant NLINKS                     : natural := 8;
    constant LINK_UNDER_TEST            : natural := 2;
    constant SUBHEADERS_PER_FRAME       : natural := 128;
    constant HITS_PER_FRAME             : natural := 1;
    constant FEB_V3_SOP                 : std_logic_vector(31 downto 0) := x"A50000BC";

    signal clk                          : std_logic := '0';
    signal reset_n                      : std_logic := '0';
    signal done                         : boolean := false;
    signal feb_rx                       : work.mu3e.link32_array_t(NLINKS-1 downto 0) := (others => work.mu3e.LINK32_IDLE);
    signal feb_tx                       : work.mu3e.link32_array_t(NLINKS-1 downto 0);
    signal writeregs                    : slv32_array_t(63 downto 0) := (others => (others => '0'));
    signal regwritten                   : std_logic_vector(63 downto 0) := (others => '0');
    signal readregs                     : slv32_array_t(63 downto 0);
    signal resets_n                     : std_logic_vector(31 downto 0) := (others => '0');
    signal wmem_rdata                   : std_logic_vector(31 downto 0) := (others => '0');
    signal wmem_addr                    : std_logic_vector(15 downto 0);
    signal rmem_wdata                   : std_logic_vector(31 downto 0);
    signal rmem_addr                    : std_logic_vector(15 downto 0);
    signal rmem_we                      : std_logic;
    signal dma_wren                     : std_logic;
    signal endofevent                   : std_logic;
    signal dma_data                     : std_logic_vector(255 downto 0);
    signal opq_data                     : std_logic_vector(31 downto 0);
    signal opq_datak                    : std_logic_vector(3 downto 0);
    signal opq_valid                    : std_logic;
    signal farm_tx                      : work.mu3e.link32_array_t(0 downto 0);
    signal opq_valid_words              : natural := 0;

    procedure drive_word(
        signal link_i : out work.mu3e.link32_t;
        signal clk_i  : in  std_logic;
        constant word : in  std_logic_vector(31 downto 0);
        constant k    : in  std_logic_vector(3 downto 0)
    ) is
    begin
        wait until rising_edge(clk_i);
        link_i <= work.mu3e.to_link(word, k);
        wait until rising_edge(clk_i);
        link_i <= work.mu3e.LINK32_IDLE;
    end procedure;

    procedure drive_feb_v3_frame(
        signal link_i      : out work.mu3e.link32_t;
        signal clk_i       : in  std_logic;
        constant frame_idx : in  natural
    ) is
        variable subh_ts    : unsigned(7 downto 0);
        variable frame_cnt  : unsigned(15 downto 0);
        variable payload    : std_logic_vector(31 downto 0);
    begin
        frame_cnt := to_unsigned(frame_idx mod 65536, 16);

        drive_word(link_i, clk_i, FEB_V3_SOP, "0001");
        drive_word(link_i, clk_i, x"2026" & std_logic_vector(frame_cnt), "0000");
        drive_word(link_i, clk_i, x"0000" & std_logic_vector(frame_cnt), "0000");
        drive_word(link_i, clk_i, '0' & std_logic_vector(to_unsigned(SUBHEADERS_PER_FRAME, 15)) & std_logic_vector(to_unsigned(HITS_PER_FRAME, 16)), "0000");
        drive_word(link_i, clk_i, x"C001" & std_logic_vector(frame_cnt), "0000");

        for shd in 0 to SUBHEADERS_PER_FRAME - 1 loop
            subh_ts := to_unsigned(shd, 8);
            if shd = (frame_idx mod SUBHEADERS_PER_FRAME) then
                drive_word(link_i, clk_i, std_logic_vector(subh_ts) & x"00" & x"01" & work.util.K23_7, "0001");
                payload := std_logic_vector(to_unsigned(frame_idx mod 16, 4)) & x"0" & std_logic_vector(to_unsigned(frame_idx, 24));
                drive_word(link_i, clk_i, payload, "0000");
            else
                drive_word(link_i, clk_i, std_logic_vector(subh_ts) & x"00" & x"00" & work.util.K23_7, "0001");
            end if;
        end loop;

        drive_word(link_i, clk_i, x"000000" & work.util.K28_4, "0001");
    end procedure;

    procedure configure_scifi_opq(
        signal regs         : out slv32_array_t(63 downto 0);
        constant scifi_mask : in  std_logic_vector(31 downto 0);
        constant generic_mask : in std_logic_vector(31 downto 0)
    ) is
        variable next_regs : slv32_array_t(63 downto 0) := (others => (others => '0'));
    begin
        next_regs(SWB_LINK_MASK_SCIFI_REGISTER_W) := scifi_mask;
        next_regs(SWB_GENERIC_MASK_REGISTER_W) := generic_mask;
        next_regs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_SCIFI) := '1';
        next_regs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER) := '1';
        next_regs(DMA_REGISTER_W)(DMA_BIT_ENABLE) := '1';
        regs <= next_regs;
    end procedure;

    procedure configure_generic_opq(
        signal regs         : out slv32_array_t(63 downto 0);
        constant generic_mask : in std_logic_vector(31 downto 0)
    ) is
        variable next_regs : slv32_array_t(63 downto 0) := (others => (others => '0'));
    begin
        next_regs(SWB_GENERIC_MASK_REGISTER_W) := generic_mask;
        next_regs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_GENERIC) := '1';
        next_regs(SWB_READOUT_STATE_REGISTER_W)(USE_BIT_MERGER) := '1';
        next_regs(DMA_REGISTER_W)(DMA_BIT_ENABLE) := '1';
        regs <= next_regs;
    end procedure;

begin
    clk <= not clk after CLK_PERIOD / 2 when not done else clk;

    dut : entity work.swb_block
    generic map (
        g_NLINKS_FEB_TOTL       => NLINKS,
        g_NLINKS_DATA_GENERIC   => 0,
        g_NLINKS_FARM_TOTL      => 1,
        g_NLINKS_DATA_PIXEL_US  => 5,
        g_NLINKS_DATA_PIXEL_DS  => 5,
        g_SC_SEC_SKIP_INIT      => '1'
    )
    port map (
        i_feb_rx         => feb_rx,
        o_feb_tx         => feb_tx,
        i_writeregs      => writeregs,
        i_regwritten     => regwritten,
        o_readregs       => readregs,
        i_resets_n       => resets_n,
        i_wmem_rdata     => wmem_rdata,
        o_wmem_addr      => wmem_addr,
        o_rmem_wdata     => rmem_wdata,
        o_rmem_addr      => rmem_addr,
        o_rmem_we        => rmem_we,
        i_dmamemhalffull => '0',
        o_dma_wren       => dma_wren,
        o_endofevent     => endofevent,
        o_dma_data       => dma_data,
        o_opq_data       => opq_data,
        o_opq_datak      => opq_datak,
        o_opq_valid      => opq_valid,
        o_farm_tx        => farm_tx,
        i_reset_n        => reset_n,
        i_clk            => clk
    );

    monitor : process
    begin
        wait until rising_edge(clk);
        if reset_n = '1' and opq_valid = '1' then
            opq_valid_words <= opq_valid_words + 1;
        end if;
    end process;

    stimulus : process
        variable before_words : natural;
        variable after_words  : natural;
    begin
        resets_n <= (others => '0');
        reset_n <= '0';
        feb_rx <= (others => work.mu3e.LINK32_IDLE);
        for i in 0 to 8 loop
            wait until rising_edge(clk);
        end loop;
        reset_n <= '1';
        resets_n <= (others => '1');
        for i in 0 to 8 loop
            wait until rising_edge(clk);
        end loop;

        configure_scifi_opq(writeregs, x"00000004", x"00000000");
        for i in 0 to 8 loop
            wait until rising_edge(clk);
        end loop;
        before_words := opq_valid_words;
        drive_feb_v3_frame(feb_rx(LINK_UNDER_TEST), clk, 0);
        for i in 0 to 32 loop
            wait until rising_edge(clk);
        end loop;
        after_words := opq_valid_words;
        report "[SWB_SCIFI_MASK_REPLAY] scifi_mask=0x4 generic_mask=0x0 before="
            & integer'image(before_words) & " after=" & integer'image(after_words);
        assert after_words > before_words
            report "FEB v3 frame on logical link 2 did not pass the SciFi-selected OPQ mask"
            severity failure;

        configure_scifi_opq(writeregs, x"00000000", x"00000004");
        for i in 0 to 8 loop
            wait until rising_edge(clk);
        end loop;
        before_words := opq_valid_words;
        drive_feb_v3_frame(feb_rx(LINK_UNDER_TEST), clk, 1);
        for i in 0 to 32 loop
            wait until rising_edge(clk);
        end loop;
        after_words := opq_valid_words;
        report "[SWB_SCIFI_MASK_REPLAY] scifi_mask=0x0 generic_mask=0x4 before="
            & integer'image(before_words) & " after=" & integer'image(after_words);
        assert after_words = before_words
            report "SciFi readout incorrectly used SWB_GENERIC_MASK instead of SWB_LINK_MASK_SCIFI"
            severity failure;

        configure_generic_opq(writeregs, x"00000004");
        for i in 0 to 8 loop
            wait until rising_edge(clk);
        end loop;
        before_words := opq_valid_words;
        drive_feb_v3_frame(feb_rx(LINK_UNDER_TEST), clk, 2);
        for i in 0 to 32 loop
            wait until rising_edge(clk);
        end loop;
        after_words := opq_valid_words;
        report "[SWB_SCIFI_MASK_REPLAY] generic_mode generic_mask=0x4 before="
            & integer'image(before_words) & " after=" & integer'image(after_words);
        assert after_words > before_words
            report "Generic readout no longer uses SWB_GENERIC_MASK"
            severity failure;

        report "*** TEST PASSED ***";
        done <= true;
        finish;
        wait;
    end process;
end architecture;
