--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

use work.util_slv.all;

use work.mudaq.all;
use work.a10_pcie_registers.all;

entity tb_gpu_event is
end entity;

architecture TB of tb_gpu_event is

    signal reset_n : std_logic;
    signal clk, clk_gpu_event : std_logic := '0';
    constant CLK_MHZ : real := 250.0;

    signal float_hit : slv128_array_t(3 downto 0);
    signal backpressure_gpu : std_logic;
    signal float_hit_cnt, slow_down, package_cnt : slv32_array_t(3 downto 0);
    signal float_hit_sop, float_hit_eop, float_hit_valid : std_logic_vector(3 downto 0);
    signal dma_data_array : slv32_array_t(7 downto 0);
    signal dma_data : std_logic_vector(255 downto 0);
    signal dma_wen : std_logic;
    file file_dma_buf : text open write_mode is "dma_buf.bin";

begin

    clk <= not clk after (0.5 us / CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / CLK_MHZ);

    gen_buffer_hits : for i in 0 to 3 generate
    float_hits : process(clk, reset_n)
    begin
    if ( reset_n = '0' ) then
        float_hit_cnt(i) <= (others => '0');
        slow_down(i) <= (others => '0');
        package_cnt(i) <= (others => '0');
        float_hit(i) <= (others => '0');
        --
    elsif rising_edge(clk) then
        slow_down(i) <= slow_down(i) + '1';
        float_hit_valid(i) <= '0';
        float_hit_sop(i) <= '0';
        float_hit_eop(i) <= '0';

        if ( slow_down(i)(1 downto 0) = "00" ) then

            package_cnt(i) <= package_cnt(i) + '1';

            float_hit_cnt(i) <= float_hit_cnt(i) + 4;

            float_hit(i)(31 downto  0) <= float_hit_cnt(i) + 0;
            float_hit(i)(63 downto 32) <= float_hit_cnt(i) + 1;
            float_hit(i)(95 downto 64) <= float_hit_cnt(i) + 2;
            float_hit(i)(127 downto 96) <= float_hit_cnt(i) + 3;

            float_hit_valid(i) <= '1';

            if ( package_cnt(i)(4 downto 0) = "00000" ) then
                float_hit_sop(i) <= '1';
            end if;

            -- increase this value to have more hits per frame
            -- 11110 would mean 30 hits
            if ( package_cnt(i)(4 downto 0) = "11110" ) then
                float_hit_eop(i) <= '1';
                package_cnt(i) <= (others => '0');
            end if;

        end if;
    end if;
    end process;
    end generate;

    e_farm_gpu_event_builder : entity work.farm_gpu_event_builder_onboard_RAM
    port map (

        --! hits per layer input
        i_float_hit         => float_hit,
        i_sop               => float_hit_sop,
        i_eop               => float_hit_eop,
        i_valid             => float_hit_valid,
        i_max_padding_size  => x"0400",
        o_almost_full       => backpressure_gpu,

        --! DMA
        i_dmamemhalffull    => '0',
        i_wen               => '1',
        i_get_n_events      => x"00000001",
        o_dma_wen           => dma_wen,
        o_dma_data          => dma_data,
        o_endofevent        => open,
        o_dma_done          => open,

        --! 250 MHz clock pice / reset_n
        i_reset_n       => reset_n,
        i_clk           => clk--,
    );

    dma_data_array(0) <= dma_data(0*32 + 31 downto 0*32);
    dma_data_array(1) <= dma_data(1*32 + 31 downto 1*32);
    dma_data_array(2) <= dma_data(2*32 + 31 downto 2*32);
    dma_data_array(3) <= dma_data(3*32 + 31 downto 3*32);
    dma_data_array(4) <= dma_data(4*32 + 31 downto 4*32);
    dma_data_array(5) <= dma_data(5*32 + 31 downto 5*32);
    dma_data_array(6) <= dma_data(6*32 + 31 downto 6*32);
    dma_data_array(7) <= dma_data(7*32 + 31 downto 7*32);

    process
        variable data_line : line;
    begin
        while true loop
            wait until rising_edge(clk);  -- Ensure synchronous operation

            if (dma_wen = '1') then
                -- Convert std_logic_vector to string of '0' and '1'
                write(data_line, to_hstring(dma_data));
                writeline(file_dma_buf, data_line);
            end if;
        end loop;

        file_close(file_dma_buf);
    end process;

end architecture;
