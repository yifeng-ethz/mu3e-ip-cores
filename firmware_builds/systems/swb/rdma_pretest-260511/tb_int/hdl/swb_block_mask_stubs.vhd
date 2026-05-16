library ieee;
use ieee.std_logic_1164.all;

entity run_control is
generic (
    g_LINKS : positive := 4
);
port (
    i_reset_ack_seen_n      : in  std_logic;
    i_reset_run_end_n       : in  std_logic;
    i_buffers_empty         : in  std_logic_vector(31 downto 0);
    i_aligned               : in  std_logic_vector(31 downto 0);
    i_data                  : in  work.mu3e.link32_array_t(g_LINKS-1 downto 0);
    i_link_enable           : in  std_logic_vector(31 downto 0);
    i_addr                  : in  std_logic_vector(31 downto 0);
    i_run_number            : in  std_logic_vector(23 downto 0);
    o_run_number            : out std_logic_vector(31 downto 0);
    o_runNr_ack             : out std_logic_vector(31 downto 0);
    o_run_stop_ack          : out std_logic_vector(31 downto 0);
    o_buffers_empty         : out std_logic_vector(31 downto 0);
    o_feb_merger_timeout    : out std_logic_vector(31 downto 0);
    o_time_counter          : out std_logic_vector(63 downto 0);
    i_reset_n               : in  std_logic;
    i_clk                   : in  std_logic
);
end entity;

architecture stub of run_control is
begin
    o_run_number <= (others => '0');
    o_runNr_ack <= (others => '0');
    o_run_stop_ack <= (others => '0');
    o_buffers_empty <= i_buffers_empty;
    o_feb_merger_timeout <= (others => '0');
    o_time_counter <= (others => '0');
end architecture;

library ieee;
use ieee.std_logic_1164.all;

entity swb_sc_main is
generic (
    NLINKS : positive := 4
);
port (
    i_length_we     : in    std_logic;
    i_length        : in    std_logic_vector(15 downto 0);
    i_mem_data      : in    std_logic_vector(31 downto 0);
    o_mem_addr      : out   std_logic_vector(15 downto 0);
    o_mem_data      : out   work.mu3e.link32_array_t(NLINKS-1 downto 0);
    o_injection     : out   work.mu3e.link32_array_t(3 downto 0);
    o_done          : out   std_logic;
    o_state         : out   std_logic_vector(27 downto 0);
    i_reset_n       : in    std_logic;
    i_clk           : in    std_logic
);
end entity;

architecture stub of swb_sc_main is
begin
    o_mem_addr <= (others => '0');
    o_mem_data <= (others => work.mu3e.LINK32_IDLE);
    o_injection <= (others => work.mu3e.LINK32_IDLE);
    o_done <= '1';
    o_state <= (others => '0');
end architecture;

library ieee;
use ieee.std_logic_1164.all;

entity swb_sc_secondary is
generic (
    NLINKS      : positive := 4;
    skip_init   : std_logic := '0'
);
port (
    i_link_enable               : in    std_logic_vector(NLINKS-1 downto 0);
    i_link_data                 : in    work.mu3e.link32_array_t(NLINKS-1 downto 0);
    o_mem_addr                  : out   std_logic_vector(15 downto 0);
    o_mem_addr_finished         : out   std_logic_vector(15 downto 0);
    o_mem_data                  : out   std_logic_vector(31 downto 0);
    o_mem_we                    : out   std_logic;
    o_state                     : out   std_logic_vector(3 downto 0);
    i_reset_n                   : in    std_logic;
    i_clk                       : in    std_logic
);
end entity;

architecture stub of swb_sc_secondary is
begin
    o_mem_addr <= (others => '0');
    o_mem_addr_finished <= (others => '0');
    o_mem_data <= (others => '0');
    o_mem_we <= '0';
    o_state <= (others => '0');
end architecture;

library ieee;
use ieee.std_logic_1164.all;

entity qc_histos is
port (
    i_data                  : in    work.mu3e.link32_t;
    i_chip_sel              : in    integer range 0 to 128 := 0;
    i_raddr                 : in    std_logic_vector(31 downto 0);
    o_rdata                 : out   std_logic_vector(31 downto 0);
    i_zeromem               : in    std_logic;
    i_ena                   : in    std_logic;
    i_reset_n               : in    std_logic;
    i_clk                   : in    std_logic
);
end entity;

architecture stub of qc_histos is
begin
    o_rdata <= (others => '0');
end architecture;

library ieee;
use ieee.std_logic_1164.all;

entity data_generator_a10 is
generic (
    fpga_id: std_logic_vector(15 downto 0) := x"FFFF";
    max_row: std_logic_vector(7 downto 0) := (others => '0');
    max_col: std_logic_vector(7 downto 0) := (others => '0');
    test_error: boolean := false;
    is_farm: boolean := false;
    wtot: std_logic := '0';
    go_to_sh : positive := 2;
    go_to_trailer : positive := 3;
    wchip: std_logic := '0';
    DATA_TYPE : std_logic_vector(5 downto 0) := work.mudaq.MUPIX_HEADER_ID
);
port (
    i_enable            : in  std_logic;
    i_seed              : in  std_logic_vector(15 downto 0);
    o_data              : out work.mu3e.link32_t;
    i_slow_down         : in  std_logic_vector(31 downto 0);
    o_state             : out std_logic_vector(3 downto 0);
    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic
);
end entity;

