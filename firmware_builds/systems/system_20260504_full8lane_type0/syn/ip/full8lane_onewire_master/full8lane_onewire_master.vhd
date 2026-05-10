library ieee;
use ieee.std_logic_1164.all;

entity full8lane_onewire_master is
generic (
    MASTER_INIT_RESET_US                  : natural := 500;
    MASTER_WAIT_PRESENCE_US              : natural := 45;
    MASTER_SAMPLE_PRESENCE_TIMEOUT_US    : natural := 1000;
    SLOTS_SEPERATION_US                  : natural := 5;
    RX_SLOT_US                           : natural := 90;
    RX_PULL_LOW_US                       : natural := 5;
    RX_MASTER_SAMPLE_US                  : natural := 10;
    TX_SLOT_US                           : natural := 90;
    TX_PULL_LOW_US                       : natural := 5;
    PARACITIC_POWERING                   : natural := 0;
    REF_CLOCK_RATE                       : natural := 156250000;
    AVST_DATA_WIDTH                      : natural := 8;
    AVMM_DATA_WIDTH                      : natural := 32;
    N_DQ_LINES                           : natural := 6;
    AVST_CHANNEL_WIDTH                   : natural := 3;
    RX_BUFFER_DEPTH                      : natural := 16;
    TX_BUFFER_DEPTH                      : natural := 8;
    VARIANT                              : string := "lite";
    DEBUG_LV                             : natural := 2;
    RX_FIFO_TYPE                         : string := "MLAB";
    TX_FIFO_TYPE                         : string := "MLAB";
    MAX_BUFFER_DEPTH                     : natural := 16
);
port (
    avs_ctrl_read       : in  std_logic;
    avs_ctrl_readdata   : out std_logic_vector(AVMM_DATA_WIDTH-1 downto 0);
    avs_ctrl_write      : in  std_logic;
    avs_ctrl_writedata  : in  std_logic_vector(AVMM_DATA_WIDTH-1 downto 0);
    avs_ctrl_address    : in  std_logic_vector(3 downto 0);
    avs_ctrl_waitrequest : out std_logic;

    aso_rx_data         : out std_logic_vector(AVST_DATA_WIDTH-1 downto 0);
    aso_rx_valid        : out std_logic;
    aso_rx_ready        : in  std_logic;
    aso_rx_channel      : out std_logic_vector(AVST_CHANNEL_WIDTH-1 downto 0);

    asi_tx_data         : in  std_logic_vector(AVST_DATA_WIDTH-1 downto 0);
    asi_tx_valid        : in  std_logic;
    asi_tx_ready        : out std_logic;
    asi_tx_channel      : in  std_logic_vector(AVST_CHANNEL_WIDTH-1 downto 0);

    ins_complete_irq    : out std_logic;

    coe_sense_dq_in     : in  std_logic_vector(N_DQ_LINES-1 downto 0);
    coe_sense_dq_out    : out std_logic_vector(N_DQ_LINES-1 downto 0);
    coe_sense_dq_oe     : out std_logic_vector(N_DQ_LINES-1 downto 0);

    rsi_reset_reset     : in  std_logic;
    csi_clock_clk       : in  std_logic
);
end entity full8lane_onewire_master;

architecture rtl of full8lane_onewire_master is
    constant PARACITIC_POWERING_BOOL_CONST : boolean := PARACITIC_POWERING /= 0;
begin
    u_core : entity work.onewire_master
    generic map (
        MASTER_INIT_RESET_US               => MASTER_INIT_RESET_US,
        MASTER_WAIT_PRESENCE_US           => MASTER_WAIT_PRESENCE_US,
        MASTER_SAMPLE_PRESENCE_TIMEOUT_US => MASTER_SAMPLE_PRESENCE_TIMEOUT_US,
        SLOTS_SEPERATION_US               => SLOTS_SEPERATION_US,
        RX_SLOT_US                        => RX_SLOT_US,
        RX_PULL_LOW_US                    => RX_PULL_LOW_US,
        RX_MASTER_SAMPLE_US               => RX_MASTER_SAMPLE_US,
        TX_SLOT_US                        => TX_SLOT_US,
        TX_PULL_LOW_US                    => TX_PULL_LOW_US,
        PARACITIC_POWERING                => PARACITIC_POWERING_BOOL_CONST,
        REF_CLOCK_RATE                    => REF_CLOCK_RATE,
        AVST_DATA_WIDTH                   => AVST_DATA_WIDTH,
        AVMM_DATA_WIDTH                   => AVMM_DATA_WIDTH,
        N_DQ_LINES                        => N_DQ_LINES,
        AVST_CHANNEL_WIDTH                => AVST_CHANNEL_WIDTH,
        RX_BUFFER_DEPTH                   => RX_BUFFER_DEPTH,
        TX_BUFFER_DEPTH                   => TX_BUFFER_DEPTH,
        VARIANT                           => VARIANT,
        DEBUG_LV                          => DEBUG_LV,
        RX_FIFO_TYPE                      => RX_FIFO_TYPE,
        TX_FIFO_TYPE                      => TX_FIFO_TYPE,
        MAX_BUFFER_DEPTH                  => MAX_BUFFER_DEPTH
    )
    port map (
        avs_ctrl_read        => avs_ctrl_read,
        avs_ctrl_readdata    => avs_ctrl_readdata,
        avs_ctrl_write       => avs_ctrl_write,
        avs_ctrl_writedata   => avs_ctrl_writedata,
        avs_ctrl_address     => avs_ctrl_address,
        avs_ctrl_waitrequest => avs_ctrl_waitrequest,
        aso_rx_data          => aso_rx_data,
        aso_rx_valid         => aso_rx_valid,
        aso_rx_ready         => aso_rx_ready,
        aso_rx_channel       => aso_rx_channel,
        asi_tx_data          => asi_tx_data,
        asi_tx_valid         => asi_tx_valid,
        asi_tx_ready         => asi_tx_ready,
        asi_tx_channel       => asi_tx_channel,
        ins_complete_irq     => ins_complete_irq,
        coe_sense_dq_in      => coe_sense_dq_in,
        coe_sense_dq_out     => coe_sense_dq_out,
        coe_sense_dq_oe      => coe_sense_dq_oe,
        rsi_reset_reset      => rsi_reset_reset,
        csi_clock_clk        => csi_clock_clk
    );
end architecture rtl;
