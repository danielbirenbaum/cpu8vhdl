-- =============================================================================
-- tb_lucas_integracao.vhd
-- Integra command_parser + cpu_control + response_formatter com:
--   * o cpu_datapath real (reg_file + alu do Luan);
--   * um modelo de uart_tx (busy por alguns ciclos por byte).
-- Os bytes de entrada sao entregues direto como rx_data/rx_valid (sem quadro
-- serial). Confere o texto exato das respostas.
--
-- Criterio do M1: LDI R1,05 ; LDI R2,03 ; ADD R3,R1,R2 -> "R3 = 08" (+ flags
-- no M2) e um comando invalido -> ERR sem alterar registradores.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity tb_lucas_integracao is
end entity;

architecture sim of tb_lucas_integracao is

  constant T_CLK    : time    := 20 ns;
  constant BUSY_CYC : integer := 12;
  constant CR : character := character'val(13);
  constant LF : character := character'val(10);

  signal clk, rst : std_logic := '0';
  signal sim_end  : boolean := false;

  -- uart_rx (estimulo)
  signal rx_data  : byte_t := x"00";
  signal rx_valid : std_logic := '0';
  signal rx_error : std_logic := '0';

  -- parser -> controle
  signal p_opcode : opcode_t;
  signal p_rd, p_ra, p_rb : regidx_t;
  signal p_imm : byte_t;
  signal cmd_valid, cmd_error, parser_block : std_logic;

  -- controle -> datapath / formatter
  signal ra, rb, rd : regidx_t;
  signal imm : byte_t;
  signal reg_we, result_ld, flags_we, sel_b : std_logic;
  signal alu_op  : aluop_t;
  signal sel_res : std_logic_vector(1 downto 0);
  signal resp_valid, resp_err, resp_show_flags, format_done : std_logic;

  -- datapath -> formatter
  signal flags      : std_logic_vector(3 downto 0);
  signal resp_data  : byte_t;
  signal resp_idx   : regidx_t;

  -- uart_tx (modelo)
  signal tx_data  : byte_t;
  signal tx_valid : std_logic;
  signal tx_busy  : std_logic := '0';
  signal cap_str  : string(1 to 64) := (others => ' ');
  signal cap_len  : integer := 0;
  signal cap_clear: std_logic := '0';