architecture stub of data_generator_a10 is
begin
    o_data <= work.mu3e.LINK32_IDLE;
    o_state <= (others => '0');
end architecture;

library ieee;
use ieee.std_logic_1164.all;

entity ingress_egress_adaptor is
port (
    enable              : in std_logic;
    rx_ingress          : in work.mu3e.link32_array_t(3 downto 0);
    rx_egress           : out work.mu3e.link32_array_t(3 downto 0);
    opq_egress_ready    : in std_logic;
    opq_egress_data     : out std_logic_vector(31 downto 0);
    opq_egress_datak    : out std_logic_vector(3 downto 0);
    opq_egress_valid    : out std_logic;
    opq_egress_sop      : out std_logic;
    opq_egress_eop      : out std_logic;
    reset_n             : in std_logic;
    clk                 : in std_logic
);
end entity;

architecture stub of ingress_egress_adaptor is
    signal selected : work.mu3e.link32_t := work.mu3e.LINK32_IDLE;
begin
    process(all)
        variable selected_v : work.mu3e.link32_t;
    begin
        selected_v := work.mu3e.LINK32_IDLE;
        for lane in 0 to 3 loop
            if selected_v.idle = '1' and rx_ingress(lane).idle = '0' then
                selected_v := rx_ingress(lane);
            end if;
        end loop;
        selected <= selected_v;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset_n /= '1' or enable /= '1' or opq_egress_ready /= '1' then
                opq_egress_data <= (others => '0');
                opq_egress_datak <= (others => '0');
                opq_egress_valid <= '0';
                opq_egress_sop <= '0';
                opq_egress_eop <= '0';
                rx_egress <= (others => work.mu3e.LINK32_IDLE);
            else
                opq_egress_data <= selected.data;
                opq_egress_datak <= selected.datak;
                opq_egress_valid <= not selected.idle;
                opq_egress_sop <= selected.sop and not selected.idle;
                opq_egress_eop <= selected.eop and not selected.idle;
                rx_egress <= (others => work.mu3e.LINK32_IDLE);
                rx_egress(0) <= selected;
            end if;
        end if;
    end process;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity swb_opq_dma_pipeline is
port (
    i_clk                  : in  std_logic;
    i_reset_n              : in  std_logic;
    i_dma_enable           : in  std_logic;
    i_dma_halffull         : in  std_logic;
    i_opq_data             : in  std_logic_vector(31 downto 0);
    i_opq_datak            : in  std_logic_vector(3 downto 0);
    i_opq_valid            : in  std_logic;
    i_opq_sop              : in  std_logic;
    i_opq_eop              : in  std_logic;
    o_opq_ready            : out std_logic;
    o_opq_egress_data      : out std_logic_vector(35 downto 0);
    o_opq_egress_valid     : out std_logic;
    o_opq_egress_sop       : out std_logic;
    o_opq_egress_eop       : out std_logic;
    o_dma_data             : out std_logic_vector(255 downto 0);
    o_dma_wen              : out std_logic;
    o_end_of_event         : out std_logic;
    o_input_word_cnt       : out std_logic_vector(31 downto 0);
    o_output_word_cnt      : out std_logic_vector(31 downto 0);
    o_event_cnt            : out std_logic_vector(31 downto 0);
    o_halt_cnt             : out std_logic_vector(31 downto 0)
);
end entity;

architecture stub of swb_opq_dma_pipeline is
    signal input_word_cnt : unsigned(31 downto 0) := (others => '0');
    signal event_cnt : unsigned(31 downto 0) := (others => '0');
    signal accept_valid : std_logic;
begin
    o_opq_ready <= i_dma_enable and not i_dma_halffull;
    accept_valid <= i_dma_enable and not i_dma_halffull and i_opq_valid;
    o_input_word_cnt <= std_logic_vector(input_word_cnt);
    o_output_word_cnt <= std_logic_vector(input_word_cnt);
    o_event_cnt <= std_logic_vector(event_cnt);
    o_halt_cnt <= (others => '0');

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_reset_n /= '1' then
                input_word_cnt <= (others => '0');
                event_cnt <= (others => '0');
                o_opq_egress_data <= (others => '0');
                o_opq_egress_valid <= '0';
                o_opq_egress_sop <= '0';
                o_opq_egress_eop <= '0';
                o_dma_data <= (others => '0');
                o_dma_wen <= '0';
                o_end_of_event <= '0';
            else
                o_opq_egress_data <= i_opq_datak & i_opq_data;
                o_opq_egress_valid <= accept_valid;
                o_opq_egress_sop <= accept_valid and i_opq_sop;
                o_opq_egress_eop <= accept_valid and i_opq_eop;
                o_dma_data <= (others => '0');
                o_dma_data(31 downto 0) <= i_opq_data;
                o_dma_wen <= accept_valid;
                o_end_of_event <= accept_valid and i_opq_eop;
                if accept_valid = '1' then
                    input_word_cnt <= input_word_cnt + 1;
                    if i_opq_eop = '1' then
                        event_cnt <= event_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture;
