library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity board_reset_adapter is
    generic (
        DEBOUNCE_CYCLES_G      : positive := 16#FFFF#;
        RESET_HOLDOFF_CYCLES_G : positive := 5000000
    );
    port (
        i_clk                  : in  std_logic;
        i_reset_release_button : in  std_logic;
        o_board_reset_n        : out std_logic
    );
end entity board_reset_adapter;

architecture rtl of board_reset_adapter is
    signal button_meta        : std_logic := '0';
    signal button_sync        : std_logic := '0';
    signal button_db          : std_logic := '0';
    signal debounce_ctr       : integer range 0 to DEBOUNCE_CYCLES_G - 1 := 0;
    signal reset_holdoff_ctr  : integer range 0 to RESET_HOLDOFF_CYCLES_G - 1 := 0;
    signal board_reset_n_int  : std_logic := '0';
begin
    o_board_reset_n <= board_reset_n_int;

    process (i_clk)
    begin
        if rising_edge(i_clk) then
            button_meta <= i_reset_release_button;
            button_sync <= button_meta;

            if button_sync /= button_db then
                if debounce_ctr = DEBOUNCE_CYCLES_G - 1 then
                    button_db <= button_sync;
                    debounce_ctr <= 0;
                else
                    debounce_ctr <= debounce_ctr + 1;
                end if;
            else
                debounce_ctr <= 0;
            end if;

            if button_db /= '1' then
                reset_holdoff_ctr <= 0;
                board_reset_n_int <= '0';
            elsif reset_holdoff_ctr = RESET_HOLDOFF_CYCLES_G - 1 then
                board_reset_n_int <= '1';
            else
                reset_holdoff_ctr <= reset_holdoff_ctr + 1;
                board_reset_n_int <= '0';
            end if;
        end if;
    end process;
end architecture rtl;
