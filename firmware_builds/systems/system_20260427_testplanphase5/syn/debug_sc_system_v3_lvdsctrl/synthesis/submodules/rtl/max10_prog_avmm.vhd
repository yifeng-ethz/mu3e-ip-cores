-- File name : max10_prog_avmm.vhd
-- Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision  : 26.2.1 (pipeline launch_page_data bulk copy via launch_copy_pending one-shot)
-- Date      : 20260416
-- Change    : The launch_page_data <= page_data bulk copy previously fired
--             combinationally the same cycle as the validated START command.
--             Quartus built the 65x32 register file's |sload enable from the
--             full START-decode cone (address + START bit + state +
--             xfer_bytes + page_ready + page_valid checks), pulling a 6-LUT
--             path from the AVMM pipeline stage data1[46] into
--             launch_page_data[*][*]|sload and failing round-8 Slow-85C setup
--             at -0.256. The fix arms a single-flop one-shot
--             (launch_copy_pending) when START validates, and performs the
--             bulk copy one cycle later. The |sload enable collapses to a
--             one-flop compare. Queue handshake timing is preserved: the
--             first FIFO push is the header (uses launch_flash_addr /
--             launch_xfer_bytes, not launch_page_data), so the +1-cycle
--             launch_page_data latch still lands before the first data word
--             push at queue_word_index = 0.
-- Revision  : 26.2.0 (registered csr_staged_words to break prefix_count_func cone at Slow-85C)
-- Date      : 20260415
-- =========
-- Description : [Arria-side AVMM-to-MAX10 programming bridge]
--
-- Abbreviations
--   AVMM : Avalon Memory-Mapped
--   CSR  : Control and Status Register
--   FEB  : Front-End Board
--   MAX10: Intel MAX 10 FPGA / system controller
--   FPP  : Fast Passive Parallel configuration
--   WFIFO: MAX10-side programming write FIFO
--
-- Function
--   This IP accepts standard incrementing AVMM writes from sc_hub, stages one
--   programming chunk in local page storage, and translates CTRL.START into the
--   existing custom Arria<->MAX10 SPI-like protocol. The downstream MAX10
--   firmware and flash-programming behavior are kept unchanged.
--
-- Hard spec
--   1) The AVMM slave is 32-bit, word-addressed, and does not use byteenable.
--   2) PAGE_DATA holds up to 64 words = 256 bytes per programming transaction.
--   3) XFER_BYTES defines the valid byte count for the next START, range 1..256.
--   4) FLASH_ADDR is a 24-bit absolute SPI-flash byte address.
--   5) CTRL bits are write-one pulse commands; STATUS and ERROR are software ABI.
--   6) MAX10 raw programming status is mirrored without bit renumbering.
--
-- Software sequence
--   1) Write FLASH_ADDR and XFER_BYTES.
--   2) Burst-write PAGE_DATA[0..N-1] contiguously from word 0.
--   3) Pulse CTRL.START.
--   4) Poll STATUS.BUSY until 0, then inspect STATUS and ERROR.
--
-- Reset behavior
--   1) XFER_BYTES resets to 256.
--   2) FLASH_ADDR, staged-word count, and sticky status reset to 0.
--   3) CTRL has no retained state; reads return 0 except for the one-cycle
--      sw_reset acknowledgement.
--
-- Integration
--   1) The AVMM slave faces sc_hub inside the control-path subsystem.
--   2) The custom conduit faces the Arria<->MAX10 SPI-like link.
--   3) Existing FEBSPI/MAX10 semantics remain the downstream contract.
--
-- Debug notes
--   1) STATUS[31:24] may expose local engine state for waveform/debug only.
--   2) MAX10_COUNT is a raw mirror and must not be treated as stable software ABI.
--
-- OPEN
--   1) Replace the local START stub with the real link-domain sequencer and CDC.
--   2) Hook MAX10_STAT/MAX10_COUNT to the imported Arria-side max10_spi engine.
--   3) Confirm whether DATE is needed in the common header for this repo family.
--
-- ================ synthesizer configuration ==================
-- altera vhdl_input_version vhdl_2008
-- ============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library altera_mf;
use altera_mf.altera_mf_components.all;
use work.mudaq.all;

entity max10_prog_avmm is
    generic (
        CSR_ADDR_W      : natural    := 10;
        BURSTCOUNT_W    : natural    := 9;
        CDC_FIFO_ADDR_W : natural    := 7;
        BOOT_HIST_AUTO_REFRESH : natural := 0;
        DEBUG_LEVEL     : natural    := 1;
        BUILD           : natural    := 0;
        VERSION_MAJOR   : natural    := 0;
        VERSION_MINOR   : natural    := 1;
        VERSION_PATCH   : natural    := 0;
        IP_ID           : natural    := 16#4D313050#
    );
    port (
        avs_csr_address        : in    std_logic_vector(CSR_ADDR_W-1 downto 0);  -- Word-addressed CSR address.
        avs_csr_read           : in    std_logic;                                -- AVMM read qualifier.
        avs_csr_write          : in    std_logic;                                -- AVMM write qualifier.
        avs_csr_writedata      : in    std_logic_vector(31 downto 0);            -- AVMM write payload.
        avs_csr_readdata       : out   std_logic_vector(31 downto 0);            -- AVMM read payload.
        avs_csr_readdatavalid  : out   std_logic;                                -- AVMM read response qualifier.
        avs_csr_waitrequest    : out   std_logic;                                -- AVMM backpressure; Rev A is always ready.
        avs_csr_burstcount     : in    std_logic_vector(BURSTCOUNT_W-1 downto 0);-- AVMM burstcount for incrementing page writes.

        csi_csr_clk       : in    std_logic; -- CSR and staging clock.
        rsi_csr_reset     : in    std_logic; -- CSR-domain reset, active high.
        csi_link_clk      : in    std_logic; -- Future MAX10 link clock domain.
        rsi_link_reset    : in    std_logic; -- Future MAX10 link reset, active high.

        coe_max10_spi_csn         : out   std_logic; -- MAX10 custom-link chip-select.
        coe_max10_spi_clk         : out   std_logic; -- MAX10 custom-link clock.
        coe_max10_spi_mosi_in     : in    std_logic; -- MAX10 custom-link lane 0 sampled from top-level buffer.
        coe_max10_spi_mosi_out    : out   std_logic; -- MAX10 custom-link lane 0 drive value toward top-level buffer.
        coe_max10_spi_mosi_oe     : out   std_logic; -- MAX10 custom-link lane 0 output-enable.
        coe_max10_spi_miso_in     : in    std_logic; -- MAX10 custom-link lane 1 sampled from top-level buffer.
        coe_max10_spi_miso_out    : out   std_logic; -- MAX10 custom-link lane 1 drive value toward top-level buffer.
        coe_max10_spi_miso_oe     : out   std_logic; -- MAX10 custom-link lane 1 output-enable.
        coe_max10_spi_d1_in       : in    std_logic; -- MAX10 custom-link lane 2 sampled from top-level buffer.
        coe_max10_spi_d1_out      : out   std_logic; -- MAX10 custom-link lane 2 drive value toward top-level buffer.
        coe_max10_spi_d1_oe       : out   std_logic; -- MAX10 custom-link lane 2 output-enable.
        coe_max10_spi_d2_in       : in    std_logic; -- MAX10 custom-link lane 3 sampled from top-level buffer.
        coe_max10_spi_d2_out      : out   std_logic; -- MAX10 custom-link lane 3 drive value toward top-level buffer.
        coe_max10_spi_d2_oe       : out   std_logic; -- MAX10 custom-link lane 3 output-enable.
        coe_max10_spi_d3_in       : in    std_logic; -- MAX10 custom-link lane 4 sampled from top-level buffer.
        coe_max10_spi_d3_out      : out   std_logic; -- MAX10 custom-link lane 4 drive value toward top-level buffer.
        coe_max10_spi_d3_oe       : out   std_logic; -- MAX10 custom-link lane 4 output-enable.

        coe_diag_summary          : out   std_logic_vector(31 downto 0); -- Optional CSR-domain diagnostic summary.
        coe_diag_err_flags        : out   std_logic_vector(31 downto 0); -- Optional sticky local error flags.
        coe_diag_last_error       : out   std_logic_vector(31 downto 0); -- Optional last-error record.
        coe_diag_max10_stat       : out   std_logic_vector(31 downto 0); -- Optional mirrored MAX10 status.
        coe_diag_max10_count      : out   std_logic_vector(31 downto 0)  -- Optional mirrored MAX10 debug count.
    );
end entity max10_prog_avmm;