begin

  clk <= not clk after T_CLK / 2 when not sim_end else '0';

  u_parser : entity work.command_parser
    generic map (G_FULL_ISA => true)
    port map (clk => clk, rst => rst,
              rx_data => rx_data, rx_valid => rx_valid, rx_error => rx_error,
              parser_block => parser_block,
              opcode => p_opcode, rd => p_rd, ra => p_ra, rb => p_rb, imm => p_imm,
              cmd_valid => cmd_valid, cmd_error => cmd_error);

  u_control : entity work.cpu_control
    port map (clk => clk, rst => rst,
              cmd_valid => cmd_valid, cmd_error => cmd_error,
              opcode_i => p_opcode, rd_i => p_rd, ra_i => p_ra, rb_i => p_rb,
              imm_i => p_imm, format_done => format_done,
              parser_block => parser_block,
              resp_valid => resp_valid, resp_err => resp_err,
              resp_show_flags => resp_show_flags,
              ra => ra, rb => rb, rd => rd, imm => imm,
              reg_we => reg_we, result_ld => result_ld, flags_we => flags_we,
              alu_op => alu_op, sel_b => sel_b, sel_res => sel_res);

  u_fmt : entity work.response_formatter
    generic map (G_FLAGS_EN => true)
    port map (clk => clk, rst => rst,
              resp_valid => resp_valid, resp_err => resp_err,
              resp_show_flags => resp_show_flags,
              resp_idx => resp_idx, resp_data => resp_data, resp_flags => flags,
              tx_busy => tx_busy, tx_data => tx_data, tx_valid => tx_valid,
              format_done => format_done);

  -- ---------------------------------------------------------------------------
  -- Datapath real (cpu_datapath + reg_file + alu)
  -- ---------------------------------------------------------------------------
  u_dp : entity work.cpu_datapath
    port map (clk => clk, rst => rst,
              ra => ra, rb => rb, rd => rd, imm => imm,
              reg_we => reg_we, result_ld => result_ld, flags_we => flags_we,
              alu_op => alu_op, sel_b => sel_b, sel_res => sel_res,
              resp_data => resp_data, resp_idx => resp_idx, resp_flags => flags);

  -- ---------------------------------------------------------------------------
  -- Modelo da uart_tx
  -- ---------------------------------------------------------------------------
  uart_model : process (clk)
    variable cnt : integer := 0;
  begin
    if rising_edge(clk) then
      if cap_clear = '1' then
        cap_len <= 0;
      end if;
      if tx_valid = '1' and tx_busy = '0' then
        if cap_clear = '0' and cap_len < 64 then
          cap_str(cap_len + 1) <= character'val(to_integer(unsigned(tx_data)));
          cap_len <= cap_len + 1;
        end if;
        tx_busy <= '1';
        cnt := BUSY_CYC;
      elsif cnt > 0 then
        cnt := cnt - 1;
        if cnt = 0 then
          tx_busy <= '0';
        end if;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- Estimulos
  -- ---------------------------------------------------------------------------
  stim : process
    variable errors : integer := 0;

    procedure idle(n : integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    procedure send_byte(b : byte_t) is
    begin
      wait until rising_edge(clk);
      rx_data  <= b;
      rx_valid <= '1';
      wait until rising_edge(clk);
      rx_valid <= '0';
      idle(8);
    end procedure;

    -- envia "linha" + CR + LF e confere a resposta completa
    procedure cmd(line : string; expected : string) is
      variable ok : boolean;
    begin
      cap_clear <= '1';
      wait until rising_edge(clk);
      cap_clear <= '0';
      for i in line'range loop
        send_byte(to_byte(line(i)));
      end loop;
      send_byte(ASCII_CR);
      send_byte(ASCII_LF);
      idle(40 * BUSY_CYC);                 -- tempo para a resposta inteira

      ok := (cap_len = expected'length);
      if ok then
        for i in 1 to expected'length loop
          if cap_str(i) /= expected(expected'low + i - 1) then
            ok := false;
          end if;
        end loop;
      end if;
      if ok then
        report "ok   : " & line;
      else
        report "FALHA: " & line & " -> recebido """ & cap_str(1 to cap_len) &
               """, esperado """ & expected & """" severity error;
        errors := errors + 1;
      end if;
    end procedure;

    constant NL : string := CR & LF;

  begin
    rst <= '1';
    idle(5);
    rst <= '0';
    idle(5);

    -- criterio do M1 (no M2 o ADD inclui as flags)
    cmd("LDI R1,05",      "R1 = 05" & NL);
    cmd("LDI R2,03",      "R2 = 03" & NL);
    cmd("ADD R3,R1,R2",   "R3 = 08 Z=0 C=0 N=0 V=0" & NL);

    -- erro nao altera registradores
    cmd("ADD R3,R1,R9",   "ERR" & NL);
    cmd("MOV R4,R3",      "R4 = 08" & NL);

    -- destino igual a fonte
    cmd("ADD R1,R1,R2",   "R1 = 08 Z=0 C=0 N=0 V=0" & NL);

    -- carry: 255 + 1
    cmd("LDI R5,FF",      "R5 = FF" & NL);
    cmd("ADDI R6,R5,01",  "R6 = 00 Z=1 C=1 N=0 V=0" & NL);
    -- LDI preserva as flags; o proximo ADD mostra as novas
    cmd("LDI R7,7F",      "R7 = 7F" & NL);
    -- overflow: 127 + 1
    cmd("ADDI R7,R7,01",  "R7 = 80 Z=0 C=0 N=1 V=1" & NL);

    -- subtracao sem e com emprestimo (C = 1 indica ausencia de emprestimo)
    cmd("SUB R0,R3,R2",   "R0 = 05 Z=0 C=1 N=0 V=0" & NL);
    cmd("SUB R0,R2,R3",   "R0 = FB Z=0 C=0 N=1 V=0" & NL);

    -- logicas: C e V zerados
    cmd("AND R0,R5,R3",   "R0 = 08 Z=0 C=0 N=0 V=0" & NL);
    cmd("OR R0,R1,R2",    "R0 = 0B Z=0 C=0 N=0 V=0" & NL);
    cmd("XOR R0,R5,R5",   "R0 = 00 Z=1 C=0 N=0 V=0" & NL);
    cmd("NOT R0,R5",      "R0 = 00 Z=1 C=0 N=0 V=0" & NL);

    -- comandos invalidos
    cmd("LDI R1,5",       "ERR" & NL);
    cmd("add r1,r2,r3",   "ERR" & NL);
    cmd("LDI R1,05",      "R1 = 05" & NL);      -- recuperacao apos erro

    if errors = 0 then
      report "tb_lucas_integracao: TODOS OS TESTES PASSARAM";
    else
      report "tb_lucas_integracao: " & integer'image(errors) & " FALHA(S)"
        severity error;
    end if;
    sim_end <= true;
    wait;
  end process;

end architecture sim;
