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
---- mutrig_registers---------------------------------------------
-----------------------------------------------------------------
    -- counters
    constant MUTRIG_CNT_CTRL_REGISTER_W          :   integer := 16#4100#;
    constant MUTRIG_CNT_VALUE_REGISTER_R         :   integer := 16#4101#;
    constant MUTRIG_CNT_ADDR_REGISTER_W          :   integer := 16#4102#;

    -- RX status
    constant MUTRIG_RX_STATUS_REGISTER_R         :   integer := 16#4103#;
    constant MUTRIG_MON_STATUS_REGISTER_R        :   integer := 16#4104#;
    constant MUTRIG_MON_TEMPERATURE_REGISTER_W   :   integer := 16#4105#;

    -- ctrl
    constant MUTRIG_CTRL_DUMMY_REGISTER_W        :   integer := 16#4106#;
    -- TODO: Name single bits according to this:
    --        printf("dummyctrl_reg:    0x%08X\n", regs.ctrl.dummy);
    --        printf("    :cfgdummy_en  0x%X\n", (regs.ctrl.dummy>>0)&1);
    --        printf("    :datagen_en   0x%X\n", (regs.ctrl.dummy>>1)&1);
    --        printf("    :datagen_fast 0x%X\n", (regs.ctrl.dummy>>2)&1);
    --        printf("    :datagen_cnt  0x%X\n", (regs.ctrl.dummy>>3)&0x3ff);
    constant MUTRIG_CTRL_DP_REGISTER_W           :   integer := 16#4107#;
    constant MUTRIG_CTRL_RESET_REGISTER_W        :   integer := 16#4108#;
    constant MUTRIG_CTRL_RESETDELAY_REGISTER_W   :   integer := 16#4109#;

    -- lapse counting
    constant MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W   :   integer := 16#410A#;

    -- data debug paths
    constant MUTRIG_DEBUG_PATH_REGISTER_W           :   integer := 16#410B#;

    -- ch rate register (times 128 at the moment)
    constant MUTRIG_CH_CTRL_REGISTER_R              :   integer := 16#410C#;
    constant MUTRIG_CH_RATE_REGISTER_R              :   integer := 16#410D#;
    constant IS_MUTRIG3_REGISTER_W                  :   integer := 16#410E#;

-----------------------------------------------------------------
---- mutrig sorter (0x4000-0x4100)--------------------------------
-----------------------------------------------------------------

    constant MT_SORTER_COUNTER_REGISTER_R           :  integer := 16#4000#;       -- DOC: Hit counters in the sorter, 40 32 bit counters in total. For the inner pixel FEBs: 12 counters with in-time hits per chip, 12 counters with out-of-time hits per chip, 12 counters with overflows per chip, a counter with the number of output hits and the current credit value. The last two counters are currently reserved for future use | MP_FEB
    constant MT_SORTER_NINTIME_REGISTER_R           :  integer := 16#4000#;
    constant MT_SORTER_NOUTOFTIME_REGISTER_R        :  integer := 16#400C#;
    constant MT_SORTER_NOVERFLOW_REGISTER_R         :  integer := 16#4018#;
    constant MT_SORTER_NOUT_REGISTER_R              :  integer := 16#4024#;
    constant MT_SORTER_CREDIT_REGISTER_R            :  integer := 16#4025#;
    constant MT_SORTER_DELAY_REGISTER_W             :  integer := 16#4028#;       -- DOC: Minimum round-trip delay from sync reset going off to hit with TS > 0 appearing at sorter input in 8 ns steps | MP_FEB

end package;