architecture rtl of max10_prog_avmm is

    subtype word_t is std_logic_vector(31 downto 0);

    type page_mem_array is array (0 to 63) of word_t;
    type boot_words_array is array (0 to 5) of word_t;

    type state_t is (
        IDLING,
        LAUNCHING,
        COMPLETING,
        ABORTING
    );

    type link_state_t is (
        RESETTING,
        STANDINGBY,
        PRIMINGFIFO,
        PUMPINGFIFO,
        WAITINGFIFO,
        WRITINGADDR,
        WAITINGADDR,
        WRITINGCTRLSTART,
        WAITINGCTRLSTART,
        READINGSTATUS,
        WAITINGSTATUSWORD,
        WAITINGSTATUSDONE,
        WRITINGCTRLSTOP,
        WAITINGCTRLSTOP,
        READINGCOUNT,
        WAITINGCOUNTWORD,
        WAITINGCOUNTDONE,
        READINGBOOTHISTINFO,
        WAITINGBOOTHISTINFOWORD,
        READINGBOOTEVT0,
        WAITINGBOOTEVT0WORD,
        READINGBOOTEVT1,
        WAITINGBOOTEVT1WORD,
        READINGBOOTPERSIST,
        WAITINGBOOTPERSISTWORD,
        NOTIFYING
    );

    type csr_reg_t is record
        scratch             : word_t;
        flash_addr          : std_logic_vector(23 downto 0);
        flash_addr_valid    : std_logic;
        xfer_bytes          : unsigned(8 downto 0);
        err_flags           : word_t;
        err_count           : unsigned(31 downto 0);
        last_error          : word_t;
        max10_stat          : word_t;
        max10_count         : word_t;
        busy                : std_logic;
        resetting           : std_logic;
        launch_accepted     : std_logic;
        launch_done         : std_logic;
        state               : state_t;
        launch_flash_addr   : std_logic_vector(23 downto 0);
        launch_xfer_bytes   : unsigned(8 downto 0);
        launch_toggle       : std_logic;
        boot_refresh_busy   : std_logic;
        boot_refresh_toggle : std_logic;
        boot_auto_refresh_armed : std_logic;
        boot_done_toggle_sync : std_logic_vector(2 downto 0);
        boot_live_info      : word_t;
        boot_persist_info   : word_t;
        boot_evt0_words     : boot_words_array;
        boot_evt1_words     : boot_words_array;
        boot_persist_words  : boot_words_array;
        queue_active        : std_logic;
        queue_header        : std_logic;
        queue_word_index    : natural range 0 to 63;
        done_toggle_sync    : std_logic_vector(2 downto 0);
    end record csr_reg_t;

    type link_reg_t is record
        -- Functional control state: cleared by hard reset and by the soft functional
        -- reset path that runs through the RESETTING state.
        state               : link_state_t;
        launch_toggle_sync  : std_logic_vector(2 downto 0);
        resetting_sync      : std_logic_vector(2 downto 0);
        done_toggle         : std_logic;
        boot_done_toggle    : std_logic;
        busy_last           : std_logic;
        ctrl_start_issued   : std_logic;
        payload_started     : std_logic;
        cmd_strobe          : std_logic;
        cmd_addr            : std_logic_vector(6 downto 0);
        cmd_rw              : std_logic;
        cmd_data_to_max     : word_t;
        cmd_numbytes        : std_logic_vector(8 downto 0);
        boot_word_index     : natural range 0 to 5;
        boot_refresh_toggle_sync : std_logic_vector(2 downto 0);
        launch_flash_addr   : std_logic_vector(23 downto 0);
        launch_xfer_bytes   : unsigned(8 downto 0);
        payload_words_total : natural range 0 to 64;
        payload_words_sent  : natural range 0 to 64;
        status_poll_count   : natural range 0 to 65535;
        txn_timeout_count   : natural range 0 to 65535;
        flash_busy          : std_logic;

        -- Retained debug mirrors: preserved across the soft functional reset path.
        max10_stat          : word_t;
        max10_count         : word_t;
        err_flags           : word_t;
        err_code            : std_logic_vector(7 downto 0);

        -- Retained boot-history cache: preserved across the soft functional reset path.
        boot_live_info      : word_t;
        boot_persist_info   : word_t;
        boot_evt0_words     : boot_words_array;
        boot_evt1_words     : boot_words_array;
        boot_persist_words  : boot_words_array;
    end record link_reg_t;

    type csr_pack_reg_t is record
        page_data           : page_mem_array;
        page_valid          : std_logic_vector(63 downto 0);
        launch_page_data    : page_mem_array;
    end record csr_pack_reg_t;

    type link_var_t is record
        reg                 : link_reg_t;
        xfer_bytes          : unsigned(8 downto 0);
        reset_requested     : std_logic;
        must_drain          : boolean;
    end record link_var_t;

    function bool_to_std_logic_func (
        constant flag_value   : boolean
    ) return std_logic is
    begin
        if flag_value then
            return '1';
        else
            return '0';
        end if;
    end function bool_to_std_logic_func;

    constant CDC_FIFO_WIDTH_CONST             : natural                := 40;
    constant CDC_HEADER_FLAG_BIT_CONST        : natural                := 39;
    constant CDC_HEADER_XFER_MSB_CONST        : natural                := 32;
    constant CDC_HEADER_XFER_LSB_CONST        : natural                := 24;
    constant IP_ID_CONST                      : word_t                 := std_logic_vector(to_unsigned(IP_ID, 32)); -- "M10P"
    -- Background boot-history refresh is only useful when the debug-facing
    -- registers are actually exposed. Keeping it disabled for DEBUG_LEVEL=0
    -- avoids live status churn in the production sc_hub CSR aperture.
    constant BOOT_HIST_AUTO_REFRESH_CONST     : std_logic              := bool_to_std_logic_func((BOOT_HIST_AUTO_REFRESH /= 0) and (DEBUG_LEVEL /= 0));
    constant XFER_BYTES_RESET_CONST           : unsigned(8 downto 0)   := to_unsigned(256, 9);
    constant ZERO_WORD_CONST                  : word_t                 := (others => '0');
    constant PAGE_MEM_RESET_CONST             : page_mem_array         := (others => (others => '0'));
    constant PAGE_VALID_RESET_CONST           : std_logic_vector(63 downto 0) := (others => '0');
    constant ERR_COUNT_MAX_CONST              : unsigned(31 downto 0)  := (others => '1');

    constant REG_ID_CONST                     : natural                := 16#000#;
    constant REG_VERSION_CONST                : natural                := 16#001#;
    constant REG_CTRL_CONST                   : natural                := 16#002#;
    constant REG_STATUS_CONST                 : natural                := 16#003#;
    constant REG_ERR_FLAGS_CONST              : natural                := 16#004#;
    constant REG_ERR_COUNT_CONST              : natural                := 16#005#;
    constant REG_SCRATCH_CONST                : natural                := 16#006#;
    constant REG_FLASH_ADDR_CONST             : natural                := 16#007#;
    constant REG_XFER_BYTES_CONST             : natural                := 16#008#;
    constant REG_PROG_CTRL_CONST              : natural                := 16#009#;
    constant REG_PROG_STATUS_CONST            : natural                := 16#00A#;
    constant REG_STAGED_WORDS_CONST           : natural                := 16#00B#;
    constant REG_MAX10_STAT_CONST             : natural                := 16#00C#;
    constant REG_MAX10_COUNT_CONST            : natural                := 16#00D#;
    constant REG_LAST_ERROR_CONST             : natural                := 16#00E#;
    constant REG_PAGE_DATA_BASE_CONST         : natural                := 16#020#;
    constant REG_PAGE_DATA_LAST_CONST         : natural                := 16#05F#;
    constant REG_BOOT_HIST_CTRL_CONST         : natural                := 16#060#;
    constant REG_BOOT_LIVE_INFO_CONST         : natural                := 16#061#;
    constant REG_BOOT_EVT0_BASE_CONST         : natural                := 16#062#;
    constant REG_BOOT_EVT0_LAST_CONST         : natural                := 16#067#;
    constant REG_BOOT_EVT1_BASE_CONST         : natural                := 16#068#;
    constant REG_BOOT_EVT1_LAST_CONST         : natural                := 16#06D#;
    constant REG_BOOT_PERSIST_INFO_CONST      : natural                := 16#06E#;
    constant REG_BOOT_PERSIST_BASE_CONST      : natural                := 16#06F#;
    constant REG_BOOT_PERSIST_LAST_CONST      : natural                := 16#074#;

    constant ERR_START_WHILE_BUSY_CONST       : natural                := 0;
    constant ERR_START_DURING_RESET_CONST     : natural                := 1;
    constant ERR_ADDR_MISSING_CONST           : natural                := 2;
    constant ERR_XFER_BYTES_ZERO_CONST        : natural                := 3;
    constant ERR_XFER_BYTES_GT_256_CONST      : natural                := 4;
    constant ERR_PAGE_UNDERRUN_CONST          : natural                := 5;
    constant ERR_LINK_TIMEOUT_CONST           : natural                := 6;
    constant ERR_MAX10_TIMEOUT_CONST          : natural                := 7;
    constant ERR_MAX10_NSTATUS_LOW_CONST      : natural                := 8;
    constant ERR_MAX10_CRCERROR_CONST         : natural                := 9;

    constant CODE_NONE_CONST                  : natural                := 16#00#;
    constant CODE_START_WHILE_BUSY_CONST      : natural                := 16#01#;
    constant CODE_START_DURING_RESET_CONST    : natural                := 16#02#;
    constant CODE_ADDR_MISSING_CONST          : natural                := 16#03#;
    constant CODE_XFER_BYTES_ZERO_CONST       : natural                := 16#04#;
    constant CODE_XFER_BYTES_GT_256_CONST     : natural                := 16#05#;
    constant CODE_PAGE_UNDERRUN_CONST         : natural                := 16#06#;
    constant CODE_LINK_TIMEOUT_CONST          : natural                := 16#07#;
    constant CODE_MAX10_TIMEOUT_CONST         : natural                := 16#08#;
    constant CODE_MAX10_NSTATUS_LOW_CONST     : natural                := 16#09#;
    constant CODE_MAX10_CRCERROR_CONST        : natural                := 16#0A#;
    constant CODE_ABORTED_SW_RESET_CONST      : natural                := 16#80#;

    constant MAX10_STATUS_BIT_ARRIAWRITING_CONST
                                             : natural                := 0;
    constant MAX10_STATUS_BIT_SPI_BUSY_CONST  : natural                := 1;
    constant MAX10_STATUS_BIT_FIFO_EMPTY_CONST
                                             : natural                := 14;
    constant MAX10_STATUS_BIT_FIFO_FULL_CONST : natural                := 15;
    constant MAX10_STATUS_BIT_CONF_DONE_CONST : natural                := 16;
    constant MAX10_STATUS_BIT_NSTATUS_CONST   : natural                := 17;
    constant MAX10_STATUS_BIT_TIMEOUT_CONST   : natural                := 18;
    constant MAX10_STATUS_BIT_CRCERROR_CONST  : natural                := 19;

    constant LINK_TRANSACTION_TIMEOUT_CONST   : natural                := 65535;
    constant MAX10_STATUS_POLL_TIMEOUT_CONST  : natural                := 65535;

    constant CSR_RESET_CONST : csr_reg_t := (
        scratch             => (others => '0'),
        flash_addr          => (others => '0'),
        flash_addr_valid    => '0',
        xfer_bytes          => XFER_BYTES_RESET_CONST,
        err_flags           => (others => '0'),
        err_count           => (others => '0'),
        last_error          => (others => '0'),
        max10_stat          => (others => '0'),
        max10_count         => (others => '0'),
        busy                => '0',
        resetting           => '0',
        launch_accepted     => '0',
        launch_done         => '0',
        state               => IDLING,
        launch_flash_addr   => (others => '0'),
        launch_xfer_bytes   => XFER_BYTES_RESET_CONST,
        launch_toggle       => '0',
        boot_refresh_busy   => '0',
        boot_refresh_toggle => '0',
        boot_auto_refresh_armed => BOOT_HIST_AUTO_REFRESH_CONST,
        boot_done_toggle_sync => (others => '0'),
        boot_live_info      => (others => '0'),
        boot_persist_info   => (others => '0'),
        boot_evt0_words     => (others => (others => '0')),
        boot_evt1_words     => (others => (others => '0')),
        boot_persist_words  => (others => (others => '0')),
        queue_active        => '0',
        queue_header        => '0',
        queue_word_index    => 0,
        done_toggle_sync    => (others => '0')
    );

    constant LINK_RESET_CONST : link_reg_t := (
        state               => RESETTING,
        launch_toggle_sync  => (others => '0'),
        resetting_sync      => (others => '0'),
        done_toggle         => '0',
        boot_done_toggle    => '0',
        busy_last           => '0',
        ctrl_start_issued   => '0',
        payload_started     => '0',
        cmd_strobe          => '0',
        cmd_addr            => (others => '0'),
        cmd_rw              => '0',
        cmd_data_to_max     => (others => '0'),
        cmd_numbytes        => (others => '0'),
        boot_word_index     => 0,
        boot_refresh_toggle_sync => (others => '0'),
        boot_live_info      => (others => '0'),
        boot_persist_info   => (others => '0'),
        boot_evt0_words     => (others => (others => '0')),
        boot_evt1_words     => (others => (others => '0')),
        boot_persist_words  => (others => (others => '0')),
        launch_flash_addr   => (others => '0'),
        launch_xfer_bytes   => XFER_BYTES_RESET_CONST,
        payload_words_total => 0,
        payload_words_sent  => 0,
        status_poll_count   => 0,
        txn_timeout_count   => 0,
        flash_busy          => '0',
        max10_stat          => (others => '0'),
        max10_count         => (others => '0'),
        err_flags           => (others => '0'),
        err_code            => std_logic_vector(to_unsigned(CODE_NONE_CONST, 8))
    );

    constant CSR_PACK_RESET_CONST : csr_pack_reg_t := (
        page_data           => PAGE_MEM_RESET_CONST,
        page_valid          => PAGE_VALID_RESET_CONST,
        launch_page_data    => PAGE_MEM_RESET_CONST
    );

    function pack_version_func (
        constant major_value    : natural;
        constant minor_value    : natural;
        constant patch_value    : natural;
        constant build_value    : natural
    ) return word_t is
    begin
        return std_logic_vector(to_unsigned(major_value, 8)) &
               std_logic_vector(to_unsigned(minor_value, 8)) &
               std_logic_vector(to_unsigned(patch_value, 4)) &
               std_logic_vector(to_unsigned(build_value, 12));
    end function pack_version_func;

    function cdc_header_word_func (
        constant flash_addr_value : std_logic_vector(23 downto 0);
        constant xfer_bytes_value : unsigned(8 downto 0)
    ) return std_logic_vector is
        variable header_v         : std_logic_vector(CDC_FIFO_WIDTH_CONST-1 downto 0) := (others => '0');
    begin
        header_v(CDC_HEADER_FLAG_BIT_CONST)                                  := '1';
        header_v(CDC_HEADER_XFER_MSB_CONST downto CDC_HEADER_XFER_LSB_CONST) := std_logic_vector(xfer_bytes_value);
        header_v(23 downto 0)                                                := flash_addr_value;
        return header_v;
    end function cdc_header_word_func;

    function prefix_count_func (
        constant page_valid_value : std_logic_vector(63 downto 0)
    ) return natural is
        variable prefix_count_v : natural := 0;
    begin
        for page_idx in 0 to 63 loop
            if page_valid_value(page_idx) = '1' then
                prefix_count_v := prefix_count_v + 1;
            else
                exit;
            end if;
        end loop;
        return prefix_count_v;
    end function prefix_count_func;

    function required_words_func (
        constant xfer_bytes_value : unsigned(8 downto 0)
    ) return natural is
        variable required_words_v : natural := to_integer(xfer_bytes_value);
    begin
        if required_words_v = 0 then
            return 0;
        elsif required_words_v > 256 then
            return 64;
        else
            return (required_words_v + 3) / 4;
        end if;
    end function required_words_func;

    function state_to_slv_func (
        constant state_value    : state_t
    ) return std_logic_vector is
    begin
        case state_value is
            when IDLING        => return x"00";
            when LAUNCHING     => return x"10";
            when COMPLETING    => return x"20";
            when ABORTING      => return x"F0";
        end case;
    end function state_to_slv_func;

    function link_state_to_slv_func (
        constant state_value    : link_state_t
    ) return std_logic_vector is
    begin
        case state_value is
            when RESETTING         => return x"F8";
            when STANDINGBY         => return x"00";
            when PRIMINGFIFO        => return x"04";
            when PUMPINGFIFO        => return x"08";
            when WAITINGFIFO        => return x"0C";
            when WRITINGADDR        => return x"10";
            when WAITINGADDR        => return x"14";
            when WRITINGCTRLSTART   => return x"18";
            when WAITINGCTRLSTART   => return x"1C";
            when READINGSTATUS      => return x"20";
            when WAITINGSTATUSWORD  => return x"24";
            when WAITINGSTATUSDONE  => return x"28";
            when WRITINGCTRLSTOP    => return x"2C";
            when WAITINGCTRLSTOP    => return x"30";
            when READINGCOUNT       => return x"34";
            when WAITINGCOUNTWORD   => return x"38";
            when WAITINGCOUNTDONE   => return x"3C";
            when READINGBOOTHISTINFO=> return x"44";
            when WAITINGBOOTHISTINFOWORD => return x"48";
            when READINGBOOTEVT0    => return x"50";
            when WAITINGBOOTEVT0WORD=> return x"54";
            when READINGBOOTEVT1    => return x"5C";
            when WAITINGBOOTEVT1WORD=> return x"60";
            when READINGBOOTPERSIST => return x"68";
            when WAITINGBOOTPERSISTWORD => return x"6C";
            when NOTIFYING          => return x"40";
        end case;
    end function link_state_to_slv_func;

    function sw_reset_image_func (
        constant csr_value      : csr_reg_t
    ) return csr_reg_t is
        variable csr_v          : csr_reg_t := CSR_RESET_CONST;
    begin
        csr_v.scratch           := csr_value.scratch;
        csr_v.err_count         := csr_value.err_count;
        csr_v.boot_live_info    := csr_value.boot_live_info;
        csr_v.boot_persist_info := csr_value.boot_persist_info;
        csr_v.boot_evt0_words   := csr_value.boot_evt0_words;
        csr_v.boot_evt1_words   := csr_value.boot_evt1_words;
        csr_v.boot_persist_words:= csr_value.boot_persist_words;
        csr_v.boot_auto_refresh_armed := '0';
        return csr_v;
    end function sw_reset_image_func;

    function link_soft_reset_func (
        constant link_value     : link_reg_t
    ) return link_reg_t is
        variable link_v         : link_reg_t := link_value;
    begin
        link_v.state                    := RESETTING;
        link_v.launch_toggle_sync       := (others => '0');
        link_v.resetting_sync           := (others => '0');
        link_v.busy_last                := '0';
        link_v.ctrl_start_issued        := '0';
        link_v.payload_started          := '0';
        link_v.cmd_strobe               := '0';
        link_v.cmd_addr                 := (others => '0');
        link_v.cmd_rw                   := '0';
        link_v.cmd_data_to_max          := (others => '0');
        link_v.cmd_numbytes             := (others => '0');
        link_v.boot_word_index          := 0;
        link_v.boot_refresh_toggle_sync := (others => '0');
        link_v.launch_flash_addr        := (others => '0');
        link_v.launch_xfer_bytes        := XFER_BYTES_RESET_CONST;
        link_v.payload_words_total      := 0;
        link_v.payload_words_sent       := 0;
        link_v.status_poll_count        := 0;
        link_v.txn_timeout_count        := 0;
        link_v.flash_busy               := '0';
        return link_v;
    end function link_soft_reset_func;

    procedure record_error_proc (
        constant err_bit          : in    natural;
        constant err_code         : in    natural;
        constant state_value      : in    state_t;
        constant staged_words     : in    natural;
        constant max10_debug      : in    std_logic_vector(7 downto 0);
        variable err_flags_v      : inout word_t;
        variable last_error_v     : inout word_t;
        variable error_event_v    : inout boolean
    ) is
    begin
        err_flags_v(err_bit)          := '1';
        last_error_v(7 downto 0)      := std_logic_vector(to_unsigned(err_code, 8));
        last_error_v(15 downto 8)     := state_to_slv_func(state_value);
        last_error_v(23 downto 16)    := std_logic_vector(to_unsigned(staged_words, 8));
        last_error_v(31 downto 24)    := max10_debug;
        error_event_v                 := true;
    end procedure record_error_proc;

    signal csr                         : csr_reg_t                := CSR_RESET_CONST;
    signal link                        : link_reg_t               := LINK_RESET_CONST; -- Downstream Arria-to-MAX10 FEBSPI link-domain state owner.
    signal csr_pack                    : csr_pack_reg_t           := CSR_PACK_RESET_CONST; -- Large CSR-domain page-storage pack kept outside csr.

    signal csr_staged_words_comb       : natural range 0 to 64;                     -- Combinational output of prefix_count_func(page_valid); feeds the csr_staged_words flop.
    signal csr_staged_words            : natural range 0 to 64                 := 0; -- Registered copy of csr_staged_words_comb; breaks the prefix_count_func combinational cone from page_valid to csr_page_ready_r / csr_bank_ctrl_r at Slow-85C setup.
    signal csr_required_words          : natural range 0 to 64;
    signal csr_len_valid               : std_logic;
    signal csr_page_ready              : std_logic;
    signal csr_page_ready_r            : std_logic                  := '0'; -- Registered copy of csr_page_ready; breaks the prefix_count_func combinational path from page_valid to launch_toggle.
    -- One-shot pulse armed when a validated START command is accepted.
    -- Drives the launch_page_data bulk copy one cycle later so the
    -- launch_page_data[*]|sload enable is a single-flop compare instead of a
    -- 6-LUT cone that decodes address + START bit + state + xfer_bytes + page_ready
    -- combinationally. Fixes round-8 path-15 (data1[46] -> launch_page_data[*]|sload
    -- -0.256 at Slow 85C).
    signal launch_copy_pending         : std_logic                  := '0';
    signal csr_ready                   : std_logic;
    signal csr_fault                   : std_logic;
    signal csr_state_slv               : std_logic_vector(7 downto 0);
    -- Per-bank pipelined CSR readback cone (Slow-85C setup closure).
    --
    -- The readback mux is split into three narrow bank decoders whose outputs
    -- are flopped, and stage 2 is a shallow 3-way OR of the flopped bank words.
    -- This removes csr_read_addr_reg[*] from the direct arrival path to
    -- csr_read_data[*]: the worst remaining stage-1.5 bank decode is the 64-way
    -- indexed page_data mux, and stage 2 is a 1-LUT OR-reduce. AVMM read
    -- latency increases from 2 to 3 cycles — sc_hub uses waitrequest so the
    -- additional cycle is transparent to masters. Burst drain throughput is
    -- unchanged (one valid per cycle in steady state).
    signal csr_bank_ctrl_comb          : word_t;                    -- Bank 0 (0x000..0x00E) combinational decode.
    signal csr_bank_page_comb          : word_t;                    -- Bank 1 (0x020..0x05F) combinational page_data mux.
    signal csr_bank_boot_comb          : word_t;                    -- Bank 2 (0x060..0x074) combinational boot-history mux.
    signal csr_bank_ctrl_r           : word_t                     := (others => '0'); -- Stage 1.5 flop for bank 0.
    signal csr_bank_page_r           : word_t                     := (others => '0'); -- Stage 1.5 flop for bank 1.
    signal csr_bank_boot_r           : word_t                     := (others => '0'); -- Stage 1.5 flop for bank 2.
    signal csr_read_respond_r         : std_logic                  := '0'; -- 1-cycle delayed respond; gates csr_read_valid at stage 2.
    signal csr_done_toggle_det         : std_logic                  := '0'; -- Registered done-toggle detect; breaks the combo path from done_toggle_sync[1,2] through the variable-based state machine.
    signal csr_read_addr_reg           : std_logic_vector(CSR_ADDR_W-1 downto 0) := (others => '0'); -- Registered read address; breaks the combo path from csr_read_burst_active through the case decode.
    signal csr_read_respond            : std_logic                  := '0'; -- Stage 1 arm flag: bank decoders drive stage-1.5 flops this cycle.
    signal csr_read_data               : word_t                     := (others => '0');
    signal csr_read_valid              : std_logic                  := '0';
    signal csr_read_burst_active       : std_logic                  := '0';
    signal csr_read_burst_addr         : unsigned(CSR_ADDR_W-1 downto 0) := (others => '0');
    signal csr_read_burst_remaining    : natural range 0 to 65535  := 0;
    signal csr_diag_summary            : word_t;
    signal csr_fifo_clear              : std_logic                 := '0';

    signal link_spi_next_data          : std_logic;
    signal link_spi_word_from_max      : word_t;
    signal link_spi_word_en            : std_logic;
    signal link_spi_byte_from_max      : std_logic_vector(7 downto 0);
    signal link_spi_byte_en            : std_logic;
    signal link_spi_busy               : std_logic;
    signal cdc_fifo_aclr               : std_logic;
    signal cdc_fifo_wrreq              : std_logic                 := '0';
    signal cdc_fifo_wrfull             : std_logic;
    signal cdc_fifo_wrdata             : std_logic_vector(CDC_FIFO_WIDTH_CONST-1 downto 0) := (others => '0');
    signal cdc_fifo_rdreq              : std_logic                 := '0';
    signal cdc_fifo_rdempty            : std_logic;
    signal cdc_fifo_q                  : std_logic_vector(CDC_FIFO_WIDTH_CONST-1 downto 0);

