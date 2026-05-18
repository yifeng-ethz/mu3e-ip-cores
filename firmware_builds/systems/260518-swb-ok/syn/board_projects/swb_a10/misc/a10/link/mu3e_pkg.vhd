--
-- author : Alexandr Kozlinskiy
-- date : 2018-03-30
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.util_slv.all;

package mu3e is

    --                                data  datak  idl   sop  dthdr sbhdr  eop  err t0  t1  d0  d1
    constant LINK_LENGTH : positive := 32  +  4  +  1  +  1  +  1  +  1  +  1  + 1 + 1 + 1 + 1 + 1;
    constant LINK_64b_LENGTH : positive := 64  +  1  +  1  +  1  +  1  +  1  +  1  + 1 + 1 + 1 + 1 + 1;

    -- TODO: think about to add a linkID

    type link32_t is record
        data    : std_logic_vector(31 downto 0);
        -- TODO: use one bit `k` signal
        datak   : std_logic_vector(3 downto 0);
        -- TODO: use valid
        idle    : std_logic;
        sop     : std_logic; -- start of packet (preamble)
        dthdr   : std_logic; -- DaTa HeaDeR
        sbhdr   : std_logic; -- SuB HeaDeR
        eop     : std_logic; -- end of packet (trailer)
        eor     : std_logic; -- end of run (trailer)
        err     : std_logic; -- package has an error
        t0      : std_logic; -- time stamp upper bits
        t1      : std_logic; -- time stamp lower bits
        d0      : std_logic; -- sorter debug word 0
        d1      : std_logic; -- sorter debug word 1
    end record;
    type link32_array_t is array(natural range <>) of link32_t;

    type link64_t is record
        data    : std_logic_vector(63 downto 0);
        k       : std_logic;
        idle    : std_logic;
        sop     : std_logic; -- start of packet (preamble)
        dthdr   : std_logic; -- DaTa HeaDeR
        sbhdr   : std_logic; -- SuB HeaDeR
        eop     : std_logic; -- end of packet (trailer)
        eor     : std_logic; -- end of run (trailer)
        err     : std_logic; -- package has an error
        t0      : std_logic; -- time stamp upper bits
        t1      : std_logic; -- time stamp lower bits
        d0      : std_logic; -- sorter debug word 0
        d1      : std_logic; -- sorter debug word 1
    end record;
    type link64_array_t is array(natural range <>) of link64_t;

    constant LINK32_ZERO : link32_t := (
        data => X"00000000",
        datak => "0000",
        others => '0'
    );
    constant LINK64_ZERO : link64_t := (
        data => X"0000000000000000",
        k => '0',
        others => '0'
    );

    constant LINK32_IDLE : link32_t := (
        data => X"000000" & work.util.D28_5,
        datak => "0001",
        idle => '1',
        others => '0'
    );
    constant LINK64_IDLE : link64_t := (
        data => X"00000000000000" & work.util.D28_5,
        k => '1',
        idle => '1',
        others => '0'
    );

    constant LINK32_SOP : link32_t := (
        data => X"E80000" & work.util.D28_5,
        datak => "0001",
        sop => '1',
        others => '0'
    );
    constant LINK64_SOP : link64_t := (
        data => X"00000000E80000" & work.util.D28_5,
        k => '1',
        sop => '1',
        others => '0'
    );

    constant LINK32_T0 : link32_t := (
        data => X"00000000",
        datak => "0000",
        t0 => '1',
        others => '0'
    );
    constant LINK64_T0 : link64_t := (
        data => X"0000000000000000",
        k => '0',
        t0 => '1',
        others => '0'
    );

    constant LINK32_T1 : link32_t := (
        data => X"00000000",
        datak => "0000",
        t1 => '1',
        others => '0'
    );
    constant LINK64_T1 : link64_t := (
        data => X"0000000000000000",
        k => '0',
        t1 => '1',
        others => '0'
    );

    constant LINK32_D0 : link32_t := (
        data => X"00000000",
        datak => "0000",
        d0 => '1',
        others => '0'
    );
    constant LINK64_D0 : link64_t := (
        data => X"0000000000000000",
        k => '0',
        d0 => '1',
        others => '0'
    );

    constant LINK32_D1 : link32_t := (
        data => X"00000000",
        datak => "0000",
        d1 => '1',
        others => '0'
    );
    constant LINK64_D1 : link64_t := (
        data => X"0000000000000000",
        k => '0',
        d1 => '1',
        others => '0'
    );

    constant LINK32_EOP : link32_t := (
        data => X"000000" & work.util.D28_4,
        datak => "0001",
        eop => '1',
        others => '0'
    );
    constant LINK64_EOP : link64_t := (
        data => X"00000000000000" & work.util.D28_4,
        k => '1',
        eop => '1',
        others => '0'
    );

    constant LINK_SBHDR : link32_t := (
        data => X"000000" & work.util.K23_7,
        datak => "0001",
        sbhdr => '1',
        others => '0'
    );
    constant LINK64_SBHDR : link64_t := (
        data => X"00000000000000" & work.util.K23_7,
        k => '1',
        sbhdr => '1',
        others => '0'
    );

    constant LINK_ERR : link32_t := (
        data => X"0FFFFF" & work.util.D28_4,
        datak => "0001",
        err => '1',
        others => '0'
    );
    constant LINK64_ERR : link64_t := (
        data => X"000000000FFFFF" & work.util.D28_4,
        k => '1',
        err => '1',
        others => '0'
    );

    subtype RANGE_LINK_FPGA_ID is integer range 23 downto 8;

    function to_link (
        data : std_logic_vector(31 downto 0);
        datak : std_logic_vector(3 downto 0)--;
    ) return link32_t;

    function to_link (
        data : std_logic_vector(63 downto 0);
        k : std_logic--;
    ) return link64_t;

    function to_link (
        slv : std_logic_vector(LINK_LENGTH-1 downto 0)--;
    ) return link32_t;

    function to_link (
        slv : std_logic_vector(LINK_64B_LENGTH-1 downto 0)--;
    ) return link64_t;

    function to_slv (
        link : link32_t--;
    ) return std_logic_vector;

    function to_slv (
        link : link64_t--;
    ) return std_logic_vector;

    function to_slv (
        links : link32_array_t--;
    ) return std_logic_vector;

    function to_slv (
        links : link64_array_t--;
    ) return std_logic_vector;

    function to_link_array (
        data : slv32_array_t;
        datak : slv4_array_t--;
    ) return link32_array_t;

    function to_link_array (
        data : slv64_array_t;
        k : std_logic_vector--;
    ) return link64_array_t;

    function to_slv_sop (
        links : link32_array_t--;
    ) return std_logic_vector;

    function to_slv_sop (
        links : link64_array_t--;
    ) return std_logic_vector;

    function to_slv_eop (
        links : link32_array_t--;
    ) return std_logic_vector;

    function to_slv_eop (
        links : link64_array_t--;
    ) return std_logic_vector;

