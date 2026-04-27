-- mscb addressing
-- Martin Mueller August 2019

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mudaq.all;


ENTITY mscb_addressing is
port (
    i_data          : in  std_logic_vector(8 downto 0);
    i_empty         : in  std_logic;
    i_address       : in  std_logic_vector(15 downto 0);
    o_data          : out std_logic_vector(8 downto 0);
    o_wrreq         : out std_logic;
    o_rdreq         : out std_logic;

    i_reset         : in  std_logic;
    i_clk           : in  std_logic--;
);
END ENTITY;

architecture rtl of mscb_addressing is

    type mscb_rd_state is (idle,rd,proc);
    type process_state is (idle, addressing1, addressing2, addressed, not_addressed);

    signal state :           mscb_rd_state;
    signal proc_state :      process_state;
    signal data :            std_logic_vector(8 downto 0);
    signal cmd_buffer :      std_logic_vector(35 downto 0);
    signal send_buffer :     std_logic_vector(2 downto 0);

    signal timeout : unsigned(16 downto 0);

begin

    process(i_clk, i_reset)
    begin
    if ( i_reset = '1' ) then
        o_wrreq         <= '0';
        o_rdreq         <= '0';
        o_data          <= (others => '1');
        state           <= idle;
        proc_state      <= idle;
        send_buffer     <= (others => '1');
        timeout         <= (others => '0');
        data            <= (others => '1');
        cmd_buffer      <= (others => '1');
        --
    elsif rising_edge(i_clk) then
        timeout <= timeout + 1;

        case state is
        when idle =>
            o_wrreq             <= '0';
            if ( timeout = (timeout'range => '1') ) then
                proc_state      <= idle;
                timeout         <= (others => '0');
                send_buffer     <= (others => '0');
                cmd_buffer      <= (others => '1');
            end if;

            if(i_empty = '0') then
                o_rdreq     <= '1';
                state       <= rd;
                data        <= i_data;
            else
                o_rdreq     <= '0';
            end if;

        when rd =>
            o_rdreq     <= '0';
            o_wrreq     <= '0';
            state       <= proc;

        when proc =>
            -- for tests:
            -- state       <= idle;
            -- o_wrreq     <= '1';
            -- o_data      <= data;

            case proc_state is
            when idle =>
                if((data(7 downto 0) = MSCB_CMD_ADDR_NODE16) or (data(7 downto 0) = MSCB_CMD_PING16)) then
                    proc_state                  <= addressing1;
                    cmd_buffer(8 downto 0)      <= data(8 downto 0);
                    timeout                     <= (others => '0'); -- start timeout counting
                elsif ((data(7 downto 0) = MSCB_CMD_ADDR_BC)) then -- Broadcast command
                    proc_state                  <= addressed;
                    send_buffer                 <= "100";
                    o_wrreq                     <= '1';
                    o_data                      <= data;
                    timeout                     <= (others => '0');
                end if;
                state                           <= idle;

            when addressing1 =>
                if(data(7 downto 0) = i_address(15 downto 8)) then
                    proc_state                  <= addressing2;
                    cmd_buffer(17 downto 9)     <= data(8 downto 0);
                else
                    proc_state                  <= not_addressed;
                end if;
                state                           <= idle;

            when addressing2 =>
                if(data(7 downto 0) = i_address(7 downto 0)) then
                    proc_state                  <= addressed;
                    cmd_buffer(26 downto 18)    <= data(8 downto 0);
                else
                    proc_state                  <= not_addressed;
                end if;
                -- the next one is a CRC, we let the software do that  => wait for CRC and send to nios
                state                           <= idle;
                send_buffer                     <= "000";

            when addressed =>
                if(send_buffer = "000") then
                    o_data                      <= cmd_buffer(8 downto 0);-- send MSCB_CMD_ADDR_NODE16
                    cmd_buffer(8 downto 0)      <= data(8 downto 0);-- this is the CRC
                    o_wrreq                     <= '1';
                    -- we do not wait for new commands here for the first time, so we dont do a state <= idle
                    send_buffer                 <= "001";
                elsif(send_buffer = "001") then
                    o_data                      <= cmd_buffer(17 downto 9);-- send the first part of address
                    o_wrreq                     <= '1';
                    send_buffer                 <= "010";
                elsif(send_buffer = "010") then
                    o_data                      <= cmd_buffer(26 downto 18);-- send 2nd part of address
                    o_wrreq                     <= '1';
                    send_buffer                 <= "011";
                elsif(send_buffer = "011") then
                    o_data                      <= cmd_buffer(8 downto 0); -- send the CRC
                    o_wrreq                     <= '1';
                    -- we are done, back to idle and wait for new data
                    state                       <= idle;
                    --stay in addressed state and forward stuff to nios
                    send_buffer                 <= "100";
                elsif(send_buffer = "100") then
                    -- forward to nios
                    o_wrreq                     <= '1';
                    o_data                      <= data;
                    state                       <= idle;

                    -- stay here for some time and forward everthing to nios for now
                    -- TODO: read length from command and adjust timeout

                    if ( timeout = (timeout'range => '1') ) then
                        proc_state      <= idle;
                        state           <= idle;
                        send_buffer     <= "000";
                        timeout         <= (others => '0');
                    end if;
                end if;

            when not_addressed =>
                proc_state      <= idle;
                -- TODO: do something intellegent here --MM
                -- data (write mem etc.) might contain a sequence like MSCB_CMD_ADDR_NODE16, NodeAddress1, NodeAddress2, CORRECT CRC, VALID COMMAND, VALID PAYLOAD by chance
                -- should i just sit here for a while to avoid this ? how long ?
                -- if i dont't interpret the commad i don't know the length => cannot ignore the correct length here ...

                -- => have to read at least the length of command here
                -- https://elog.psi.ch/mscb/protocol/index.html
                -- xxxxx 000    [CRC]           command only
                -- xxxxx 001    [byte1] [CRC]   Single byte parameter
                -- ..
            when others =>
                proc_state      <= idle;

            end case;

        when others =>
            state       <= idle;

        end case;

    end if;
    end process;

end architecture;
