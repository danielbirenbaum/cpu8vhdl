-- =============================================================================
-- tb_command_parser.vhd
-- Comandos validos, registrador fora de R0-R7, operacao desconhecida,
-- imediato invalido, falta de operando, limite de 32 caracteres, CR+LF,
-- rx_error e linha vazia. Verificacao automatica (assert).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity tb_command_parser is
end entity;

architecture sim of tb_command_parser is

  constant T_CLK : time := 20 ns;   -- 50 MHz

  signal clk          : std_logic := '0';
  signal rst          : std_logic := '1';
  signal rx_data      : byte_t := x"00";
  signal rx_valid     : std_logic := '0';
  signal rx_error     : std_logic := '0';
  signal parser_block : std_logic := '0';
  signal opcode       : opcode_t;
  signal rd, ra, rb   : regidx_t;
  signal imm          : byte_t;
  signal cmd_valid    : std_logic;
  signal cmd_error    : std_logic;

  -- monitor
  signal n_valid : integer := 0;
  signal n_error : integer := 0;
  signal sim_end : boolean := false;

begin

  clk <= not clk after T_CLK / 2 when not sim_end else '0';

  dut : entity work.command_parser
    generic map (G_FULL_ISA => true, G_MAX_LEN => 32)
    port map (
      clk => clk, rst => rst,
      rx_data => rx_data, rx_valid => rx_valid, rx_error => rx_error,
      parser_block => parser_block,
      opcode => opcode, rd => rd, ra => ra, rb => rb, imm => imm,
      cmd_valid => cmd_valid, cmd_error => cmd_error);

  -- Modelo simplificado do cpu_control: conta os comandos e bloqueia o
  -- parser por 30 ciclos depois de cada um.
  monitor : process (clk)
    variable blk : integer := 0;
  begin
    if rising_edge(clk) then
      if cmd_valid = '1' then
        n_valid <= n_valid + 1;
      end if;
      if cmd_error = '1' then
        n_error <= n_error + 1;
      end if;
      if cmd_valid = '1' or cmd_error = '1' then
        blk := 30;
        parser_block <= '1';
      elsif blk > 0 then
        blk := blk - 1;
        if blk = 0 then
          parser_block <= '0';
        end if;
      end if;
    end if;
  end process;

  stim : process
    variable errors : integer := 0;
    variable v0, e0 : integer;
    variable v1, e1 : integer;   -- contagem propria do teste de bloqueio

    procedure send_byte(b : byte_t) is
    begin
      wait until rising_edge(clk);
      rx_data  <= b;
      rx_valid <= '1';
      wait until rising_edge(clk);
      rx_valid <= '0';
      for i in 1 to 4 loop               -- intervalo entre bytes
        wait until rising_edge(clk);
      end loop;
    end procedure;

    procedure send_str(s : string) is
    begin
      for i in s'range loop
        send_byte(to_byte(s(i)));
      end loop;
    end procedure;

    procedure idle(n : integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    -- envia a linha + CR e confere um comando valido com os campos esperados
    procedure expect_ok(s : string; op : opcode_t; e_rd, e_ra, e_rb : integer;
                        e_imm : byte_t) is
    begin
      v0 := n_valid; e0 := n_error;
      send_str(s);
      send_byte(ASCII_CR);
      idle(100);
      if n_valid /= v0 + 1 or n_error /= e0 then
        report "FALHA (esperava cmd_valid): """ & s & """" severity error;
        errors := errors + 1;
      elsif opcode /= op or
            to_integer(unsigned(rd)) /= e_rd or
            to_integer(unsigned(ra)) /= e_ra or
            to_integer(unsigned(rb)) /= e_rb or
            imm /= e_imm then
        report "FALHA (campos errados): """ & s & """" severity error;
        errors := errors + 1;
      else
        report "ok   : """ & s & """";
      end if;
    end procedure;

    -- envia a linha + CR e confere cmd_error
    procedure expect_err(s : string) is
    begin
      v0 := n_valid; e0 := n_error;
      send_str(s);
      send_byte(ASCII_CR);
      idle(100);
      if n_error /= e0 + 1 or n_valid /= v0 then
        report "FALHA (esperava cmd_error): """ & s & """" severity error;
        errors := errors + 1;
      else
        report "ok   : ERR para """ & s & """";
      end if;
    end procedure;

  begin
    rst <= '1';
    idle(5);
    rst <= '0';
    idle(5);

    -- ---------------- comandos validos ----------------
    expect_ok("LDI R1,05",        OP_LDI,  1, 0, 0, x"05");
    expect_ok("LDI R2, 03",       OP_LDI,  2, 0, 0, x"03");
    expect_ok("ADD R3,R1,R2",     OP_ADD,  3, 1, 2, x"00");
    expect_ok("ADD R3, R1, R2",   OP_ADD,  3, 1, 2, x"00");
    expect_ok("ADD R1,R1,R2",     OP_ADD,  1, 1, 2, x"00");
    expect_ok("SUB R4,R3,R1",     OP_SUB,  4, 3, 1, x"00");
    expect_ok("AND R5,R0,R7",     OP_AND,  5, 0, 7, x"00");
    expect_ok("OR R6,R5,R4",      OP_OR,   6, 5, 4, x"00");
    expect_ok("XOR R0,R1,R2",     OP_XOR,  0, 1, 2, x"00");
    expect_ok("NOT R7,R6",        OP_NOT,  7, 6, 0, x"00");
    expect_ok("MOV R2,R7",        OP_MOV,  2, 7, 0, x"00");
    expect_ok("ADDI R7,R6,FF",    OP_ADDI, 7, 6, 0, x"FF");
    expect_ok("LDI R0,A5",        OP_LDI,  0, 0, 0, x"A5");
    expect_ok("LDI R1 , 7F  ",    OP_LDI,  1, 0, 0, x"7F");
    -- exatamente 32 caracteres (12 + 20 espacos no final)
    expect_ok("ADD R3,R1,R2                    ", OP_ADD, 3, 1, 2, x"00");

    -- ---------------- comandos invalidos ----------------
    expect_err("ADD R8,R1,R2");          -- registrador fora de R0-R7
    expect_err("MUL R1,R2,R3");          -- operacao desconhecida
    expect_err("LDI R1,5");              -- imediato com 1 digito
    expect_err("LDI R1,005");            -- imediato com 3 digitos
    expect_err("LDI R1,0G");             -- digito hex invalido
    expect_err("LDI R1,0f");             -- minuscula
    expect_err("add r1,r2,r3");          -- minusculas
    expect_err("ADD R3,R1");             -- falta operando
    expect_err("ADD R3,R1,");            -- virgula sobrando
    expect_err("ADD R3,R1,R2,R4");       -- operando sobrando
    expect_err("ADD R3 R1 R2");          -- sem virgulas
    expect_err("LDI R1,R2");             -- tipo de operando errado
    expect_err("ADD");                   -- so a operacao
    expect_err("ADDIX R1,R2,03");        -- operacao longa demais
    expect_err(" LDI R1,05");            -- espaco no inicio
    -- 33 caracteres
    expect_err("ADD R3,R1,R2                     ");

    -- ---------------- CR+LF: exatamente um comando ----------------
    v0 := n_valid; e0 := n_error;
    send_str("LDI R4,10");
    send_byte(ASCII_CR);
    send_byte(ASCII_LF);
    idle(100);
    if n_valid /= v0 + 1 or n_error /= e0 then
      report "FALHA: CR+LF gerou resposta errada" severity error;
      errors := errors + 1;
    else
      report "ok   : CR+LF gera um unico comando";
    end if;

    -- ---------------- LF sozinho como terminador ----------------
    v0 := n_valid; e0 := n_error;
    send_str("LDI R5,20");
    send_byte(ASCII_LF);
    idle(100);
    if n_valid /= v0 + 1 or n_error /= e0 then
      report "FALHA: terminador LF" severity error;
      errors := errors + 1;
    else
      report "ok   : terminador LF";
    end if;

    -- ---------------- linha vazia: ignorada ----------------
    v0 := n_valid; e0 := n_error;
    send_byte(ASCII_CR);
    idle(100);
    if n_valid /= v0 or n_error /= e0 then
      report "FALHA: linha vazia gerou comando" severity error;
      errors := errors + 1;
    else
      report "ok   : linha vazia ignorada";
    end if;

    -- ---------------- rx_error no meio da linha ----------------
    v0 := n_valid; e0 := n_error;
    send_str("LDI R1");
    wait until rising_edge(clk);
    rx_error <= '1';
    wait until rising_edge(clk);
    rx_error <= '0';
    send_str(",05");
    send_byte(ASCII_CR);
    idle(100);
    if n_error /= e0 + 1 or n_valid /= v0 then
      report "FALHA: rx_error nao invalidou a linha" severity error;
      errors := errors + 1;
    else
      report "ok   : rx_error invalida a linha";
    end if;

    -- ---------------- bytes durante o bloqueio sao descartados ----------------
    v1 := n_valid; e1 := n_error;
    send_str("LDI R1,05");
    send_byte(ASCII_CR);                  -- parser bloqueia por 30 ciclos
    idle(10);
    send_str("XX");                       -- chega durante o bloqueio
    idle(100);
    expect_ok("LDI R2,06", OP_LDI, 2, 0, 0, x"06");   -- linha seguinte limpa
    if n_valid /= v1 + 2 or n_error /= e1 then
      report "FALHA: bytes durante o bloqueio nao foram descartados" severity error;
      errors := errors + 1;
    else
      report "ok   : bytes descartados durante o bloqueio";
    end if;

    -- ---------------- resultado ----------------
    if errors = 0 then
      report "tb_command_parser: TODOS OS TESTES PASSARAM";
    else
      report "tb_command_parser: " & integer'image(errors) & " FALHA(S)" severity error;
    end if;
    sim_end <= true;
    wait;
  end process;

end architecture sim;
