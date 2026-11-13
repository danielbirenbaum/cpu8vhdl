-- Testbench da ULA de 8 bits.
-- Testa ADD, SUB, AND, OR, XOR, NOT, as flags e um opcode nao utilizado.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.cpu_pkg.all;

entity tb_alu_unit is
end entity tb_alu_unit;

architecture test of tb_alu_unit is
    signal a         : byte_t := (others => '0');
    signal b         : byte_t := (others => '0');
    signal op        : aluop_t := ALU_ADD;
    signal resultado : byte_t;
    signal z, c, n, v : std_logic;
begin
    dut : entity work.alu
        port map (
            a         => a,
            b         => b,
            op        => op,
            resultado => resultado,
            z         => z,
            c         => c,
            n         => n,
            v         => v
        );

    stimulus : process
        procedure check_result(
            constant test_name    : in string;
            constant expected     : in byte_t;
            constant expected_zcnv: in std_logic_vector(3 downto 0)
        ) is
        begin
            wait for 1 ns;
            assert resultado = expected
                report "Falha em " & test_name & ": resultado incorreto"
                severity failure;
            assert (z & c & n & v) = expected_zcnv
                report "Falha em " & test_name & ": flags ZCNV incorretas"
                severity failure;
            report "PASS: " & test_name severity note;
        end procedure;
    begin
        -- ADD simples: 5 + 3 = 8.
        a <= x"05"; b <= x"03"; op <= ALU_ADD;
        check_result("ADD simples", x"08", "0000");

        -- ADD com carry: 255 + 1 = 256; resultado de 8 bits = 0.
        a <= x"FF"; b <= x"01"; op <= ALU_ADD;
        check_result("ADD com carry", x"00", "1100");

        -- ADD com overflow de sinal: 127 + 1 = -128 em 8 bits.
        a <= x"7F"; b <= x"01"; op <= ALU_ADD;
        check_result("ADD com overflow", x"80", "0011");

        -- ADD de dois numeros negativos: -128 + -128 -> 0x00, C=1 e V=1.
        a <= x"80"; b <= x"80"; op <= ALU_ADD;
        check_result("ADD negativo com carry e overflow", x"00", "1101");

        -- SUB simples: 5 - 3 = 2; C=1 significa sem borrow.
        a <= x"05"; b <= x"03"; op <= ALU_SUB;
        check_result("SUB simples", x"02", "0100");

        -- SUB com borrow: 3 - 5 = -2 (0xFE); C=0.
        a <= x"03"; b <= x"05"; op <= ALU_SUB;
        check_result("SUB com borrow", x"FE", "0010");

        -- SUB com overflow: -128 - 1 nao cabe em 8 bits com sinal.
        a <= x"80"; b <= x"01"; op <= ALU_SUB;
        check_result("SUB com overflow", x"7F", "0101");

        -- AND: bits correspondentes precisam ser ambos 1.
        a <= x"F0"; b <= x"0F"; op <= ALU_AND;
        check_result("AND", x"00", "1000");

        -- OR: basta um dos bits correspondentes ser 1.
        a <= x"F0"; b <= x"0F"; op <= ALU_OR;
        check_result("OR", x"FF", "0010");

        -- XOR: bits iguais produzem 0; diferentes produzem 1.
        a <= x"AA"; b <= x"AA"; op <= ALU_XOR;
        check_result("XOR", x"00", "1000");

        -- NOT: inverte todos os bits de A; B nao e utilizado.
        a <= x"00"; b <= x"5A"; op <= ALU_NOT;
        check_result("NOT", x"FF", "0010");

        -- Codigo nao utilizado: saidas devem assumir o valor padrao zero.
        a <= x"12"; b <= x"34"; op <= "1111";
        check_result("opcode desconhecido", x"00", "1000");

        report "Todos os testes da ULA passaram." severity note;
        stop;
        wait;
    end process;
end architecture test;
