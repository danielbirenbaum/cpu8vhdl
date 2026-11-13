-- Testbench de integracao do CPU Datapath.
-- Testa o banco + MUX B + ULA + MUX Resultado + captura de resultado/flags.
-- Os sinais de controle sao aplicados diretamente, sem instanciar cpu_control.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.cpu_pkg.all;

entity tb_cpu_datapath_unit is
end entity tb_cpu_datapath_unit;

architecture test of tb_cpu_datapath_unit is
    signal clk        : std_logic := '0';
    signal rst        : std_logic := '0';
    signal ra         : regidx_t := "000";
    signal rb         : regidx_t := "000";
    signal rd         : regidx_t := "000";
    signal imm        : byte_t := x"00";
    signal reg_we     : std_logic := '0';
    signal result_ld  : std_logic := '0';
    signal flags_we   : std_logic := '0';
    signal alu_op     : aluop_t := ALU_ADD;
    signal sel_b      : std_logic := SELB_REG;
    signal sel_res    : std_logic_vector(1 downto 0) := SELR_ALU;
    signal resp_data  : byte_t;
    signal resp_idx   : regidx_t;
    signal resp_flags : std_logic_vector(3 downto 0);
begin
    clk <= not clk after 5 ns;

    dut : entity work.cpu_datapath
        port map (
            clk        => clk,
            rst        => rst,
            ra         => ra,
            rb         => rb,
            rd         => rd,
            imm        => imm,
            reg_we     => reg_we,
            result_ld  => result_ld,
            flags_we   => flags_we,
            alu_op     => alu_op,
            sel_b      => sel_b,
            sel_res    => sel_res,
            resp_data  => resp_data,
            resp_idx   => resp_idx,
            resp_flags => resp_flags
        );

    stimulus : process
        -- Carrega um imediato diretamente em um registrador usando o MUX Resultado.
        procedure load_imm(
            constant destination : in natural;
            constant value       : in byte_t
        ) is
        begin
            ra <= "000";
            rb <= "000";
            rd <= std_logic_vector(to_unsigned(destination, 3));
            imm <= value;
            sel_b <= SELB_IMM;
            sel_res <= SELR_IMM;
            alu_op <= ALU_ADD;
            reg_we <= '1';
            result_ld <= '0';
            flags_we <= '0';
            wait for 1 ns;
            wait until rising_edge(clk);
            wait for 1 ns;
            reg_we <= '0';
            wait for 1 ns;
        end procedure;

        -- Executa um caminho do datapath e, opcionalmente, atualiza as flags.
        procedure execute_and_capture(
            constant source_a     : in natural;
            constant source_b     : in natural;
            constant destination  : in natural;
            constant operation    : in aluop_t;
            constant b_select     : in std_logic;
            constant result_select: in std_logic_vector(1 downto 0);
            constant immediate    : in byte_t;
            constant update_flags : in std_logic
        ) is
        begin
            ra <= std_logic_vector(to_unsigned(source_a, 3));
            rb <= std_logic_vector(to_unsigned(source_b, 3));
            rd <= std_logic_vector(to_unsigned(destination, 3));
            imm <= immediate;
            alu_op <= operation;
            sel_b <= b_select;
            sel_res <= result_select;

            -- Deixa banco/MUX/ULA estabilizarem antes da borda de escrita.
            wait for 1 ns;
            reg_we <= '1';
            result_ld <= '1';
            flags_we <= update_flags;
            wait until rising_edge(clk);
            wait for 1 ns;
            reg_we <= '0';
            result_ld <= '0';
            flags_we <= '0';
            wait for 1 ns;
        end procedure;

        procedure check_response(
            constant test_name : in string;
            constant exp_data  : in byte_t;
            constant exp_idx   : in regidx_t;
            constant exp_flags : in std_logic_vector(3 downto 0)
        ) is
        begin
            assert resp_data = exp_data
                report "Falha em " & test_name & ": resp_data incorreto"
                severity failure;
            assert resp_idx = exp_idx
                report "Falha em " & test_name & ": resp_idx incorreto"
                severity failure;
            assert resp_flags = exp_flags
                report "Falha em " & test_name & ": resp_flags incorretas (ordem Z C N V)"
                severity failure;
            report "PASS: " & test_name severity note;
        end procedure;
    begin
        -- Reset dos registradores, da captura e das flags.
        rst <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert resp_data = x"00" and resp_idx = "000" and resp_flags = "0000"
            report "Falha no reset do datapath" severity failure;
        report "PASS: reset do datapath" severity note;
        rst <= '0';
        wait for 1 ns;

        -- Prepara R1=F0 e R2=0F.
        load_imm(1, x"F0");
        load_imm(2, x"0F");

        -- ADD R3,R1,R2: F0 + 0F = FF. Verifica MUX B selecionando Rb.
        execute_and_capture(1, 2, 3, ALU_ADD, SELB_REG, SELR_ALU, x"00", '1');
        check_response("ADD e MUX B por registrador", x"FF", "011", "0010");

        -- AND R4,R1,R2: F0 AND 0F = 00; Z=1.
        execute_and_capture(1, 2, 4, ALU_AND, SELB_REG, SELR_ALU, x"00", '1');
        check_response("AND e flag Z", x"00", "100", "1000");

        -- OR R5,R1,R2: F0 OR 0F = FF; N=1.
        execute_and_capture(1, 2, 5, ALU_OR, SELB_REG, SELR_ALU, x"00", '1');
        check_response("OR e flag N", x"FF", "101", "0010");

        -- XOR R6,R1,R2: F0 XOR 0F = FF.
        execute_and_capture(1, 2, 6, ALU_XOR, SELB_REG, SELR_ALU, x"00", '1');
        check_response("XOR", x"FF", "110", "0010");

        -- NOT R7,R1: NOT F0 = 0F. A ULA usa somente A.
        execute_and_capture(1, 0, 7, ALU_NOT, SELB_REG, SELR_ALU, x"00", '1');
        check_response("NOT", x"0F", "111", "0000");

        -- ADDI R3,R1,10: F0 + 10 = 100; 8 bits -> 00, Z=1 e C=1.
        execute_and_capture(1, 0, 3, ALU_ADD, SELB_IMM, SELR_ALU, x"10", '1');
        check_response("ADDI e MUX B por imediato", x"00", "011", "1100");

        -- SUB R3,R1,R2: F0 - 0F = E1; sem borrow, N=1.
        execute_and_capture(1, 2, 3, ALU_SUB, SELB_REG, SELR_ALU, x"00", '1');
        check_response("SUB", x"E1", "011", "0110");

        -- MOV R4,R1: MUX Resultado seleciona A; flags devem ser preservadas.
        execute_and_capture(1, 0, 4, ALU_ADD, SELB_REG, SELR_A, x"00", '0');
        check_response("MOV pelo MUX Resultado A e preservacao das flags", x"F0", "100", "0110");

        -- LDI R5,AA: MUX Resultado seleciona o imediato; flags preservadas.
        execute_and_capture(0, 0, 5, ALU_ADD, SELB_IMM, SELR_IMM, x"AA", '0');
        check_response("LDI pelo MUX Resultado imediato", x"AA", "101", "0110");

        -- Caminho direto B do MUX Resultado: copia R2 para R6.
        execute_and_capture(0, 2, 6, ALU_ADD, SELB_REG, SELR_B, x"00", '0');
        check_response("MUX Resultado B", x"0F", "110", "0110");

        -- Destino igual a uma fonte: ADD R1,R1,R2. A captura deve guardar FF
        -- mesmo na mesma borda em que R1 e sobrescrito.
        execute_and_capture(1, 2, 1, ALU_ADD, SELB_REG, SELR_ALU, x"00", '1');
        check_response("destino igual a fonte", x"FF", "001", "0010");

        -- Le R1 novamente por MOV; confirma que a escrita no banco ocorreu.
        execute_and_capture(1, 0, 7, ALU_ADD, SELB_REG, SELR_A, x"00", '0');
        check_response("confirmacao da escrita no banco", x"FF", "111", "0010");

        report "Todos os testes do CPU Datapath passaram." severity note;
        stop;
        wait;
    end process;
end architecture test;
