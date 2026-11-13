-- =============================================================================
-- cpu_pkg.vhd
-- Pacote compartilhado: codigos de operacao, codigos da ULA, selecoes dos MUXes
-- e funcoes auxiliares de ASCII.
--
-- Autor: Lucas Elbert (parser, unidade de controle e formatacao da resposta)
--
-- IMPORTANTE PARA A INTEGRACAO:
--   * ALU_*   precisa coincidir com a codificacao de alu_op usada em alu.vhd (Luan).
--   * SELB_* e SELR_* precisam coincidir com os MUXes de cpu_datapath.vhd (Luan).
--   * A ordem das flags em resp_flags(3 downto 0) e: Z, C, N, V.
--   Se o datapath usar outros valores, basta alterar as constantes aqui.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package cpu_pkg is

  subtype byte_t   is std_logic_vector(7 downto 0);
  subtype opcode_t is std_logic_vector(3 downto 0);
  subtype aluop_t  is std_logic_vector(3 downto 0);
  subtype regidx_t is std_logic_vector(2 downto 0);

  -- ---------------------------------------------------------------------------
  -- Opcodes (gerados pelo command_parser, consumidos pelo cpu_control)
  -- ---------------------------------------------------------------------------
  --   Sintaxe aceita                  Operacao               Flags
  --   LDI  Rd,HH                      Rd <- HH               preserva
  --   ADD  Rd,Ra,Rb                   Rd <- Ra + Rb          atualiza
  --   SUB  Rd,Ra,Rb                   Rd <- Ra - Rb          atualiza
  --   AND  Rd,Ra,Rb                   Rd <- Ra and Rb        atualiza
  --   OR   Rd,Ra,Rb                   Rd <- Ra or  Rb        atualiza
  --   XOR  Rd,Ra,Rb                   Rd <- Ra xor Rb        atualiza
  --   NOT  Rd,Ra                      Rd <- not Ra           atualiza
  --   MOV  Rd,Ra                      Rd <- Ra               preserva
  --   ADDI Rd,Ra,HH                   Rd <- Ra + HH          atualiza
  constant OP_LDI  : opcode_t := "0000";
  constant OP_ADD  : opcode_t := "0001";
  constant OP_SUB  : opcode_t := "0010";
  constant OP_AND  : opcode_t := "0011";
  constant OP_OR   : opcode_t := "0100";
  constant OP_XOR  : opcode_t := "0101";
  constant OP_NOT  : opcode_t := "0110";
  constant OP_MOV  : opcode_t := "0111";
  constant OP_ADDI : opcode_t := "1000";

  -- ---------------------------------------------------------------------------
  -- Codigos da ULA (alu_op) -- alinhar com alu.vhd
  -- ---------------------------------------------------------------------------
  constant ALU_ADD : aluop_t := "0000";
  constant ALU_SUB : aluop_t := "0001";
  constant ALU_AND : aluop_t := "0010";
  constant ALU_OR  : aluop_t := "0011";
  constant ALU_XOR : aluop_t := "0100";
  constant ALU_NOT : aluop_t := "0101";   -- opera sobre A (Ra)

  -- ---------------------------------------------------------------------------
  -- Selecoes dos MUXes do datapath -- alinhar com cpu_datapath.vhd
  -- ---------------------------------------------------------------------------
  -- MUX B: segundo operando da ULA
  constant SELB_REG : std_logic := '0';   -- segunda leitura do banco (Rb)
  constant SELB_IMM : std_logic := '1';   -- imediato
  -- MUX Resultado: dado escrito no banco (wr_data) e capturado para a resposta
  constant SELR_ALU : std_logic_vector(1 downto 0) := "00";  -- alu_result
  constant SELR_A   : std_logic_vector(1 downto 0) := "01";  -- primeira leitura (Ra)
  constant SELR_B   : std_logic_vector(1 downto 0) := "10";  -- segunda leitura (Rb)
  constant SELR_IMM : std_logic_vector(1 downto 0) := "11";  -- imediato

  -- Indices das flags em resp_flags
  constant FLAG_Z : natural := 3;
  constant FLAG_C : natural := 2;
  constant FLAG_N : natural := 1;
  constant FLAG_V : natural := 0;

  -- ---------------------------------------------------------------------------
  -- ASCII
  -- ---------------------------------------------------------------------------
  constant ASCII_CR    : byte_t := x"0D";
  constant ASCII_LF    : byte_t := x"0A";
  constant ASCII_SPACE : byte_t := x"20";
  constant ASCII_COMMA : byte_t := x"2C";
  constant ASCII_EQUAL : byte_t := x"3D";

  -- Caractere VHDL -> byte ASCII
  function to_byte(c : character) return byte_t;
  -- Nibble (0..F) -> caractere ASCII '0'..'9','A'..'F'
  function hex_ascii(n : std_logic_vector(3 downto 0)) return byte_t;
  -- Bit -> '0' ou '1'
  function bit_ascii(b : std_logic) return byte_t;
  -- Testes de classe de caractere (somente maiusculas)
  function is_hex(b : byte_t) return boolean;
  function is_upper(b : byte_t) return boolean;
  -- Digito hexadecimal ASCII -> nibble (supoe is_hex = true)
  function hex_val(b : byte_t) return std_logic_vector;
  -- Empacota um mnemonico de ate 4 letras, alinhado a direita e
  -- completado com espacos a esquerda. Ex.: "ADD" -> x"20414444"
  function pack4(s : string) return std_logic_vector;

end package cpu_pkg;

package body cpu_pkg is

  function to_byte(c : character) return byte_t is
  begin
    return std_logic_vector(to_unsigned(character'pos(c), 8));
  end function;

  function hex_ascii(n : std_logic_vector(3 downto 0)) return byte_t is
  begin
    if unsigned(n) < 10 then
      return std_logic_vector(to_unsigned(16#30#, 8) + unsigned(n));  -- '0'..'9'
    else
      return std_logic_vector(to_unsigned(16#37#, 8) + unsigned(n));  -- 'A'..'F'
    end if;
  end function;

  function bit_ascii(b : std_logic) return byte_t is
  begin
    if b = '1' then
      return x"31";
    else
      return x"30";
    end if;
  end function;

  function is_hex(b : byte_t) return boolean is
    variable u : unsigned(7 downto 0);
  begin
    u := unsigned(b);
    return (u >= 16#30# and u <= 16#39#) or (u >= 16#41# and u <= 16#46#);
  end function;

  function is_upper(b : byte_t) return boolean is
    variable u : unsigned(7 downto 0);
  begin
    u := unsigned(b);
    return (u >= 16#41# and u <= 16#5A#);
  end function;

  function hex_val(b : byte_t) return std_logic_vector is
    variable r : unsigned(3 downto 0);
  begin
    if unsigned(b) <= 16#39# then
      r := unsigned(b(3 downto 0));               -- '0'..'9'
    else
      r := unsigned(b(3 downto 0)) + 9;           -- 'A'(0x41)..'F'(0x46)
    end if;
    return std_logic_vector(r);
  end function;

  function pack4(s : string) return std_logic_vector is
    variable r : std_logic_vector(31 downto 0) := x"20202020";
  begin
    for i in s'range loop
      r := r(23 downto 0) & to_byte(s(i));
    end loop;
    return r;
  end function;

end package body cpu_pkg;
