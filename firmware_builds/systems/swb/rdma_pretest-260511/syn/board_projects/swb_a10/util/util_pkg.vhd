--

library ieee;
use ieee.math_real.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

use std.textio.all;
use ieee.std_logic_textio.all;

package util is

    constant SIMULATION : boolean := false
        -- pragma translate_off
        or true
        -- pragma translate_on
    ;

    --! 8b/10b words
    -- Dx_y = to_unsigned(y, 3) & to_unsigned(x, 5)
    constant D16_2 : std_logic_vector(7 downto 0) := X"50";
    constant D21_4 : std_logic_vector(7 downto 0) := x"95";
    constant D02_5 : std_logic_vector(7 downto 0) := X"A2";
    constant D21_5 : std_logic_vector(7 downto 0) := x"B5";
    constant D28_4 : std_logic_vector(7 downto 0) := x"9C";
    constant D28_5 : std_logic_vector(7 downto 0) := X"BC";
    constant D28_7 : std_logic_vector(7 downto 0) := X"FC";
    constant D05_6 : std_logic_vector(7 downto 0) := X"C5";
    -- Kx_y - control symbol
    constant K28_0 : std_logic_vector(7 downto 0) := X"1C";
    constant K28_1 : std_logic_vector(7 downto 0) := X"3C";
    constant K28_2 : std_logic_vector(7 downto 0) := X"5C";
    constant K28_3 : std_logic_vector(7 downto 0) := X"7C";
    constant K28_4 : std_logic_vector(7 downto 0) := X"9C";
    -- K.28.1, K.28.5, and K.28.7 are "comma symbols"
    -- (if K.28.7 is not used, the unique comma sequences 00111110 or 11000001
    -- can't be found at any bit position within any combination of normal codes)
    constant K28_5 : std_logic_vector(7 downto 0) := X"BC";
    constant K28_6 : std_logic_vector(7 downto 0) := X"DC";
    -- NOTE: a combination of K.28.7 with several other codes
    -- forms a false misaligned comma symbol overlapping the two codes
    constant K28_7 : std_logic_vector(7 downto 0) := X"FC";
    constant K23_7 : std_logic_vector(7 downto 0) := X"F7";
    constant K27_7 : std_logic_vector(7 downto 0) := X"FB";
    constant K29_7 : std_logic_vector(7 downto 0) := X"FD";
    constant K30_7 : std_logic_vector(7 downto 0) := X"FE";

    -- @deprecated : use avmm_t
    -- avalon memory mapped interface
    type avalon_t is record
        address         :   std_logic_vector(31 downto 0);
        read            :   std_logic;
        readdata        :   std_logic_vector(31 downto 0);
        write           :   std_logic;
        writedata       :   std_logic_vector(31 downto 0);
        waitrequest     :   std_logic;
        readdatavalid   :   std_logic;
    end record;
    type avalon_array_t is array(natural range <>) of avalon_t;
    constant c_AVALON_ZERO : avalon_t := (
        read => '0', write => '0', waitrequest => '0', readdatavalid => '0',
        others => (others => '0')
    );



    -- avalon memory mapped interface
    type avmm_t is record
        address         :   std_logic_vector(31 downto 0);
        read            :   std_logic;
        -- NOTE: `readdata`, `readdatavalid` and `waitrequest`
        --       should be used as separate ports/signals
        readdata        :   std_logic_vector(31 downto 0);
        write           :   std_logic;
        writedata       :   std_logic_vector(31 downto 0);
        waitrequest     :   std_logic;
        readdatavalid   :   std_logic;
    end record;
    type avmm_array_t is array(natural range <>) of avmm_t;

    -- avalon streaming interface
    type avst256_t is record
        data            :   std_logic_vector(255 downto 0);
        sop             :   std_logic;
        eop             :   std_logic;
        empty           :   std_logic_vector(1 downto 0);
        valid           :   std_logic;
        err             :   std_logic;
        -- NOTE: `ready` should be used as separate port/signal
        ready           :   std_logic;
    end record;
    type avst256_array_t is array(natural range <>) of avst256_t;
    constant c_AVST256_ZERO : avst256_t := (
        data => (others => '0'), empty => (others => '0'),
        others => '0'
    );

    -- @deprecated (use rw32_t)
    type rw_t is record
        addr            :   std_logic_vector(31 downto 0);
        re              :   std_logic; -- read enable
        rvalid          :   std_logic; -- read valid
        rdata           :   std_logic_vector(31 downto 0);
        we              :   std_logic; -- write enable
        wdata           :   std_logic_vector(31 downto 0);
    end record;
    type rw32_t is record
        addr            :   std_logic_vector(31 downto 0);
        -- NOTE: `re` and `rvalid` should be used as separate ports/signals
        re              :   std_logic; -- read enable
        rvalid          :   std_logic; -- read valid
        rdata           :   std_logic_vector(31 downto 0);
        we              :   std_logic; -- write enable
        wdata           :   std_logic_vector(31 downto 0);
    end record;
    type rw32_array_t is array(natural range <>) of rw32_t;
    constant c_RW32_ZERO : rw32_t := (
        re => '0', rvalid => '0', we => '0',
        others => (others => '0')
    );



    function value_if (
        condition : boolean;
        value_true, value_false : std_logic_vector--;
    ) return std_logic_vector;

    function value_if (
        condition : boolean;
        value_true, value_false : integer--;
    ) return integer;

    function value_if (
        condition : boolean;
        value_true, value_false : string--;
    ) return string;

    -- Greatest Common Divisor
    function gcd (
        p, q : positive--;
    ) return positive;

    function max (
        l, r : integer--;
    ) return integer;

    function vector_width (
        v : natural--;
    ) return positive;

    function bin2gray (
        v : std_logic_vector--;
    ) return std_logic_vector;

    function gray2bin (
        v : std_logic_vector--;
    ) return std_logic_vector;

    function gray_inc (
        v : std_logic_vector--;
    ) return std_logic_vector;

    -- @deprecated
    function grayinc (
        v : std_logic_vector--;
    ) return std_logic_vector;

    function shift_right (
        v : std_logic_vector;
        n : natural--;
    ) return std_logic_vector;

    function shift_left (
        v : std_logic_vector;
        n : natural--;
    ) return std_logic_vector;

    function rotate_right (
        v : std_logic_vector;
        n : natural--;
    ) return std_logic_vector;

    function rotate_left (
        v : std_logic_vector;
        n : natural--;
    ) return std_logic_vector;

    function resize (
        v : std_logic_vector;
        n : positive--;
    ) return std_logic_vector;

    function to_std_logic (
        b : in boolean--;
    ) return std_logic;

    function reverse (
        v : std_logic_vector--;
    ) return std_logic_vector;

    procedure char_to_hex (
        c : in character;
        v : out std_logic_vector(3 downto 0);
        good : out boolean--;
    );

    procedure string_to_hex (
        s : in string;
        v : out std_logic_vector;
        good : out boolean--;
    );

    procedure read_hex (
        l : inout line;
        value : out std_logic_vector;
        good : out boolean--;
    );

    impure
    function read_hex (
        fname : in string;
        N : in positive;
        W : in positive--;
    ) return std_logic_vector;

    function lfsr (
        data : in std_logic_vector;
        taps : in integer_vector--;
    ) return std_logic_vector;

    function one_hot_to_index (
        one_hot : std_logic_vector--;
    ) return std_logic_vector;

    function count_bits (
        data : std_logic_vector--;
    ) return natural;

    function to_slv (
        c : in character--;
    ) return std_logic_vector;

    function to_slv (
        s : in string--;
    ) return std_logic_vector;

    function to_string (
        v : in std_logic--;
    ) return string;

    function to_string (
        v : in std_logic_vector--;
    ) return string;

    function to_hstring (
        v : std_logic_vector--;
    ) return string;

    -- get next Round-Robin index
    function round_robin_next (
        i : std_logic_vector;
        req : std_logic_vector--;
    ) return std_logic_vector;

    -- for input "1010" and n = 3 produce output "111000111000"
    function expand (
        v : std_logic_vector;
        n : integer--;
    ) return std_logic_vector;

    -- Select Graphic Rendition
    function sgr (
        n : natural--;
    ) return string;

    -- return map_vector(i) when ( i < map_vector'lenght ) else i
    function map_index (
        i : integer;
        map_vector : integer_vector--;
    ) return integer;

    -- CLZ
    function count_leading_zeroes (
        slv : std_logic_vector--;
    ) return integer;

    constant SGR_RESET : string;
    constant SGR_FG_RED : string;
    constant SGR_FG_GREEN : string;

end package;

package body util is

    function value_if (
        condition : boolean;
        value_true, value_false : std_logic_vector--;
    ) return std_logic_vector is
    begin
        if ( condition ) then
            return value_true;
        else
            return value_false;
        end if;
    end function;

    function value_if (
        condition : boolean;
        value_true, value_false : integer--;
    ) return integer is
    begin
        if ( condition ) then
            return value_true;
        else
            return value_false;
        end if;
    end function;

    function value_if (
        condition : boolean;
        value_true, value_false : string--;
    ) return string is
    begin
        if ( condition ) then
            return value_true;
        else
            return value_false;
        end if;
    end function;

    function gcd (
        p, q : positive--;
    ) return positive is
        variable p_v : positive := p;
        variable q_v : positive := q;
    begin
        while ( p_v /= q_v ) loop
            if ( p_v > q_v ) then
                p_v := p_v - q_v;
            else
                q_v := q_v - p_v;
            end if;
        end loop;
        return p_v;
    end function;

    function max (
        l, r : integer
    ) return integer is
    begin
        if ( l > r ) then
            return l;
        else
            return r;
        end if;
    end function;

    function vector_width (
        v : natural--;
    ) return positive is
    begin
        if ( v = 0 or v = 1 ) then
            return 1;
        end if;
        return positive(ceil(log2(real(v))));
    end function;

    function bin2gray (
        v : std_logic_vector--;
    ) return std_logic_vector is
    begin
        return v xor shift_right(v, 1);
    end function;

    function gray2bin (
        v : std_logic_vector--;
    ) return std_logic_vector is
        variable b : std_logic := '0';
        variable r : std_logic_vector(v'range);
    begin
        for i in v'range loop
            b := b xor v(i);
            r(i) := b;
        end loop;
        return r;
    end function;

    function gray_inc (
        v : std_logic_vector--;
    ) return std_logic_vector is
        variable r : std_logic_vector(v'range) := (others => '0');
    begin
        r := gray2bin(v);
        r := r + 1;
        return bin2gray(r);
    end function;

    function grayinc (
        v : std_logic_vector--;
    ) return std_logic_vector is
        variable r : std_logic_vector(v'range) := (others => '0');
    begin
        r(r'right) := '1';
        if ( xor_reduce(v) /= '0' ) then
            for i in v'reverse_range loop
                exit when ( i = v'left );
                r := shift_left(r, 1);
                exit when ( v(i) = '1' );
            end loop;
        end if;
        return v xor r;
    end function;

    function shift_right (
        v : std_logic_vector;
        n : natural--;
    ) return std_logic_vector is
    begin
        return std_logic_vector(shift_right(unsigned(v), n));
    end function;

    function shift_left (
        v : std_logic_vector;
        n : natural--;
    ) return std_logic_vector is
    begin
        return std_logic_vector(shift_left(unsigned(v), n));
    end function;

    function rotate_right (
        v : std_logic_vector;
        n : natural--;
    ) return std_logic_vector is
    begin
        return shift_right(v, n) or shift_left(v, v'length - n);
    end function;

    function rotate_left (
        v : std_logic_vector;
        n : natural--;
    ) return std_logic_vector is
    begin
        return shift_left(v, n) or shift_right(v, v'length - n);
    end function;

    function resize (
        v : std_logic_vector;
        n : positive--;
    ) return std_logic_vector is
    begin
        return std_logic_vector(resize(unsigned(v), n));
    end function;

    function to_std_logic (
        b : in boolean--;
    ) return std_logic is
    begin
        if b then
            return '1';
        else
            return '0';
        end if;
    end function;

    function reverse (
        v : std_logic_vector--;
    ) return std_logic_vector is
        variable r : std_logic_vector(v'range);
        alias a : std_logic_vector(v'reverse_range) is v;
    begin
        for i in a'range loop
            r(i) := a(i);
        end loop;
        return r;
    end function;

    procedure char_to_hex (
        c : in character;
        v : out std_logic_vector(3 downto 0);
        good : out boolean--;
    ) is
    begin
        good := true;
        case c is
        when '0' => v := X"0";
        when '1' => v := X"1";
        when '2' => v := X"2";
        when '3' => v := X"3";
        when '4' => v := X"4";
        when '5' => v := X"5";
        when '6' => v := X"6";
        when '7' => v := X"7";
        when '8' => v := X"8";
        when '9' => v := X"9";

        when 'a' | 'A' => v := X"A";
        when 'b' | 'B' => v := X"B";
        when 'c' | 'C' => v := X"C";
        when 'd' | 'D' => v := X"D";
        when 'e' | 'E' => v := X"E";
        when 'f' | 'F' => v := X"F";

        when others =>
            report "(char_to_hex) invalid hex character '" & c & "'" severity failure;
            good := false;
            v := "XXXX";
        end case;
    end procedure;

    procedure string_to_hex (
        s : in string;
        v : out std_logic_vector;
        good : out boolean--;
    ) is
        variable ok : boolean;
        variable good_i : boolean;
    begin
        good_i := true;
        for i in 0 to s'length-1 loop
            char_to_hex(s(s'right-i), v(3+4*i+v'right downto 4*i+v'right), ok);
            good_i := good_i and ok;
        end loop;
        good := good_i;
    end procedure;

    procedure read_hex (
        l : inout line;
        value : out std_logic_vector;
        good : out boolean--;
    ) is
        variable v : std_logic_vector(value'range);
        variable c : character;
        variable s : string(1 to value'length/4);
        variable ok : boolean;
    begin
        good := false;

        if ( value'length mod 4 /= 0 ) then
            report "(read_hex) value'length mod 4 /= 0" severity failure;
            return;
        end if;

        -- skip spaces
        loop
            read(l, c);
            exit when ((c /= ' ') and (c /= CR) and (c /= HT));
        end loop;

        -- skip comment
        if ( c = '#' ) then
            return;
        end if;

        s(1) := c;
        read(L, s(2 to s'right), ok);
        if not ok then
            return;
        end if;

        string_to_hex(s, v, ok);
        if not ok then
            return;
        end if;

        value := v;
        good := true;
    end procedure;

    impure
    function read_hex (
        fname : in string;
        N : in positive;
        W : in positive--;
    ) return std_logic_vector is
        variable data : std_logic_vector(N*W-1 downto 0);
        variable data_i : std_logic_vector(W-1 downto 0);
        variable i : integer := 0;
        file f : text;
        variable fs : file_open_status;
        variable l : line;
        variable c : character;
        variable s : string(1 to W/4);
        variable ok : boolean;
    begin
        if ( fname'length = 0 ) then
            return data;
        end if;

        file_open(fs, f, fname, READ_MODE);
        assert ( fs = open_ok ) report "(read_hex) file_open_status = '" & FILE_OPEN_STATUS'image(fs) & "'" severity failure;

        while ( not endfile(f) ) loop
            readline(f, l);
            read(l, c, ok);
            next when ( not ok or c = '#' );
            s(1) := c;
            read(l, s(2 to s'right), ok);
            next when ( not ok );
            work.util.string_to_hex(s, data_i, ok);
            next when ( not ok );
            data(W-1+i*W downto i*W) := data_i;
            i := i + 1;
        end loop;

        file_close(f);
        return data;
    end function;

    function lfsr (
        data : in std_logic_vector;
        taps : in integer_vector--;
    ) return std_logic_vector is
        variable data_v : std_logic_vector(data'range);
    begin
        data_v := shift_left(data, 1);
        for i in taps'range loop
            data_v(0) := data_v(0) xor data(taps(i));
        end loop;
        return data_v;
    end function;

    -- one hot to index calculate; assuming LEN_HOT = 2 ** LEN_IDX
    -- https://stackoverflow.com/questions/57269302
    function one_hot_to_index (
        one_hot : std_logic_vector--;
    ) return std_logic_vector is
        variable mask_v : std_logic_vector(one_hot'range);
        variable res_v  : std_logic_vector(vector_width(one_hot'length)-1 downto 0);
    begin
        for i in res_v'range loop
            -- generate mask
            for j in one_hot'range loop
                if ((j / (2 ** i)) mod 2) = 0 then
                    mask_v(j) := '0';
                else
                    mask_v(j) := '1';
                end if;
            end loop;
            -- apply mask and generate bit in index
            if unsigned(one_hot and mask_v) = 0 then
                res_v(i) := '0';
            else
                res_v(i) := '1';
            end if;
        end loop;
        return res_v;
    end function;

    function count_bits (
        data : std_logic_vector--;
    ) return natural is
        variable data_v : std_logic_vector(data'length-1 downto 0);
    begin
        data_v := data;
        if ( data_v'length > 1 ) then
            return count_bits(data_v(data_v'length-1 downto data_v'length/2)) + count_bits(data_v(data_v'length/2-1 downto 0));
        else
            return to_integer(unsigned(data_v));
        end if;
    end function;

    function to_slv (
        c : in character--;
    ) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(character'pos(c), 8));
    end function;

    function to_slv (
        s : in string--;
    ) return std_logic_vector is
        variable v : std_logic_vector(s'length*8-1 downto 0);
    begin
        for i in s'length-1 downto 0 loop
            v((i+1)*8-1 downto i*8) := to_slv(s(i+1));
        end loop;
        return v;
    end function;

    function to_string (
        v : in std_logic--;
    ) return string is
        variable s : string(1 to 1);
    begin
        s(1) := std_logic'image(v)(2);
        return s;
    end function;

    function to_string (
        v : in std_logic_vector--;
    ) return string is
        variable s : string(1 to v'length);
        variable j : integer := 1;
    begin
        for i in v'range loop
            s(j) := to_string(v(i))(1);
            j := j + 1;
        end loop;
        return s;
    end function;

    function to_hstring (
        v : std_logic_vector--;
    ) return string is
        variable r : string(1 to (v'length + 3) / 4) := (others => 'X');
        variable u : unsigned(v'length+3 downto 0);
        constant LUT : string(1 to 16) := "0123456789ABCDEF";
    begin
        u := resize(unsigned(v), u'length);
        for i in r'range loop
            next when ( is_x(std_logic_vector(u(4*i-1 downto 4*i-4))) );
            r(r'length-i+1) := LUT(1 + to_integer(u(4*i-1 downto 4*i-4)));
        end loop;
        return r;
    end function;

    function round_robin_next (
        -- one hot encoded active link
        i : std_logic_vector;
        -- bit encoded available links
        req : std_logic_vector--;
    ) return std_logic_vector is
        variable mask, nxt : std_logic_vector(i'range);
    begin
        -- bits to the right of active link
        mask := i - 1;
        -- ... to the left ...
        mask := not mask xor i;
        -- select available links to the left of active link
        nxt := req and mask;
        if ( nxt = 0 ) then
            -- select all available links
            nxt := req or i;
        end if;
        -- return least significant set bit
        return nxt and ((not nxt) + 1);
    end function;

    function expand (
        v : std_logic_vector;
        n : integer--;
    ) return std_logic_vector is
        variable r : std_logic_vector(n*v'length-1 downto 0);
    begin
        for i in v'range loop
            r(n*(i+1)-1 downto n*i) := (others => v(i));
        end loop;
        return r;
    end function;

    function sgr (
        n : natural--;
    ) return string is
    begin
        return ESC & "[" & natural'image(n) & "m";
    end function;

    function map_index (
        i : integer;
        map_vector : integer_vector--;
    ) return integer is
    begin
        if ( i < map_vector'length ) then
            return map_vector(i);
        end if;
        return i;
    end function;

    function count_leading_zeroes (
        slv : std_logic_vector--;
    ) return integer is
    begin
        for i in slv'range loop
            if ( slv(i) /= '0' ) then
                return i;
            end if;
        end loop;
        return slv'length;
    end function;

    constant SGR_RESET : string := sgr(0);
    constant SGR_FG_RED : string := sgr(31);
    constant SGR_FG_GREEN : string := sgr(32);

end package body;
