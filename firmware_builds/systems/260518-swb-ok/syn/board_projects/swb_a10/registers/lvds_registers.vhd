--

library ieee;
use ieee.std_logic_1164.all;

package lvds_registers is

    type lvds_status_t is record
        disperr         :   std_logic_vector(31 downto 0);
        err8b10b        :   std_logic_vector(31 downto 0);
        hitcnt          :   std_logic_vector(31 downto 0);
        pll_locked      :   std_logic;
        ready           :   std_logic;
        dpa_locked      :   std_logic;
        aligncnt        :   std_logic_vector(5 downto 0);
        arrival_phase   :   std_logic_vector(1 downto 0);
        out_of_phase_cnt:   std_logic_vector(15 downto 0);
    end record;
    constant LVDS_ZERO : lvds_status_t := (
        disperr => (others => '0'),
        err8b10b => (others => '0'),
        hitcnt => (others => '0'),
        pll_locked => '0',
        ready  => '0',
        dpa_locked => '0',
        aligncnt => (others => '0'),
        arrival_phase => (others => '0'),
        out_of_phase_cnt => (others => '0')
    );
    type lvds_status_array_t is array (natural range <>) of lvds_status_t;


-----------------------------------------------------------------
---- lvds rx (0x1100-0x11FF)-------------------------------
-----------------------------------------------------------------

    -- for now we go with two because of the addr space
    constant LVDS_STATUS_REGISTER_R          :  integer := 16#4101#;       -- DOC: nonincrementing read of lvds status register block, 1 Word for each lvds link from here on | FEB mutrig
    constant LVDS_STATUS_START_REGISTER_W    :  integer := 16#1100#;       -- DOC: start of lvds status register block, 1 Word for each lvds link from here on | FEB
        constant LVDS_STATUS_PLL_LOCKED_BIT  :  integer := 31;             -- DOC: PLL locked bit in each lvds status register | FEB
        constant LVDS_STATUS_READY_BIT       :  integer := 30;             -- DOC: if set: this lvds link is locked and ready | FEB
        constant LVDS_STATUS_DPA_LOCKED_BIT  :  integer := 29;             -- DOC: if set: this links dpa is locked | FEB
        subtype  LVDS_STATUS_ALIGN_CNT_RANGE     is integer range 27 downto 22; -- DOC: counts how often the aligner has shifted the link | FEB
        subtype  LVDS_STATUS_ARRIVAL_PHASE_RANGE is integer range 21 downto 20; -- DOC: Phase of hit arrival | FEB
        subtype  LVDS_STATUS_OUTOF_PHASE_RANGE   is integer range 15 downto 0;  -- DOC: counts how often the hit arrival time is not in the same 4 cycle phase | FEB

end package;