begin

    assert CDC_FIFO_ADDR_W >= 7
        report "CDC_FIFO_ADDR_W must provide at least 128 entries for one header plus 64 payload words"
        severity failure;

    csr_staged_words_comb       <= prefix_count_func(csr_pack.page_valid);
    csr_required_words          <= required_words_func(csr.xfer_bytes);
    csr_len_valid               <= '1' when (to_integer(csr.xfer_bytes) >= 1 and to_integer(csr.xfer_bytes) <= 256) else '0';
    csr_page_ready              <= '1' when ((csr_len_valid = '1') and (csr_staged_words >= csr_required_words)) else '0';
    csr_ready                   <= not csr.resetting;
    csr_fault                   <= '1' when csr.err_flags /= ZERO_WORD_CONST else '0';
    csr_state_slv               <= state_to_slv_func(csr.state);
    csr_diag_summary(31 downto 24)
                                <= csr_state_slv;
    csr_diag_summary(23 downto 16)
                                <= std_logic_vector(to_unsigned(csr.queue_word_index, 8));
    csr_diag_summary(15)        <= csr.busy;
    csr_diag_summary(14)        <= csr.resetting;
    csr_diag_summary(13)        <= csr_page_ready;
    csr_diag_summary(12)        <= csr.flash_addr_valid;
    csr_diag_summary(11)        <= csr_len_valid;
    csr_diag_summary(10)        <= csr.queue_active;
    csr_diag_summary(9)         <= csr.queue_header;
    csr_diag_summary(8)         <= cdc_fifo_wrfull;
    csr_diag_summary(7 downto 1)
                                <= std_logic_vector(to_unsigned(csr_staged_words, 7));
    csr_diag_summary(0)         <= csr_fault;
    cdc_fifo_aclr               <= rsi_csr_reset or rsi_link_reset or csr_fifo_clear;

    avs_csr_waitrequest         <= csr_read_burst_active;
    avs_csr_readdata            <= csr_read_data;
    avs_csr_readdatavalid       <= csr_read_valid;

    gen_diag_disabled : if DEBUG_LEVEL = 0 generate
        coe_diag_summary       <= (others => '0');
        coe_diag_err_flags     <= (others => '0');
        coe_diag_last_error    <= (others => '0');
        coe_diag_max10_stat    <= (others => '0');
        coe_diag_max10_count   <= (others => '0');
    end generate gen_diag_disabled;

    gen_diag_enabled : if DEBUG_LEVEL /= 0 generate
        coe_diag_summary       <= csr_diag_summary;
        coe_diag_err_flags     <= csr.err_flags;
        coe_diag_last_error    <= csr.last_error;
        coe_diag_max10_stat    <= csr.max10_stat;
        coe_diag_max10_count   <= csr.max10_count;
    end generate gen_diag_enabled;

    queue_fifo : dcfifo
        generic map (
            intended_device_family => "Arria V",
            lpm_hint               => "RAM_BLOCK_TYPE=MLAB",
            lpm_numwords           => 2**CDC_FIFO_ADDR_W,
            lpm_showahead          => "ON",
            lpm_type               => "dcfifo",
            lpm_width              => CDC_FIFO_WIDTH_CONST,
            lpm_widthu             => CDC_FIFO_ADDR_W,
            overflow_checking      => "ON",
            rdsync_delaypipe       => 4,
            read_aclr_synch        => "ON",
            underflow_checking     => "ON",
            use_eab                => "ON",
            write_aclr_synch       => "ON",
            wrsync_delaypipe       => 4
        )
        port map (
            aclr    => cdc_fifo_aclr,
            data    => cdc_fifo_wrdata,
            rdclk   => csi_link_clk,
            rdreq   => cdc_fifo_rdreq,
            wrclk   => csi_csr_clk,
            wrreq   => cdc_fifo_wrreq,
            q       => cdc_fifo_q,
            rdempty => cdc_fifo_rdempty,
            rdfull  => open,
            wrempty => open,
            wrfull  => cdc_fifo_wrfull
        );

    link_master : entity work.max10_spi_split
        port map (
            csi_clk            => csi_link_clk,
            rsi_reset_n        => not rsi_link_reset,
            strobe             => link.cmd_strobe,
            addr               => link.cmd_addr,
            rw                 => link.cmd_rw,
            data_to_max        => link.cmd_data_to_max,
            numbytes           => link.cmd_numbytes,
            next_data          => link_spi_next_data,
            word_from_max      => link_spi_word_from_max,
            word_en            => link_spi_word_en,
            byte_from_max      => link_spi_byte_from_max,
            byte_en            => link_spi_byte_en,
            busy               => link_spi_busy,
            coe_spi_csn        => coe_max10_spi_csn,
            coe_spi_clk        => coe_max10_spi_clk,
            coe_spi_mosi_in    => coe_max10_spi_mosi_in,
            coe_spi_mosi_out   => coe_max10_spi_mosi_out,
            coe_spi_mosi_oe    => coe_max10_spi_mosi_oe,
            coe_spi_miso_in    => coe_max10_spi_miso_in,
            coe_spi_miso_out   => coe_max10_spi_miso_out,
            coe_spi_miso_oe    => coe_max10_spi_miso_oe,
            coe_spi_d1_in      => coe_max10_spi_d1_in,
            coe_spi_d1_out     => coe_max10_spi_d1_out,
            coe_spi_d1_oe      => coe_max10_spi_d1_oe,
            coe_spi_d2_in      => coe_max10_spi_d2_in,
            coe_spi_d2_out     => coe_max10_spi_d2_out,
            coe_spi_d2_oe      => coe_max10_spi_d2_oe,
            coe_spi_d3_in      => coe_max10_spi_d3_in,
            coe_spi_d3_out     => coe_max10_spi_d3_out,
            coe_spi_d3_oe      => coe_max10_spi_d3_oe
        );

    -- link_reg owns the downstream Arria-to-MAX10 FEBSPI link-domain engine.
    -- "link" is the committed link-domain register owner shared with other processes.
    -- "link_v" is the process-local scratch image used to derive the next committed link state.
    -- Hard reset reloads the full LINK_RESET_CONST image, while the RESETTING state performs
    -- a soft functional reset of the control subset and preserves retained boot/debug mirrors.
    link_reg : process (csi_link_clk, rsi_link_reset)
        variable link_v                 : link_var_t;
    begin
        if rsi_link_reset = '1' then
            link             <= LINK_RESET_CONST;
            cdc_fifo_rdreq   <= '0';
        elsif rising_edge(csi_link_clk) then
            link_v.reg                    := link;
            link_v.reg.launch_toggle_sync := link.launch_toggle_sync(1 downto 0) & csr.launch_toggle;
            link_v.reg.resetting_sync     := link.resetting_sync(1 downto 0) & csr.resetting;
            link_v.reg.boot_refresh_toggle_sync
                                         := link.boot_refresh_toggle_sync(1 downto 0) & csr.boot_refresh_toggle;
            link_v.reg.cmd_strobe         := '0';
            link_v.reg.busy_last          := link_spi_busy;
            cdc_fifo_rdreq            <= '0';
            link_v.reset_requested    := link.resetting_sync(2);
            link_v.must_drain         := (link.payload_started = '1') or (link.ctrl_start_issued = '1');

            if link_spi_busy = '1' then
                if link.txn_timeout_count < LINK_TRANSACTION_TIMEOUT_CONST then
                    link_v.reg.txn_timeout_count := link.txn_timeout_count + 1;
                end if;
            else
                link_v.reg.txn_timeout_count := 0;
            end if;

            if (link_spi_busy = '1') and (link.txn_timeout_count = LINK_TRANSACTION_TIMEOUT_CONST) then
                link_v.reg.err_flags(ERR_LINK_TIMEOUT_CONST) := '1';
                link_v.reg.err_code                          := std_logic_vector(to_unsigned(CODE_LINK_TIMEOUT_CONST, 8));
                if link.ctrl_start_issued = '1' then
                    link_v.reg.state                         := WRITINGCTRLSTOP;
                else
                    link_v.reg.state                         := RESETTING;
                end if;
            else
                case link.state is
                    when RESETTING =>
                        link_v.reg                    := link_soft_reset_func(link);
                        if link.resetting_sync(2) = '1' then
                            link_v.reg.state              := NOTIFYING;
                        else
                            link_v.reg.state              := STANDINGBY;
                        end if;

                    when STANDINGBY =>
                        if link_v.reset_requested = '1' then
                            link_v.reg.state          := RESETTING;
                        elsif link.boot_refresh_toggle_sync(2) /= link.boot_refresh_toggle_sync(1) then
                            link_v.reg.boot_word_index := 0;
                            link_v.reg.state           := READINGBOOTHISTINFO;
                        elsif link.launch_toggle_sync(2) /= link.launch_toggle_sync(1) then
                            link_v.reg.status_poll_count  := 0;
                            link_v.reg.txn_timeout_count  := 0;
                            link_v.reg.flash_busy         := '0';
                            link_v.reg.max10_stat         := ZERO_WORD_CONST;
                            link_v.reg.max10_count        := ZERO_WORD_CONST;
                            link_v.reg.err_flags          := ZERO_WORD_CONST;
                            link_v.reg.err_code           := std_logic_vector(to_unsigned(CODE_NONE_CONST, 8));
                            link_v.reg.payload_words_sent := 0;
                            link_v.reg.ctrl_start_issued  := '0';
                            link_v.reg.payload_started    := '0';
                            if (cdc_fifo_rdempty = '0') and (cdc_fifo_q(CDC_HEADER_FLAG_BIT_CONST) = '1') then
                                link_v.xfer_bytes           := unsigned(cdc_fifo_q(CDC_HEADER_XFER_MSB_CONST downto CDC_HEADER_XFER_LSB_CONST));
                                link_v.reg.launch_flash_addr
                                                             := cdc_fifo_q(23 downto 0);
                                link_v.reg.launch_xfer_bytes
                                                             := link_v.xfer_bytes;
                                link_v.reg.payload_words_total
                                                             := required_words_func(link_v.xfer_bytes);
                                cdc_fifo_rdreq         <= '1';
                                link_v.reg.state       := PRIMINGFIFO;
                            end if;
                        end if;

                    when PRIMINGFIFO =>
                        if (link_v.reset_requested = '1') and (not link_v.must_drain) then
                            link_v.reg.state          := RESETTING;
                        else
                            link_v.reg.state          := PUMPINGFIFO;
                        end if;

                    when PUMPINGFIFO =>
                        if (link_v.reset_requested = '1') and (not link_v.must_drain) then
                            link_v.reg.state          := RESETTING;
                        elsif cdc_fifo_rdempty = '0' then
                            link_v.reg.cmd_addr       := FEBSPI_ADDR_PROGRAMMING_WFIFO;
                            link_v.reg.cmd_numbytes   := std_logic_vector(link.launch_xfer_bytes);
                            link_v.reg.cmd_rw         := '1';
                            link_v.reg.cmd_data_to_max:= cdc_fifo_q(31 downto 0);
                            link_v.reg.cmd_strobe     := '1';
                            link_v.reg.payload_words_sent := 1;
                            link_v.reg.payload_started    := '1';
                            cdc_fifo_rdreq            <= '1';
                            link_v.reg.state          := WAITINGFIFO;
                        else
                            link_v.reg.err_flags(ERR_LINK_TIMEOUT_CONST) := '1';
                            link_v.reg.err_code                          := std_logic_vector(to_unsigned(CODE_LINK_TIMEOUT_CONST, 8));
                            link_v.reg.done_toggle                       := not link.done_toggle;
                            link_v.reg.state                             := STANDINGBY;
                        end if;

                    when WAITINGFIFO =>
                        if link_spi_next_data = '1' then
                            if link.payload_words_sent < link.payload_words_total then
                                if cdc_fifo_rdempty = '0' then
                                    link_v.reg.cmd_data_to_max    := cdc_fifo_q(31 downto 0);
                                    link_v.reg.payload_words_sent := link.payload_words_sent + 1;
                                    cdc_fifo_rdreq            <= '1';
                                else
                                    link_v.reg.err_flags(ERR_LINK_TIMEOUT_CONST) := '1';
                                    link_v.reg.err_code                          := std_logic_vector(to_unsigned(CODE_LINK_TIMEOUT_CONST, 8));
                                    link_v.reg.state                             := WRITINGCTRLSTOP;
                                end if;
                            end if;
                        end if;

                        if (link_spi_busy = '0') and (link.busy_last = '1') then
                            if (link_v.reset_requested = '1') and (not link_v.must_drain) then
                                link_v.reg.state      := RESETTING;
                            else
                                link_v.reg.cmd_addr       := FEBSPI_ADDR_PROGRAMMING_ADDR;
                                link_v.reg.cmd_numbytes   := std_logic_vector(to_unsigned(4, link.cmd_numbytes'length));
                                link_v.reg.cmd_rw         := '1';
                                link_v.reg.cmd_data_to_max:= x"00" & link.launch_flash_addr;
                                link_v.reg.cmd_strobe     := '1';
                                link_v.reg.state          := WRITINGADDR;
                            end if;
                        end if;

                    when WRITINGADDR =>
                        if (link_v.reset_requested = '1') and (not link_v.must_drain) then
                            link_v.reg.state          := RESETTING;
                        else
                            link_v.reg.state          := WAITINGADDR;
                        end if;

                    when WAITINGADDR =>
                        if (link_spi_busy = '0') and (link.busy_last = '1') then
                            if (link_v.reset_requested = '1') and (not link_v.must_drain) then
                                link_v.reg.state      := RESETTING;
                            else
                                link_v.reg.cmd_addr       := FEBSPI_ADDR_PROGRAMMING_CTRL;
                                link_v.reg.cmd_numbytes   := std_logic_vector(to_unsigned(4, link.cmd_numbytes'length));
                                link_v.reg.cmd_rw         := '1';
                                link_v.reg.cmd_data_to_max:= x"00000001";
                                link_v.reg.cmd_strobe     := '1';
                                link_v.reg.state          := WRITINGCTRLSTART;
                            end if;
                        end if;

                    when WRITINGCTRLSTART =>
                        if (link_v.reset_requested = '1') and (not link_v.must_drain) then
                            link_v.reg.state          := RESETTING;
                        else
                            link_v.reg.state          := WAITINGCTRLSTART;
                        end if;

                    when WAITINGCTRLSTART =>
                        if (link_spi_busy = '0') and (link.busy_last = '1') then
                            link_v.reg.ctrl_start_issued  := '1';
                            link_v.reg.status_poll_count  := 0;
                            link_v.reg.state              := READINGSTATUS;
                        end if;

                    when READINGSTATUS =>
                        link_v.reg.cmd_addr               := FEBSPI_ADDR_PROGRAMMING_STATUS;
                        link_v.reg.cmd_numbytes           := std_logic_vector(to_unsigned(4, link.cmd_numbytes'length));
                        link_v.reg.cmd_rw                 := '0';
                        link_v.reg.cmd_data_to_max        := ZERO_WORD_CONST;
                        link_v.reg.cmd_strobe             := '1';
                        link_v.reg.state                  := WAITINGSTATUSWORD;

                    when WAITINGSTATUSWORD =>
                        if link_spi_word_en = '1' then
                            link_v.reg.max10_stat         := link_spi_word_from_max;
                            link_v.reg.flash_busy         := link_spi_word_from_max(MAX10_STATUS_BIT_ARRIAWRITING_CONST);
                            link_v.reg.state              := WAITINGSTATUSDONE;
                        end if;

                    when WAITINGSTATUSDONE =>
                        if (link_spi_busy = '0') and (link.busy_last = '1') then
                            if link.flash_busy = '1' then
                                if link.status_poll_count < MAX10_STATUS_POLL_TIMEOUT_CONST then
                                    link_v.reg.status_poll_count := link.status_poll_count + 1;
                                    link_v.reg.state             := READINGSTATUS;
                                else
                                    link_v.reg.err_flags(ERR_MAX10_TIMEOUT_CONST) := '1';
                                    link_v.reg.err_code                           := std_logic_vector(to_unsigned(CODE_MAX10_TIMEOUT_CONST, 8));
                                    link_v.reg.state                              := WRITINGCTRLSTOP;
                                end if;
                            else
                                if link.max10_stat(MAX10_STATUS_BIT_TIMEOUT_CONST) = '1' then
                                    link_v.reg.err_flags(ERR_MAX10_TIMEOUT_CONST) := '1';
                                    link_v.reg.err_code                           := std_logic_vector(to_unsigned(CODE_MAX10_TIMEOUT_CONST, 8));
                                elsif link.max10_stat(MAX10_STATUS_BIT_CRCERROR_CONST) = '1' then
                                    link_v.reg.err_flags(ERR_MAX10_CRCERROR_CONST) := '1';
                                    link_v.reg.err_code                            := std_logic_vector(to_unsigned(CODE_MAX10_CRCERROR_CONST, 8));
                                elsif link.max10_stat(MAX10_STATUS_BIT_NSTATUS_CONST) = '0' then
                                    link_v.reg.err_flags(ERR_MAX10_NSTATUS_LOW_CONST) := '1';
                                    link_v.reg.err_code                              := std_logic_vector(to_unsigned(CODE_MAX10_NSTATUS_LOW_CONST, 8));
                                end if;
                                link_v.reg.state                := WRITINGCTRLSTOP;
                            end if;
                        end if;

                    when WRITINGCTRLSTOP =>
                        link_v.reg.cmd_addr               := FEBSPI_ADDR_PROGRAMMING_CTRL;
                        link_v.reg.cmd_numbytes           := std_logic_vector(to_unsigned(4, link.cmd_numbytes'length));
                        link_v.reg.cmd_rw                 := '1';
                        link_v.reg.cmd_data_to_max        := ZERO_WORD_CONST;
                        link_v.reg.cmd_strobe             := '1';
                        link_v.reg.state                  := WAITINGCTRLSTOP;

                    when WAITINGCTRLSTOP =>
                        if (link_spi_busy = '0') and (link.busy_last = '1') then
                            link_v.reg.ctrl_start_issued  := '0';
                            if link_v.reset_requested = '1' then
                                link_v.reg.state      := RESETTING;
                            else
                                link_v.reg.state      := READINGCOUNT;
                            end if;
                        end if;

                    when READINGCOUNT =>
                        if link_v.reset_requested = '1' then
                            link_v.reg.state          := RESETTING;
                        else
                            link_v.reg.cmd_addr           := FEBSPI_ADDR_PROGRAMMING_COUNT;
                            link_v.reg.cmd_numbytes       := std_logic_vector(to_unsigned(4, link.cmd_numbytes'length));
                            link_v.reg.cmd_rw             := '0';
                            link_v.reg.cmd_data_to_max    := ZERO_WORD_CONST;
                            link_v.reg.cmd_strobe         := '1';
                            link_v.reg.state              := WAITINGCOUNTWORD;
                        end if;

                    when WAITINGCOUNTWORD =>
                        if link_v.reset_requested = '1' then
                            link_v.reg.state          := RESETTING;
                        elsif link_spi_word_en = '1' then
                            link_v.reg.max10_count    := link_spi_word_from_max;
                            link_v.reg.state          := WAITINGCOUNTDONE;
                        end if;

                    when WAITINGCOUNTDONE =>
                        if link_v.reset_requested = '1' then
                            link_v.reg.state          := RESETTING;
                        elsif (link_spi_busy = '0') and (link.busy_last = '1') then
                            link_v.reg.state          := NOTIFYING;
                        end if;

                    when READINGBOOTHISTINFO =>
                        link_v.reg.cmd_addr               := FEBSPI_ADDR_BOOTHIST_INFO;
                        link_v.reg.cmd_numbytes           := std_logic_vector(to_unsigned(8, link.cmd_numbytes'length));
                        link_v.reg.cmd_rw                 := '0';
                        link_v.reg.cmd_data_to_max        := ZERO_WORD_CONST;
                        link_v.reg.cmd_strobe             := '1';
                        link_v.reg.boot_word_index        := 0;
                        link_v.reg.state                  := WAITINGBOOTHISTINFOWORD;

                    when WAITINGBOOTHISTINFOWORD =>
                        if link_spi_word_en = '1' then
                            if link.boot_word_index = 0 then
                                link_v.reg.boot_live_info  := link_spi_word_from_max;
                            else
                                link_v.reg.boot_persist_info := link_spi_word_from_max;
                            end if;
                            if link.boot_word_index < 1 then
                                link_v.reg.boot_word_index := link.boot_word_index + 1;
                            end if;
                        end if;
                        if (link_spi_busy = '0') and (link.busy_last = '1') then
                            link_v.reg.state          := READINGBOOTEVT0;
                        end if;

                    when READINGBOOTEVT0 =>
                        link_v.reg.cmd_addr               := FEBSPI_ADDR_BOOTHIST_EVT0;
                        link_v.reg.cmd_numbytes           := std_logic_vector(to_unsigned(24, link.cmd_numbytes'length));
                        link_v.reg.cmd_rw                 := '0';
                        link_v.reg.cmd_data_to_max        := ZERO_WORD_CONST;
                        link_v.reg.cmd_strobe             := '1';
                        link_v.reg.boot_word_index        := 0;
                        link_v.reg.state                  := WAITINGBOOTEVT0WORD;

                    when WAITINGBOOTEVT0WORD =>
                        if link_spi_word_en = '1' then
                            link_v.reg.boot_evt0_words(link.boot_word_index)
                                                         := link_spi_word_from_max;
                            if link.boot_word_index < 5 then
                                link_v.reg.boot_word_index := link.boot_word_index + 1;
                            end if;
                        end if;
                        if (link_spi_busy = '0') and (link.busy_last = '1') then
                            link_v.reg.state          := READINGBOOTEVT1;
                        end if;

                    when READINGBOOTEVT1 =>
                        link_v.reg.cmd_addr               := FEBSPI_ADDR_BOOTHIST_EVT1;
                        link_v.reg.cmd_numbytes           := std_logic_vector(to_unsigned(24, link.cmd_numbytes'length));
                        link_v.reg.cmd_rw                 := '0';
                        link_v.reg.cmd_data_to_max        := ZERO_WORD_CONST;
                        link_v.reg.cmd_strobe             := '1';
                        link_v.reg.boot_word_index        := 0;
                        link_v.reg.state                  := WAITINGBOOTEVT1WORD;

                    when WAITINGBOOTEVT1WORD =>
                        if link_spi_word_en = '1' then
                            link_v.reg.boot_evt1_words(link.boot_word_index)
                                                         := link_spi_word_from_max;
                            if link.boot_word_index < 5 then
                                link_v.reg.boot_word_index := link.boot_word_index + 1;
                            end if;
                        end if;
                        if (link_spi_busy = '0') and (link.busy_last = '1') then
                            link_v.reg.state          := READINGBOOTPERSIST;
                        end if;

                    when READINGBOOTPERSIST =>
                        link_v.reg.cmd_addr               := FEBSPI_ADDR_BOOTHIST_PERSIST;
                        link_v.reg.cmd_numbytes           := std_logic_vector(to_unsigned(24, link.cmd_numbytes'length));
                        link_v.reg.cmd_rw                 := '0';
                        link_v.reg.cmd_data_to_max        := ZERO_WORD_CONST;
                        link_v.reg.cmd_strobe             := '1';
                        link_v.reg.boot_word_index        := 0;
                        link_v.reg.state                  := WAITINGBOOTPERSISTWORD;

                    when WAITINGBOOTPERSISTWORD =>
                        if link_spi_word_en = '1' then
                            link_v.reg.boot_persist_words(link.boot_word_index)
                                                         := link_spi_word_from_max;
                            if link.boot_word_index < 5 then
                                link_v.reg.boot_word_index := link.boot_word_index + 1;
                            end if;
                        end if;
                        if (link_spi_busy = '0') and (link.busy_last = '1') then
                            link_v.reg.boot_done_toggle   := not link.boot_done_toggle;
                            link_v.reg.state              := STANDINGBY;
                        end if;

                    when NOTIFYING =>
                        link_v.reg.done_toggle            := not link.done_toggle;
                        link_v.reg.ctrl_start_issued      := '0';
                        link_v.reg.payload_started        := '0';
                        link_v.reg.state                  := STANDINGBY;
                end case;
            end if;

            link <= link_v.reg;
        end if;
    end process link_reg;

    -- csr_reg owns the CSR-domain software-visible state.
    -- The large page-storage arrays are kept in csr_pack so csr next-state updates
    -- do not drag the payload RAM through every record copy.
    csr_reg : process (csi_csr_clk, rsi_csr_reset)
        variable csr_v                      : csr_reg_t;
        variable csr_v_addr                 : natural;
        variable csr_v_page_index           : natural range 0 to 63;
        variable csr_v_error_event          : boolean;
        variable csr_v_page_ready_after     : std_logic;
        variable csr_v_addr_valid_after     : std_logic;
        variable csr_v_required_words       : natural range 0 to 64;
        variable csr_v_fifo_word            : std_logic_vector(CDC_FIFO_WIDTH_CONST-1 downto 0);
        variable csr_v_read_burst_count     : natural range 0 to 65535;
    begin
        if rsi_csr_reset = '1' then
            csr                   <= CSR_RESET_CONST;
            csr_pack              <= CSR_PACK_RESET_CONST;
            cdc_fifo_wrreq        <= '0';
            csr_fifo_clear        <= '0';
            csr_done_toggle_det   <= '0';
            csr_read_respond      <= '0';
            csr_read_addr_reg     <= (others => '0');
            csr_read_burst_active <= '0';
            csr_read_burst_addr   <= (others => '0');
            csr_read_burst_remaining
                                  <= 0;
            csr_page_ready_r      <= '0';
            csr_staged_words      <= 0;
            launch_copy_pending   <= '0';
        elsif rising_edge(csi_csr_clk) then
            csr_staged_words         <= csr_staged_words_comb;
            csr_page_ready_r         <= csr_page_ready;
            csr_done_toggle_det      <= csr.done_toggle_sync(2) xor csr.done_toggle_sync(1); -- Pre-register the toggle detect; used one cycle later to break combo path from sync chain through state machine.
            csr_v                    := csr;
            csr_v.done_toggle_sync   := csr.done_toggle_sync(1 downto 0) & link.done_toggle;
            csr_v.boot_done_toggle_sync
                                     := csr.boot_done_toggle_sync(1 downto 0) & link.boot_done_toggle;
            cdc_fifo_wrreq           <= '0';
            csr_fifo_clear           <= '0';
            csr_read_respond         <= '0'; -- default: no decode this cycle
            launch_copy_pending      <= '0'; -- one-shot: will be re-armed below if a validated START arrives

            -- One cycle after a START command is validated, perform the bulk
            -- launch_page_data <= page_data copy. This turns the launch_page_data
            -- |sload enable into a single-flop compare (launch_copy_pending) instead
            -- of a 6-LUT cone on address + state + xfer_bytes + page_ready decode.
            if launch_copy_pending = '1' then
                csr_pack.launch_page_data <= csr_pack.page_data;
            end if;

            -- Stage 1: register the read address and arm the respond flag for
            -- the next cycle. The bank decode + stage-1.5 flops live in the
            -- dedicated csr_rd_pipe process below. Burst continuation takes
            -- priority since waitrequest blocks new requests while a burst
            -- is active.
            if csr_read_burst_active = '1' then
                csr_read_addr_reg    <= std_logic_vector(csr_read_burst_addr);
                csr_read_respond     <= '1';
                if csr_read_burst_remaining > 1 then
                    csr_read_burst_remaining
                                          <= csr_read_burst_remaining - 1;
                    csr_read_burst_addr
                                          <= csr_read_burst_addr + 1;
                else
                    csr_read_burst_remaining
                                          <= 0;
                    csr_read_burst_active
                                          <= '0';
                end if;
            elsif avs_csr_read = '1' then
                csr_v_read_burst_count := to_integer(unsigned(avs_csr_burstcount));
                if csr_v_read_burst_count = 0 then
                    csr_v_read_burst_count := 1;
                end if;

                csr_read_addr_reg    <= avs_csr_address;
                csr_read_respond     <= '1';
                if csr_v_read_burst_count > 1 then
                    csr_read_burst_active
                                          <= '1';
                    csr_read_burst_addr
                                          <= unsigned(avs_csr_address) + 1;
                    csr_read_burst_remaining
                                          <= csr_v_read_burst_count - 1;
                else
                    csr_read_burst_active
                                          <= '0';
                    csr_read_burst_remaining
                                          <= 0;
                end if;
            end if;

            if csr_done_toggle_det = '1' then -- Uses registered detect (one cycle after sync[2] /= sync[1]) to break timing path from sync chain through state machine.
                if csr.resetting = '1' then
                    csr_v                       := sw_reset_image_func(csr);
                    csr_v.last_error(7 downto 0)
                                                := std_logic_vector(to_unsigned(CODE_ABORTED_SW_RESET_CONST, 8));
                    csr_v.last_error(15 downto 8)
                                                := state_to_slv_func(ABORTING);
                    csr_v.state                 := ABORTING;
                    csr_pack                    <= CSR_PACK_RESET_CONST;
                    csr_fifo_clear              <= '1';
                else
                    csr_v.busy                  := '0';
                    csr_v.launch_done           := '1';
                    csr_v.max10_stat            := link.max10_stat;
                    csr_v.max10_count           := link.max10_count;
                    if link.err_flags /= ZERO_WORD_CONST then
                        csr_v.err_flags          := csr.err_flags or link.err_flags;
                        csr_v.last_error(7 downto 0)
                                                    := link.err_code;
                        csr_v.last_error(15 downto 8)
                                                    := state_to_slv_func(ABORTING);
                        csr_v.last_error(23 downto 16)
                                                    := std_logic_vector(to_unsigned(csr_staged_words, 8));
                        csr_v.last_error(31 downto 24)
                                                    := link.max10_stat(31 downto 24);
                        csr_v.state              := ABORTING;
                        if csr.err_count /= ERR_COUNT_MAX_CONST then
                            csr_v.err_count       := csr.err_count + 1;
                        end if;
                    else
                        csr_v.state              := COMPLETING;
                    end if;
                end if;
            elsif csr.busy = '0' then
                csr_v.state              := IDLING;
            end if;

            if csr.boot_done_toggle_sync(2) /= csr.boot_done_toggle_sync(1) then
                csr_v.boot_live_info      := link.boot_live_info;
                csr_v.boot_persist_info   := link.boot_persist_info;
                csr_v.boot_evt0_words     := link.boot_evt0_words;
                csr_v.boot_evt1_words     := link.boot_evt1_words;
                csr_v.boot_persist_words  := link.boot_persist_words;
                csr_v.boot_refresh_busy   := '0';
            elsif (csr.busy = '0') and (csr.boot_refresh_busy = '0') and (csr.boot_auto_refresh_armed = '1') then
                csr_v.boot_refresh_busy   := '1';
                csr_v.boot_auto_refresh_armed
                                         := '0';
                csr_v.boot_refresh_toggle := not csr.boot_refresh_toggle;
            end if;

            if avs_csr_write = '1' then
                csr_v_addr            := to_integer(unsigned(avs_csr_address));
                csr_v_error_event     := false;

                case csr_v_addr is
                    when REG_CTRL_CONST =>
                        if avs_csr_writedata(0) = '1' then
                            if (csr.busy = '1') and (csr.queue_active = '0') then
                                csr_v.resetting               := '1';
                                csr_v.flash_addr              := (others => '0');
                                csr_v.flash_addr_valid        := '0';
                                csr_v.xfer_bytes              := XFER_BYTES_RESET_CONST;
                                csr_v.launch_accepted         := '0';
                                csr_v.launch_done             := '0';
                                csr_v.queue_active            := '0';
                                csr_v.queue_header            := '0';
                                csr_v.queue_word_index        := 0;
                                csr_v.last_error(7 downto 0)  := std_logic_vector(to_unsigned(CODE_ABORTED_SW_RESET_CONST, 8));
                                csr_v.last_error(15 downto 8) := state_to_slv_func(ABORTING);
                                csr_v.state                   := ABORTING;
                                csr_pack                      <= CSR_PACK_RESET_CONST;
                            else
                                csr_v                         := sw_reset_image_func(csr);
                                csr_v.last_error(7 downto 0)  := std_logic_vector(to_unsigned(CODE_ABORTED_SW_RESET_CONST, 8));
                                csr_v.last_error(15 downto 8) := state_to_slv_func(ABORTING);
                                csr_v.state                   := ABORTING;
                                csr_pack                      <= CSR_PACK_RESET_CONST;
                                csr_fifo_clear                <= '1';
                            end if;
                        end if;

                    when REG_ERR_FLAGS_CONST =>
                        csr_v.err_flags                    := csr.err_flags and not avs_csr_writedata;

                    when REG_SCRATCH_CONST =>
                        csr_v.scratch                      := avs_csr_writedata;

                    when REG_FLASH_ADDR_CONST =>
                        csr_v.flash_addr                   := avs_csr_writedata(23 downto 0);
                        csr_v.flash_addr_valid             := '1';

                    when REG_XFER_BYTES_CONST =>
                        csr_v.xfer_bytes                   := unsigned(avs_csr_writedata(8 downto 0));

                    when REG_PROG_CTRL_CONST =>
                        if avs_csr_writedata(1) = '1' then
                            csr_pack.page_data             <= PAGE_MEM_RESET_CONST;
                            csr_pack.page_valid            <= PAGE_VALID_RESET_CONST;
                        end if;

                        if avs_csr_writedata(2) = '1' then
                            csr_v.launch_accepted          := '0';
                            csr_v.launch_done              := '0';
                            csr_v.last_error               := (others => '0');
                        end if;

                        if avs_csr_writedata(3) = '1' then
                            csr_v.flash_addr               := (others => '0');
                            csr_v.flash_addr_valid         := '0';
                        end if;

                        if avs_csr_writedata(0) = '1' then
                            csr_v_page_ready_after         := csr_page_ready_r; -- Use registered copy to break prefix_count_func combinational path.
                            if avs_csr_writedata(1) = '1' then
                                csr_v_page_ready_after     := '0';
                            end if;

                            csr_v_addr_valid_after         := csr.flash_addr_valid;
                            if avs_csr_writedata(3) = '1' then
                                csr_v_addr_valid_after     := '0';
                            end if;

                            if csr.busy = '1' then
                                record_error_proc(
                                    err_bit          => ERR_START_WHILE_BUSY_CONST,
                                    err_code         => CODE_START_WHILE_BUSY_CONST,
                                    state_value      => csr.state,
                                    staged_words     => csr_staged_words,
                                    max10_debug      => csr.max10_stat(31 downto 24),
                                    err_flags_v      => csr_v.err_flags,
                                    last_error_v     => csr_v.last_error,
                                    error_event_v    => csr_v_error_event
                                );
                            elsif csr.resetting = '1' then
                                record_error_proc(
                                    err_bit          => ERR_START_DURING_RESET_CONST,
                                    err_code         => CODE_START_DURING_RESET_CONST,
                                    state_value      => csr.state,
                                    staged_words     => csr_staged_words,
                                    max10_debug      => csr.max10_stat(31 downto 24),
                                    err_flags_v      => csr_v.err_flags,
                                    last_error_v     => csr_v.last_error,
                                    error_event_v    => csr_v_error_event
                                );
                            elsif csr_v_addr_valid_after = '0' then
                                record_error_proc(
                                    err_bit          => ERR_ADDR_MISSING_CONST,
                                    err_code         => CODE_ADDR_MISSING_CONST,
                                    state_value      => csr.state,
                                    staged_words     => csr_staged_words,
                                    max10_debug      => csr.max10_stat(31 downto 24),
                                    err_flags_v      => csr_v.err_flags,
                                    last_error_v     => csr_v.last_error,
                                    error_event_v    => csr_v_error_event
                                );
                            elsif to_integer(csr.xfer_bytes) = 0 then
                                record_error_proc(
                                    err_bit          => ERR_XFER_BYTES_ZERO_CONST,
                                    err_code         => CODE_XFER_BYTES_ZERO_CONST,
                                    state_value      => csr.state,
                                    staged_words     => csr_staged_words,
                                    max10_debug      => csr.max10_stat(31 downto 24),
                                    err_flags_v      => csr_v.err_flags,
                                    last_error_v     => csr_v.last_error,
                                    error_event_v    => csr_v_error_event
                                );
                            elsif to_integer(csr.xfer_bytes) > 256 then
                                record_error_proc(
                                    err_bit          => ERR_XFER_BYTES_GT_256_CONST,
                                    err_code         => CODE_XFER_BYTES_GT_256_CONST,
                                    state_value      => csr.state,
                                    staged_words     => csr_staged_words,
                                    max10_debug      => csr.max10_stat(31 downto 24),
                                    err_flags_v      => csr_v.err_flags,
                                    last_error_v     => csr_v.last_error,
                                    error_event_v    => csr_v_error_event
                                );
                            elsif csr_v_page_ready_after = '0' then
                                record_error_proc(
                                    err_bit          => ERR_PAGE_UNDERRUN_CONST,
                                    err_code         => CODE_PAGE_UNDERRUN_CONST,
                                    state_value      => csr.state,
                                    staged_words     => csr_staged_words,
                                    max10_debug      => csr.max10_stat(31 downto 24),
                                    err_flags_v      => csr_v.err_flags,
                                    last_error_v     => csr_v.last_error,
                                    error_event_v    => csr_v_error_event
                                );
                            else
                                csr_v.busy                     := '1';
                                csr_v.launch_accepted          := '1';
                                csr_v.launch_done              := '0';
                                csr_v.state                    := LAUNCHING;
                                csr_v.launch_flash_addr        := csr.flash_addr;
                                csr_v.launch_xfer_bytes        := csr.xfer_bytes;
                                csr_v.queue_active             := '1';
                                csr_v.queue_header             := '1';
                                csr_v.queue_word_index         := 0;
                                launch_copy_pending            <= '1';
                            end if;
                        end if;

                        if csr_v_error_event and (csr.err_count /= ERR_COUNT_MAX_CONST) then
                            csr_v.err_count                  := csr.err_count + 1;
                        end if;

                    when REG_BOOT_HIST_CTRL_CONST =>
                        if (avs_csr_writedata(0) = '1') and (csr.busy = '0') and (csr.boot_refresh_busy = '0') then
                            csr_v.boot_refresh_busy         := '1';
                            csr_v.boot_refresh_toggle       := not csr.boot_refresh_toggle;
                        end if;

                    when REG_PAGE_DATA_BASE_CONST to REG_PAGE_DATA_LAST_CONST =>
                        csr_v_page_index                    := csr_v_addr - REG_PAGE_DATA_BASE_CONST;
                        csr_pack.page_data(csr_v_page_index)
                                                     <= avs_csr_writedata;
                        csr_pack.page_valid(csr_v_page_index)
                                                     <= '1';

                    when others =>
                        null;
                end case;
            end if;

            -- Queue drain: push header + payload words into the CDC FIFO,
            -- then toggle launch_toggle to signal the link domain.
            -- All reads use registered signals (csr.*), not the variable
            -- (csr_v.*), to break false combinational paths from the AVMM
            -- write handler and done-toggle handler.  Safe because when
            -- csr.queue_active = '1', no earlier code path in this process
            -- modifies queue_header, queue_word_index, launch_flash_addr,
            -- or launch_xfer_bytes (mutual exclusion with START validation
            -- and sw_reset, both of which require csr.busy = '0' or
            -- csr.queue_active = '0').
            if (csr.queue_active = '1') and (csr.resetting = '0') then
                csr_v_required_words := required_words_func(csr.launch_xfer_bytes);
                if cdc_fifo_wrfull = '0' then
                    if csr.queue_header = '1' then
                        csr_v_fifo_word       := cdc_header_word_func(csr.launch_flash_addr, csr.launch_xfer_bytes);
                        cdc_fifo_wrdata       <= csr_v_fifo_word;
                        cdc_fifo_wrreq        <= '1';
                        csr_v.queue_header    := '0';
                    else
                        csr_v_fifo_word       := (others => '0');
                        csr_v_fifo_word(31 downto 0)
                                               := csr_pack.launch_page_data(csr.queue_word_index);
                        cdc_fifo_wrdata       <= csr_v_fifo_word;
                        cdc_fifo_wrreq        <= '1';
                        if csr.queue_word_index + 1 >= csr_v_required_words then
                            csr_v.queue_active := '0';
                            csr_v.launch_toggle
                                               := not csr.launch_toggle;
                        else
                            csr_v.queue_word_index
                                               := csr.queue_word_index + 1;
                        end if;
                    end if;
                end if;
            end if;

            csr <= csr_v;
        end if;
    end process csr_reg;

    -- csr_rd_banks is the pure CSR readback bank decoder. It owns no state.
    -- Each bank evaluates a narrow range of the CSR address space and outputs
    -- zero outside its range, so stage 2 can compute csr_read_data as a simple
    -- 3-way OR of the flopped bank words. See the Slow-85C setup closure note
    -- in the signal-declaration section above.
    csr_rd_banks : process (all)
        variable addr              : natural;
        variable data_ctrl_v       : word_t;
        variable data_page_v       : word_t;
        variable data_boot_v       : word_t;
        variable status_v          : word_t;
        variable prog_status_v     : word_t;
    begin
        addr               := to_integer(unsigned(csr_read_addr_reg));
        data_ctrl_v        := (others => '0');
        data_page_v        := (others => '0');
        data_boot_v        := (others => '0');

        status_v           := (others => '0');
        status_v(0)        := csr_ready;
        status_v(1)        := csr.busy;
        status_v(2)        := csr_fault;
        status_v(3)        := csr.resetting;

        prog_status_v                := (others => '0');
        prog_status_v(0)             := csr_ready;
        prog_status_v(1)             := csr.busy;
        prog_status_v(2)             := csr_page_ready;
        prog_status_v(3)             := csr.flash_addr_valid;
        prog_status_v(4)             := csr_len_valid;
        prog_status_v(5)             := csr.busy;
        prog_status_v(6)             := csr.launch_accepted;
        prog_status_v(7)             := csr.launch_done;
        prog_status_v(8)             := csr.max10_stat(MAX10_STATUS_BIT_ARRIAWRITING_CONST);
        prog_status_v(9)             := csr.max10_stat(MAX10_STATUS_BIT_SPI_BUSY_CONST);
        prog_status_v(10)            := csr.max10_stat(MAX10_STATUS_BIT_FIFO_EMPTY_CONST);
        prog_status_v(11)            := csr.max10_stat(MAX10_STATUS_BIT_FIFO_FULL_CONST);
        prog_status_v(12)            := csr.max10_stat(MAX10_STATUS_BIT_CONF_DONE_CONST);
        prog_status_v(13)            := csr.max10_stat(MAX10_STATUS_BIT_NSTATUS_CONST);
        prog_status_v(14)            := csr.max10_stat(MAX10_STATUS_BIT_TIMEOUT_CONST);
        prog_status_v(15)            := csr.max10_stat(MAX10_STATUS_BIT_CRCERROR_CONST);
        prog_status_v(23 downto 16)  := csr_state_slv;

        -- Bank 0 — identity, control, status, error, flash, xfer, max10,
        -- last_error. Range 0x000..0x00E. Narrow 15-way mux; zero outside.
        case addr is
            when REG_ID_CONST =>
                data_ctrl_v                 := IP_ID_CONST;
            when REG_VERSION_CONST =>
                data_ctrl_v                 := pack_version_func(VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH, BUILD);
            when REG_CTRL_CONST =>
                data_ctrl_v(0)              := csr.resetting;
            when REG_STATUS_CONST =>
                data_ctrl_v                 := status_v;
            when REG_ERR_FLAGS_CONST =>
                data_ctrl_v                 := csr.err_flags;
            when REG_ERR_COUNT_CONST =>
                data_ctrl_v                 := std_logic_vector(csr.err_count);
            when REG_SCRATCH_CONST =>
                data_ctrl_v                 := csr.scratch;
            when REG_FLASH_ADDR_CONST =>
                data_ctrl_v(23 downto 0)    := csr.flash_addr;
            when REG_XFER_BYTES_CONST =>
                data_ctrl_v(8 downto 0)     := std_logic_vector(csr.xfer_bytes);
            when REG_PROG_CTRL_CONST =>
                data_ctrl_v                 := (others => '0');
            when REG_PROG_STATUS_CONST =>
                data_ctrl_v                 := prog_status_v;
            when REG_STAGED_WORDS_CONST =>
                data_ctrl_v(6 downto 0)     := std_logic_vector(to_unsigned(csr_staged_words, 7));
            when REG_MAX10_STAT_CONST =>
                data_ctrl_v                 := csr.max10_stat;
            when REG_MAX10_COUNT_CONST =>
                data_ctrl_v                 := csr.max10_count;
            when REG_LAST_ERROR_CONST =>
                data_ctrl_v                 := csr.last_error;
            when others =>
                data_ctrl_v                 := (others => '0');
        end case;

        -- Bank 1 — page_data (64-entry indexed mux). Range 0x020..0x05F.
        if (addr >= REG_PAGE_DATA_BASE_CONST) and (addr <= REG_PAGE_DATA_LAST_CONST) then
            data_page_v                     := csr_pack.page_data(addr - REG_PAGE_DATA_BASE_CONST);
        end if;

        -- Bank 2 — boot-history control, live info, evt0/evt1/persist words.
        -- Range 0x060..0x074. Narrow mux; zero outside.
        case addr is
            when REG_BOOT_HIST_CTRL_CONST =>
                data_boot_v(0)              := csr.boot_refresh_busy;
                data_boot_v(1)              := csr.boot_auto_refresh_armed;
            when REG_BOOT_LIVE_INFO_CONST =>
                data_boot_v                 := csr.boot_live_info;
            when REG_BOOT_EVT0_BASE_CONST to REG_BOOT_EVT0_LAST_CONST =>
                data_boot_v                 := csr.boot_evt0_words(addr - REG_BOOT_EVT0_BASE_CONST);
            when REG_BOOT_EVT1_BASE_CONST to REG_BOOT_EVT1_LAST_CONST =>
                data_boot_v                 := csr.boot_evt1_words(addr - REG_BOOT_EVT1_BASE_CONST);
            when REG_BOOT_PERSIST_INFO_CONST =>
                data_boot_v                 := csr.boot_persist_info;
            when REG_BOOT_PERSIST_BASE_CONST to REG_BOOT_PERSIST_LAST_CONST =>
                data_boot_v                 := csr.boot_persist_words(addr - REG_BOOT_PERSIST_BASE_CONST);
            when others =>
                data_boot_v                 := (others => '0');
        end case;

        csr_bank_ctrl_comb                  <= data_ctrl_v;
        csr_bank_page_comb                  <= data_page_v;
        csr_bank_boot_comb                  <= data_boot_v;
    end process csr_rd_banks;

    -- csr_rd_pipe owns the two CSR-readback flop stages: stage 1.5 captures
    -- the three narrow bank decodes, stage 2 OR-reduces them into
    -- csr_read_data and asserts csr_read_valid. Decoupled from csr_reg so the
    -- readback data path does not share an sclr cone with the programming FSM.
    csr_rd_pipe : process (csi_csr_clk, rsi_csr_reset)
    begin
        if rsi_csr_reset = '1' then
            csr_bank_ctrl_r               <= (others => '0');
            csr_bank_page_r               <= (others => '0');
            csr_bank_boot_r               <= (others => '0');
            csr_read_respond_r             <= '0';
            csr_read_data                   <= (others => '0');
            csr_read_valid                  <= '0';
        elsif rising_edge(csi_csr_clk) then
            -- Stage 1.5 — flop the three narrow bank decode outputs and the
            -- delayed respond flag. The stage-1 addr flop in csr_reg is the
            -- sole arrival driver into this cone.
            csr_bank_ctrl_r               <= csr_bank_ctrl_comb;
            csr_bank_page_r               <= csr_bank_page_comb;
            csr_bank_boot_r               <= csr_bank_boot_comb;
            csr_read_respond_r             <= csr_read_respond;

            -- Stage 2 — shallow OR-reduce. Each bank output was zero outside
            -- its range, so a straight OR is sufficient; no hit-bit masking.
            csr_read_data                   <= csr_bank_ctrl_r
                                            or csr_bank_page_r
                                            or csr_bank_boot_r;
            csr_read_valid                  <= csr_read_respond_r;
        end if;
    end process csr_rd_pipe;

end architecture rtl;
