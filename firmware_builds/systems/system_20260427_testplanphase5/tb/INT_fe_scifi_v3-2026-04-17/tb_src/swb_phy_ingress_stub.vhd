library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity swb_phy_ingress_stub is
    generic (
        ENABLE_BACKPRESSURE_G : boolean  := true;
        BACKPRESSURE_PERIOD_G : positive := 32
    );
    port (
        clk     : in  std_logic;
        reset_n : in  std_logic;

        link0_data  : in  std_logic_vector(35 downto 0);
        link0_valid : in  std_logic;
        link0_sop   : in  std_logic;
        link0_eop   : in  std_logic;
        link0_ready : out std_logic;

        link1_data  : in  std_logic_vector(35 downto 0);
        link1_valid : in  std_logic;
        link1_sop   : in  std_logic;
        link1_eop   : in  std_logic;
        link1_ready : out std_logic;

        link0_words_accepted  : out natural range 0 to 65535;
        link0_frames_accepted : out natural range 0 to 65535;
        link1_words_accepted  : out natural range 0 to 65535;
        link1_frames_accepted : out natural range 0 to 65535
    );
end entity swb_phy_ingress_stub;

architecture rtl of swb_phy_ingress_stub is
    function has_unknown(v : std_logic_vector) return boolean is
    begin
        for i in v'range loop
            if not (v(i) = '0' or v(i) = '1') then
                return true;
            end if;
        end loop;
        return false;
    end function has_unknown;

    signal cycle_counter : natural range 0 to 65535 := 0;
    signal link0_ready_q : std_logic := '1';
    signal link1_ready_q : std_logic := '1';
    signal link0_words_q  : natural range 0 to 65535 := 0;
    signal link0_frames_q : natural range 0 to 65535 := 0;
    signal link1_words_q  : natural range 0 to 65535 := 0;
    signal link1_frames_q : natural range 0 to 65535 := 0;
begin
    link0_ready <= link0_ready_q;
    link1_ready <= link1_ready_q;

    link0_words_accepted  <= link0_words_q;
    link0_frames_accepted <= link0_frames_q;
    link1_words_accepted  <= link1_words_q;
    link1_frames_accepted <= link1_frames_q;

    proc_capture : process (clk)
        variable apply_backpressure : boolean;
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                cycle_counter <= 0;
                link0_ready_q <= '1';
                link1_ready_q <= '1';
                link0_words_q <= 0;
                link0_frames_q <= 0;
                link1_words_q <= 0;
                link1_frames_q <= 0;
            else
                if cycle_counter < 65535 then
                    cycle_counter <= cycle_counter + 1;
                end if;

                apply_backpressure :=
                    ENABLE_BACKPRESSURE_G and ((cycle_counter mod BACKPRESSURE_PERIOD_G) = (BACKPRESSURE_PERIOD_G - 1));

                if apply_backpressure then
                    link0_ready_q <= '0';
                    link1_ready_q <= '0';
                else
                    link0_ready_q <= '1';
                    link1_ready_q <= '1';
                end if;

                if link0_valid = '1' and link0_ready_q = '1' then
                    if link0_words_q < 65535 then
                        link0_words_q <= link0_words_q + 1;
                    end if;
                    if link0_sop = '1' then
                        if link0_frames_q < 65535 then
                            link0_frames_q <= link0_frames_q + 1;
                        end if;
                    end if;
                end if;

                if link1_valid = '1' and link1_ready_q = '1' then
                    if link1_words_q < 65535 then
                        link1_words_q <= link1_words_q + 1;
                    end if;
                    if link1_sop = '1' then
                        if link1_frames_q < 65535 then
                            link1_frames_q <= link1_frames_q + 1;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process proc_capture;

    assert not has_unknown(link0_data)
        report "SWB PHY stub observed unknowns on link0 data bus"
        severity warning;
    assert not has_unknown(link1_data)
        report "SWB PHY stub observed unknowns on link1 data bus"
        severity warning;
end architecture rtl;
