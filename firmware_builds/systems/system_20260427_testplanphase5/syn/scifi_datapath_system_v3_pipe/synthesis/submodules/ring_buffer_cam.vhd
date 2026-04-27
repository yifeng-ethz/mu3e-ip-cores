-- File name: ring_buffer_cam.vhd
-- Author  : Yifeng Wang (yifenwan@phys.ethz.ch)
-- Version : 26.2.6
-- Date    : 20260422
-- Change  : package the settled SEARCH-tail timing-safe overlap guard as release 26.2.6.0422

library ieee;
use ieee.std_logic_1164.all;

entity ring_buffer_cam is
    generic (
        SEARCH_KEY_WIDTH    : natural := 8;
        RING_BUFFER_N_ENTRY : natural := 512;
        SIDE_DATA_BITS      : natural := 31;
        INTERLEAVING_FACTOR : natural := 4;
        INTERLEAVING_INDEX  : natural := 0;
        N_PARTITIONS        : natural := 4;
        ENCODER_LEAF_WIDTH  : natural := 16;
        ENCODER_PIPE_STAGES : natural := 4;
        IP_UID              : natural := 1380074317;
        VERSION_MAJOR       : natural := 26;
        VERSION_MINOR       : natural := 2;
        VERSION_PATCH       : natural := 6;
        BUILD               : natural := 422;
        VERSION_DATE        : natural := 20260422;
        VERSION_GIT         : natural := 0;
        INSTANCE_ID         : natural := 0;
        DEBUG               : natural := 1
    );
    port (
        avs_csr_readdata            : out std_logic_vector(31 downto 0);
        avs_csr_read                : in  std_logic;
        avs_csr_address             : in  std_logic_vector(4 downto 0);
        avs_csr_waitrequest         : out std_logic;
        avs_csr_write               : in  std_logic;
        avs_csr_writedata           : in  std_logic_vector(31 downto 0);
        asi_hit_type1_channel       : in  std_logic_vector(3 downto 0);
        asi_hit_type1_startofpacket : in  std_logic;
        asi_hit_type1_endofpacket   : in  std_logic;
        asi_hit_type1_empty         : in  std_logic;
        asi_hit_type1_data          : in  std_logic_vector(38 downto 0);
        asi_hit_type1_valid         : in  std_logic;
        asi_hit_type1_ready         : out std_logic;
        asi_hit_type1_error         : in  std_logic;
        aso_hit_type2_channel       : out std_logic_vector(3 downto 0);
        aso_hit_type2_startofpacket : out std_logic;
        aso_hit_type2_endofpacket   : out std_logic;
        aso_hit_type2_data          : out std_logic_vector(35 downto 0);
        aso_hit_type2_valid         : out std_logic;
        aso_hit_type2_ready         : in  std_logic;
        aso_hit_type2_error         : out std_logic;
        i_clk                       : in  std_logic;
        i_rst                       : in  std_logic;
        asi_ctrl_data               : in  std_logic_vector(8 downto 0);
        asi_ctrl_valid              : in  std_logic;
        asi_ctrl_ready              : out std_logic;
        aso_filllevel_data          : out std_logic_vector(15 downto 0);
        aso_filllevel_valid         : out std_logic
    );
end entity ring_buffer_cam;

architecture rtl of ring_buffer_cam is
    signal asi_hit_type1_error_vec : std_logic_vector(0 downto 0);
    signal aso_hit_type2_error_vec : std_logic_vector(0 downto 0);
begin
    asi_hit_type1_error_vec(0) <= asi_hit_type1_error;
    aso_hit_type2_error        <= aso_hit_type2_error_vec(0);

    v2_core : entity work.ring_buffer_cam_v2_core
        generic map (
            SEARCH_KEY_WIDTH    => SEARCH_KEY_WIDTH,
            RING_BUFFER_N_ENTRY => RING_BUFFER_N_ENTRY,
            SIDE_DATA_BITS      => SIDE_DATA_BITS,
            INTERLEAVING_FACTOR => INTERLEAVING_FACTOR,
            INTERLEAVING_INDEX  => INTERLEAVING_INDEX,
            N_PARTITIONS        => N_PARTITIONS,
            ENCODER_LEAF_WIDTH  => ENCODER_LEAF_WIDTH,
            ENCODER_PIPE_STAGES => ENCODER_PIPE_STAGES,
            IP_UID              => IP_UID,
            VERSION_MAJOR       => VERSION_MAJOR,
            VERSION_MINOR       => VERSION_MINOR,
            VERSION_PATCH       => VERSION_PATCH,
            BUILD               => BUILD,
            VERSION_DATE        => VERSION_DATE,
            VERSION_GIT         => VERSION_GIT,
            INSTANCE_ID         => INSTANCE_ID,
            DEBUG               => DEBUG
        )
        port map (
            avs_csr_readdata            => avs_csr_readdata,
            avs_csr_read                => avs_csr_read,
            avs_csr_address             => avs_csr_address,
            avs_csr_waitrequest         => avs_csr_waitrequest,
            avs_csr_write               => avs_csr_write,
            avs_csr_writedata           => avs_csr_writedata,
            asi_ctrl_data               => asi_ctrl_data,
            asi_ctrl_valid              => asi_ctrl_valid,
            asi_ctrl_ready              => asi_ctrl_ready,
            asi_hit_type1_channel       => asi_hit_type1_channel,
            asi_hit_type1_startofpacket => asi_hit_type1_startofpacket,
            asi_hit_type1_endofpacket   => asi_hit_type1_endofpacket,
            asi_hit_type1_empty         => asi_hit_type1_empty,
            asi_hit_type1_data          => asi_hit_type1_data,
            asi_hit_type1_valid         => asi_hit_type1_valid,
            asi_hit_type1_ready         => asi_hit_type1_ready,
            asi_hit_type1_error         => asi_hit_type1_error_vec,
            aso_hit_type2_channel       => aso_hit_type2_channel,
            aso_hit_type2_startofpacket => aso_hit_type2_startofpacket,
            aso_hit_type2_endofpacket   => aso_hit_type2_endofpacket,
            aso_hit_type2_data          => aso_hit_type2_data,
            aso_hit_type2_valid         => aso_hit_type2_valid,
            aso_hit_type2_ready         => aso_hit_type2_ready,
            aso_hit_type2_error         => aso_hit_type2_error_vec,
            aso_filllevel_valid         => aso_filllevel_valid,
            aso_filllevel_data          => aso_filllevel_data,
            i_rst                       => i_rst,
            i_clk                       => i_clk
        );
end architecture rtl;
