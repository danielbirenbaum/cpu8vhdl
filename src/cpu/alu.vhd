-- ULA de 8 bits: ADD, SUB, AND, OR, XOR e NOT.
-- As flags de saida seguem a ordem Z, C, N e V no datapath.

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
        variable ext_v   : unsigned(8 downto 0);
        variable res_v   : byte_t;
        variable carry_v : std_logic;
        variable ovf_v   : std_logic;
    begin
        -- Valores padrao para todos os caminhos combinacionais.
        ext_v   := (others => '0');
        res_v   := (others => '0');
        carry_v := '0';
        ovf_v   := '0';

        case op is
            when ALU_ADD =>
                ext_v := resize(unsigned(a), ext_v'length)
                       + resize(unsigned(b), ext_v'length);
                res_v := std_logic_vector(ext_v(7 downto 0));
                carry_v := ext_v(8);
                ovf_v := (not (a(7) xor b(7)))
                         and (res_v(7) xor a(7));

            when ALU_SUB =>
                ext_v := resize(unsigned(a), ext_v'length)
                       - resize(unsigned(b), ext_v'length);
                res_v := std_logic_vector(ext_v(7 downto 0));

                -- Nesta CPU, C=1 significa que a subtracao NAO teve borrow.
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
