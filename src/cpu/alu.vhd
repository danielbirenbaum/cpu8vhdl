library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity alu is
    port (
        a         : in  byte_t;
        b         : in  byte_t;
        op        : in  aluop_t;
        resultado : out byte_t;
        z         : out std_logic;
        c         : out std_logic;
        n         : out std_logic;
        v         : out std_logic
    );
end entity alu;

architecture rtl of alu is
begin

    process (a, b, op)

        variable respa_v   : unsigned(8 downto 0);
        variable res_v   : byte_t;
        variable carry_v : std_logic;
        variable ovf_v   : std_logic;

    begin

        respa_v   := (others => '0');
        res_v   := (others => '0');
        carry_v := '0';
        ovf_v   := '0';

        case op is

            when ALU_ADD =>
                respa_v := resize(unsigned(a), respa_v'length)
                          + resize(unsigned(b), respa_v'length);

                res_v := std_logic_vector(respa_v(7 downto 0));
                carry_v := respa_v(8);

                ovf_v := (not (a(7) xor b(7)))
                         and (res_v(7) xor a(7));

            when ALU_SUB =>
                respa_v := resize(unsigned(a), respa_v'length)
                       - resize(unsigned(b), respa_v'length);

                res_v := std_logic_vector(respa_v(7 downto 0));

                if unsigned(a) >= unsigned(b) then
                    carry_v := '1';
                else
                    carry_v := '0';
                end if;

                ovf_v := (a(7) xor b(7))
                         and (res_v(7) xor a(7));

            when ALU_AND =>
                res_v := a and b;

            when ALU_OR =>
                res_v := a or b;

            when ALU_XOR =>
                res_v := a xor b;

            when ALU_NOT =>
                res_v := not a;

            when others =>
                res_v := (others => '0');

        end case;

        resultado <= res_v;

        if res_v = x"00" then
            z <= '1';
        else
            z <= '0';
        end if;

        c <= carry_v;
        n <= res_v(7);
        v <= ovf_v;

    end process;

end architecture rtl;