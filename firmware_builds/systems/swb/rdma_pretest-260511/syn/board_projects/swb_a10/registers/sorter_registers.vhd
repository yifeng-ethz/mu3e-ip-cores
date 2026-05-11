

library ieee;
use ieee.std_logic_1164.all;


package sorter_registers is

    constant SORTER_COUNTER_REGISTER_R          :  integer := 16#1000#; -- DOC: Diagnostic counters in the sorter Hit counters in the sorter | MP_FEB
    constant SORTER_INDEX_NINTIME               :  integer := 0;        -- DOC: Counters for in-time hits in the sorter, one for each sorter input | MP_FEB
    constant SORTER_INDEX_NOUTOFTIME            :  integer := 12;       -- DOC: Counters for out-of-time hits in the sorter, one for each sorter input | MP_FEB
    constant SORTER_INDEX_NOVERFLOW             :  integer := 24;       -- DOC: Counters for overflows in the sorter, one for each sorter input | MP_FEB
    constant SORTER_INDEX_NPREWINDOW            :  integer := 36;       -- DOC: Counter for hits before window, one for each sorter input | MP_FEB
    constant SORTER_INDEX_NPASTWINDOW           :  integer := 48;       -- DOC: Counter for hits past window, one for each sorter input| MP_FEB
    constant SORTER_INDEX_NOUTDIAG              :  integer := 60;       -- DOC: Counter out of diag window, one for each sorter input | MP_FEB
    constant SORTER_INDEX_NOUT                  :  integer := 72;       -- DOC: Counter for hits leaving the sorter | MP_FEB
    constant SORTER_INDEX_CREDIT                :  integer := 73;       -- DOC: Current value of the sorter credits | MP_FEB
    constant SORTER_INDEX_DIAGNOSE              :  integer := 74;       -- DOC: Set width of diagnose window index | MP_FEB
    constant SORTER_INDEX_DELAY                 :  integer := 75;       -- DOC: Sorter delay index | MP_FEB

end package;
