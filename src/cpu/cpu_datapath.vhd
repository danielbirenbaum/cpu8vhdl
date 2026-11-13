library ieee;
use ieee.std_logic_1164.all; -- Tipos logicos e operacoes com bits
use ieee.numeric_std.all; -- Operacoes numericas
use work.cpu_pkg.all; -- Tipos e constantes definidos no pacote da CPU

entity cpu_datapath is
    port (
        clk        : in  std_logic; -- Clock
        rst        : in  std_logic; -- Reset
        ra         : in  regidx_t; -- Endereco do primeiro registrador lido
        rb         : in  regidx_t; -- Endereco do segundo registrador lido
        rd         : in  regidx_t; -- Endereco do registrador de destino
        imm        : in  byte_t; -- Valor imediato (constante da instrucao)
        reg_we     : in  std_logic; -- Habilita escrita no banco de registradores
        result_ld  : in  std_logic; -- Habilita captura do resultado
        flags_we   : in  std_logic; -- Habilita atualizacao das flags
        alu_op     : in  aluop_t; -- Operacao que sera executada pela ULA
        sel_b      : in  std_logic; -- Seleciona registrador ou imediato para a entrada B
        sel_res    : in  std_logic_vector(1 downto 0); -- Seleciona a origem do resultado
        resp_data  : out byte_t; -- Dado do resultado capturado
        resp_idx   : out regidx_t; -- Indice do registrador de destino
        resp_flags : out std_logic_vector(3 downto 0) -- Flags da ULA
    );
end entity cpu_datapath;

architecture rtl of cpu_datapath is
    -- Sinais internos para conectar os componentes
    signal rd_a, rd_b : byte_t; -- Dados lidos dos registradores
    signal op_b       : byte_t; -- Entrada B selecionada para a ULA
    signal alu_result : byte_t; -- Resultado produzido pela ULA
    signal alu_z, alu_c, alu_n, alu_v : std_logic; -- Flags da ULA
    signal wr_data    : byte_t; -- Dado que sera escrito no banco

    -- Registradores internos para armazenar resposta e flags
    signal flags_r : std_logic_vector(3 downto 0) := "0000";
    signal data_r  : byte_t := x"00";
    signal idx_r   : regidx_t := "000";
begin
    -- Instancia o banco de registradores
    u_regs : entity work.reg_file
        port map (
            clk       => clk,
            rst       => rst,
            we        => reg_we, -- Habilita a escrita
            wr_addr   => rd, -- Define o registrador que recebera o dado
            wr_data   => wr_data, -- Dado que sera escrito
            rd_addr_a => ra, -- Endereco do primeiro registrador lido
            rd_addr_b => rb, -- Endereco do segundo registrador lido
            rd_data_a => rd_a, -- Primeiro dado lido
            rd_data_b => rd_b -- Segundo dado lido
        );

    -- Seleciona entre o valor imediato e o segundo registrador
    op_b <= imm when sel_b = SELB_IMM else rd_b;

    -- Instancia a ULA
    u_alu : entity work.alu
        port map (
            a         => rd_a, -- Primeiro operando
            b         => op_b, -- Segundo operando
            op        => alu_op, -- Operacao desejada
            resultado => alu_result, -- Resultado da operacao
            z         => alu_z, -- Flag zero
            c         => alu_c, -- Flag carry
            n         => alu_n, -- Flag negativo
            v         => alu_v -- Flag overflow
        );

    -- Seleciona qual dado sera encaminhado para escrita
    with sel_res select
        wr_data <= alu_result when SELR_ALU, -- Resultado da ULA
                   rd_a       when SELR_A, -- Valor do primeiro registrador
                   rd_b       when SELR_B, -- Valor do segundo registrador
                   imm        when others; -- Valor imediato

    -- Processo sincronizado pelo clock
    process (clk)
    begin
        if rising_edge(clk) then -- Executa na borda de subida do clock
            if rst = '1' then -- Limpa os registradores internos
                flags_r <= "0000";
                data_r  <= x"00";
                idx_r   <= "000";
            else
                -- Atualiza as flags com os valores produzidos pela ULA
                if flags_we = '1' then
                    flags_r(FLAG_Z) <= alu_z;
                    flags_r(FLAG_C) <= alu_c;
                    flags_r(FLAG_N) <= alu_n;
                    flags_r(FLAG_V) <= alu_v;
                end if;

                -- Captura o resultado e o indice do registrador de destino
                if result_ld = '1' then
                    data_r <= wr_data;
                    idx_r  <= rd;
                end if;
            end if;
        end if;
    end process;

    -- Conecta os registradores internos as saidas do modulo
    resp_data  <= data_r;
    resp_idx   <= idx_r;
    resp_flags <= flags_r;
end architecture rtl;