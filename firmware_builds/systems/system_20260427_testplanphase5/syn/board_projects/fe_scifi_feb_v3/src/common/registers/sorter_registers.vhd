

library ieee;
use ieee.std_logic_1164.all;

package sorter_registers is

    constant SORTER_COUNTER_REGISTER_R           :  integer := 16#4000#;       -- DOC: Diagnostic counters in the sorter Hit counters in the sorter
    constant SORTER_NINTIME_REGISTER_R           :  integer := 16#4000#;       -- DOC: Counters for in-time hits in the sorter, one for each sorter input
    constant SORTER_NOUTOFTIME_REGISTER_R        :  integer := 16#400C#;       -- DOC: Counters for out-of-time hits in the sorter, one for each sorter input
    constant SORTER_NOVERFLOW_REGISTER_R         :  integer := 16#4018#;       -- DOC: Counters for overflows in the sorter, one for each sorter input
    constant SORTER_NOUT_REGISTER_R              :  integer := 16#4024#;       -- DOC: Counter for hits leaving the sorter
    constant SORTER_CREDIT_REGISTER_R            :  integer := 16#4025#;       -- DOC: Current value of the sorter credits
    constant SORTER_DELAY_REGISTER_W             :  integer := 16#4028#;       -- DOC: Sorter delay
    constant SORTER_DEBUG_REGISTER_R             :  integer := 16#4029#;       -- DOC: Sorter delay


end package;