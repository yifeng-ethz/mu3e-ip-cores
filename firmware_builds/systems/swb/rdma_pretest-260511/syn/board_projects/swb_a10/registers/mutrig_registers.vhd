-- Register Map
-- Note: 
-- write register, use naming scheme:       ***_REGISTER_W
-- read  register, use naming scheme:       ***_REGISTER_R
-- bit range     , use naming scheme:       ***_RANGE
-- single bit constant, use naming scheme:  ***_BIT

-- M.Mueller, Nov 2021

library ieee;
use ieee.std_logic_1164.all;

package mutrig_registers is

--////////////////////////////////////////////--
--//////////////////REGISTER MAP//////////////--
--////////////////////////////////////////////--
    -- update here if change in address spaces
    -- https://bitbucket.org/mu3e/online/wiki/Slowcontrol%20for%20the%20FEBs


-----------------------------------------------------------------
---- mutrig counters --------------------------------------------
-----------------------------------------------------------------
    -- counters per ASIC -- for now we researve 16 x 64 registers 0x4100-0x44FF
    -- for addr = i
    --  0 : ASIC ID
    --  1 : DEBUG
    --  2 : DEBUG
    --  3 : s_eventcounter
    --  4 : s_timecounter low
    --  5 : s_timecounter high
    --  6 : s_crcerrorcounter
    --  7 : s_framecounter
    --  8 : channel rate 0
    --  9 : channel rate 1
    -- ...
    -- 39 : channel rate 31
    -- 40 - 53: empty
    -- 54 : pll_test low
    -- 55 : pll_test high
    -- 56 : SORTER 0 IN 0
    -- 57 : SORTER 0 IN 1
    -- 58 : SORTER 1 IN 0
    -- 59 : SORTER 1 IN 1
    -- 60 - 63: empty

    constant MUTRIG_CNT_ADDR_REGISTER_R             : integer := 16#4100#;

-----------------------------------------------------------------
---- mutrig register --------------------------------------------
-----------------------------------------------------------------
    -- TMP
    constant MUTRIG_MON_STATUS_REGISTER_R           :   integer := 16#4500#;
    constant MUTRIG_MON_TEMPERATURE_REGISTER_W      :   integer := 16#4501#;

    -- ctrl
    constant MUTRIG_CNT_CTRL_REGISTER_W             :   integer := 16#4502#;
        constant SECOND_SORTER_CNT_BIT              :   integer := 31;
    constant MUTRIG_CTRL_DUMMY_REGISTER_W           :   integer := 16#4503#;
    -- TODO: Name single bits according to this:
    --        printf("dummyctrl_reg:    0x%08X\n", regs.ctrl.dummy);
    --        printf("    :cfgdummy_en  0x%X\n", (regs.ctrl.dummy>>0)&1);
    --        printf("    :datagen_en   0x%X\n", (regs.ctrl.dummy>>1)&1);
    --        printf("    :datagen_fast 0x%X\n", (regs.ctrl.dummy>>2)&1);
    --        printf("    :datagen_cnt  0x%X\n", (regs.ctrl.dummy>>3)&0x3ff);
    constant MUTRIG_CTRL_DP_REGISTER_W              :   integer := 16#4504#;
    constant MUTRIG_CTRL_RESET_REGISTER_W           :   integer := 16#4505#;
    constant MUTRIG_CTRL_RESETDELAY_REGISTER_W      :   integer := 16#4506#;
    constant MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W   :   integer := 16#4507#;
    constant MUTRIG_CTRL_LAPSE_DELAY_W              :   integer := 16#4508#;
    constant MUTRIG_CTRL_ENERGY_REGISTER_W          :   integer := 16#4509#;

end package;
