--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package sim is
    -- pragma translate_off

    type rng_lfsr32_t is protected
        procedure init (
            seed : in std_logic_vector(31 downto 0)--;
        );

        procedure init (
            seed : in integer--;
        );

        impure function random (
            n : positive--;
        ) return std_logic_vector;

        impure function random return std_logic;
        impure function random return integer;
        --
    end protected;

    type PCG_XSH_RR_t is protected
        procedure init (
            seed : in std_logic_vector(63 downto 0)--;
        );
        --
    end protected;
    -- pragma translate_on
end package;

package body sim is
    -- pragma translate_off

    type rng_lfsr32_t is protected body
        variable lfsr : std_logic_vector(31 downto 0) := (others => 'X');

        procedure init (
            seed : in std_logic_vector(31 downto 0)--;
        ) is begin
            lfsr := seed;
        end procedure;

        procedure init (
            seed : in integer--;
        ) is begin
            init(std_logic_vector(to_signed(seed, 32)));
        end procedure;

        impure function random (
            n : positive--;
        ) return std_logic_vector is
            variable z : std_logic_vector(n-1 downto 0);
        begin
            for i in z'range loop
                lfsr := work.util.lfsr(lfsr, 31 & 21 & 1 & 0);
                z(i) := lfsr(0);
            end loop;
            return z;
        end function;

        impure function random return std_logic is
        begin
            return random(1)(0);
        end function;

        impure function random return integer is
        begin
            -- TODO: try ieee.math_real.uniform
            return to_integer(signed(random(32)));
        end function;
        --
    end protected body;

    type PCG_XSH_RR_t is protected body
        variable state : std_logic_vector(63 downto 0) := (others => 'X');
        constant increment, multiplier : std_logic_vector(63 downto 0) := (others => '0');

        procedure init (
            seed : in std_logic_vector(63 downto 0)--;
        ) is begin
            state := seed;-- * multiplier + increment;
        end procedure;
        --
    end protected body;

    -- pragma translate_on
end package body;