end package;

package body mu3e is

    function to_link (
        data : std_logic_vector(31 downto 0);
        datak : std_logic_vector(3 downto 0)--;
    ) return link32_t is
        variable link : link32_t;
        variable i : integer := 0;
    begin
        link.data := data;
        i := i + 32;
        link.datak := datak;
        i := i + 4;

        link.idle := work.util.to_std_logic(true
            and datak = "0001"
            and data(7 downto 0) = work.util.D28_5 -- BC
            and data(31 downto 8) = X"000000"
        );
        i := i + 1;

        link.sop := not link.idle and work.util.to_std_logic(true
            and datak = "0001"
            and data(7 downto 0) = work.util.D28_5 -- BC
        );
        i := i + 1;

        link.dthdr := '0';
        i := i + 1;

        link.sbhdr := work.util.to_std_logic(true
            and datak = "0001"
            and data(7 downto 0) = work.util.K23_7 -- F7
        );
        i := i + 1;

        link.eop := not link.idle and work.util.to_std_logic(true
            and datak = "0001"
            and data(7 downto 0) = work.util.D28_4 -- 9C
        );
        i := i + 1;

        link.err := '0';
        i := i + 1;

        link.t0 := '0';
        i := i + 1;

        link.t1 := '0';
        i := i + 1;

        link.d0 := '0';
        i := i + 1;

        link.d1 := '0';
        i := i + 1;

        assert ( i = LINK_LENGTH ) severity failure;
        return link;
    end function;

    function to_link (
        data : std_logic_vector(63 downto 0);
        k : std_logic--;
    ) return link64_t is
        variable link : link64_t;
        variable i : integer := 0;
    begin
        link.data := data;
        i := i + 64;
        link.k := k;
        i := i + 1;

        link.idle := work.util.to_std_logic(true
            and k = '1'
            and data(7 downto 0) = work.util.D28_5 -- BC
            and data(63 downto 8) = X"000000"
        );
        i := i + 1;

        link.sop := not link.idle and work.util.to_std_logic(true
            and k = '1'
            and data(7 downto 0) = work.util.D28_5 -- BC
        );
        i := i + 1;

        link.dthdr := '0';
        i := i + 1;

        link.sbhdr := work.util.to_std_logic(true
            and k = '1'
            and data(7 downto 0) = work.util.K23_7 -- F7
        );
        i := i + 1;

        link.eop := not link.idle and work.util.to_std_logic(true
            and k = '1'
            and data(7 downto 0) = work.util.D28_4 -- 9C
        );
        i := i + 1;

        link.err := '0';
        i := i + 1;

        link.t0 := '0';
        i := i + 1;

        link.t1 := '0';
        i := i + 1;

        link.d0 := '0';
        i := i + 1;

        link.d1 := '0';
        i := i + 1;

        assert ( i = LINK_64b_LENGTH ) severity failure;
        return link;
    end function;

    function to_link (
        slv : std_logic_vector(LINK_LENGTH-1 downto 0)--;
    ) return link32_t is
        variable link : link32_t;
        variable i : integer := 0;
    begin
        link.data := slv(31 downto 0);
        i := i + 32;

        link.datak := slv(i+3 downto 0+i);
        i := i + 4;

        link.idle := slv(i);
        i := i + 1;

        link.sop := slv(i);
        i := i + 1;

        link.dthdr := slv(i);
        i := i + 1;

        link.sbhdr := slv(i);
        i := i + 1;

        link.eop := slv(i);
        i := i + 1;

        link.err := slv(i);
        i := i + 1;

        link.t0 := slv(i);
        i := i + 1;

        link.t1 := slv(i);
        i := i + 1;

        link.d0 := slv(i);
        i := i + 1;

        link.d1 := slv(i);
        i := i + 1;

        assert ( i = LINK_LENGTH ) severity failure;
        return link;
    end function;

    function to_link (
        slv : std_logic_vector(LINK_64b_LENGTH-1 downto 0)--;
    ) return link64_t is
        variable link : link64_t;
        variable i : integer := 0;
    begin
        link.data := slv(63 downto 0);
        i := i + 64;

        link.k := slv(i);
        i := i + 1;

        link.idle := slv(i);
        i := i + 1;

        link.sop := slv(i);
        i := i + 1;

        link.dthdr := slv(i);
        i := i + 1;

        link.sbhdr := slv(i);
        i := i + 1;

        link.eop := slv(i);
        i := i + 1;

        link.err := slv(i);
        i := i + 1;

        link.t0 := slv(i);
        i := i + 1;

        link.t1 := slv(i);
        i := i + 1;

        link.d0 := slv(i);
        i := i + 1;

        link.d1 := slv(i);
        i := i + 1;

        assert ( i = LINK_64b_LENGTH ) severity failure;
        return link;
    end function;

    function to_slv (
        link : link32_t--;
    ) return std_logic_vector is
        variable slv : std_logic_vector(LINK_LENGTH-1 downto 0);
        variable i : integer := 0;
    begin
        slv(31 downto 0) := link.data;
        i := i + 32;

        slv(i+3 downto 0+i) := link.datak;
        i := i + 4;

        slv(i) := link.idle;
        i := i + 1;

        slv(i) := link.sop;
        i := i + 1;

        slv(i) := link.dthdr;
        i := i + 1;

        slv(i) := link.sbhdr;
        i := i + 1;

        slv(i) := link.eop;
        i := i + 1;

        slv(i) := link.err;
        i := i + 1;

        slv(i) := link.t0;
        i := i + 1;

        slv(i) := link.t1;
        i := i + 1;

        slv(i) := link.d0;
        i := i + 1;

        slv(i) := link.d1;
        i := i + 1;

        assert ( i = LINK_LENGTH ) severity failure;
        return slv;
    end function;

    function to_slv (
        link : link64_t--;
    ) return std_logic_vector is
        variable slv : std_logic_vector(LINK_64b_LENGTH-1 downto 0);
        variable i : integer := 0;
    begin
        slv(63 downto 0) := link.data;
        i := i + 64;

        slv(i) := link.k;
        i := i + 1;

        slv(i) := link.idle;
        i := i + 1;

        slv(i) := link.sop;
        i := i + 1;

        slv(i) := link.dthdr;
        i := i + 1;

        slv(i) := link.sbhdr;
        i := i + 1;

        slv(i) := link.eop;
        i := i + 1;

        slv(i) := link.err;
        i := i + 1;

        slv(i) := link.t0;
        i := i + 1;

        slv(i) := link.t1;
        i := i + 1;

        slv(i) := link.d0;
        i := i + 1;

        slv(i) := link.d1;
        i := i + 1;

        assert ( i = LINK_64b_LENGTH ) severity failure;
        return slv;
    end function;

    function to_slv (
        links : link32_array_t--;
    ) return std_logic_vector is
        variable data : std_logic_vector(links'length*LINK_LENGTH-1 downto 0);
    begin
        for i in links'range loop
            data((i+1)*LINK_LENGTH-1 downto i*LINK_LENGTH) := to_slv(links(i));
        end loop;
        return data;
    end function;

    function to_slv (
        links : link64_array_t--;
    ) return std_logic_vector is
        variable data : std_logic_vector(links'length*LINK_64b_LENGTH-1 downto 0);
    begin
        for i in links'range loop
            data((i+1)*LINK_64b_LENGTH-1 downto i*LINK_64b_LENGTH) := to_slv(links(i));
        end loop;
        return data;
    end function;

    function to_link_array (
        data : slv32_array_t;
        datak : slv4_array_t--;
    ) return link32_array_t is
        variable links : link32_array_t(data'range);
    begin
        for i in data'range loop
            links(i) := to_link(data(i), datak(i));
        end loop;
        return links;
    end function;

    function to_link_array (
        data : slv64_array_t;
        k : std_logic_vector--;
    ) return link64_array_t is
        variable links : link64_array_t(data'range);
    begin
        for i in data'range loop
            links(i) := to_link(data(i), k(i));
        end loop;
        return links;
    end function;

    function to_slv_sop (
        links : link32_array_t--;
    ) return std_logic_vector is
        variable sop : std_logic_vector(links'range);
    begin
        for i in links'range loop
            sop(i) := links(i).sop;
        end loop;
        return sop;
    end function;

    function to_slv_sop (
        links : link64_array_t--;
    ) return std_logic_vector is
        variable sop : std_logic_vector(links'range);
    begin
        for i in links'range loop
            sop(i) := links(i).sop;
        end loop;
        return sop;
    end function;

    function to_slv_eop (
        links : link32_array_t--;
    ) return std_logic_vector is
        variable eop : std_logic_vector(links'range);
    begin
        for i in links'range loop
            eop(i) := links(i).eop;
        end loop;
        return eop;
    end function;

    function to_slv_eop (
        links : link64_array_t--;
    ) return std_logic_vector is
        variable eop : std_logic_vector(links'range);
    begin
        for i in links'range loop
            eop(i) := links(i).eop;
        end loop;
        return eop;
    end function;

end package body;
