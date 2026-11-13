-- =============================================================================
-- tb_cpu_control.vhd
-- Uma escrita por comando; erro nao escreve no banco; selecoes estaveis em
-- EXECUTA; controle de flags (flags_we); resp_valid/resp_err; parser_block;
-- transicao para LIBERA/RECEBE apos format_done.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity tb_cpu_control is
end entity;

architecture sim of tb_cpu_control is

  constant T_CLK : time := 20 ns;

  signal clk             : std_logic := '0';
  signal rst             : std_logic := '1';
  signal cmd_valid       : std_logic := '0';
  signal cmd_error       : std_logic := '0';
  signal opcode_i        : opcode_t := OP_LDI;
  signal rd_i, ra_i, rb_i: regidx_t := "000";
  signal imm_i           : byte_t := x"00";
  signal format_done     : std_logic := '0';
  signal parser_block    : std_logic;
  signal resp_valid      : std_logic;
  signal resp_err        : std_logic;
  signal resp_show_flags : std_logic;
  signal ra, rb, rd      : regidx_t;
  signal imm             : byte_t;
  signal reg_we          : std_logic;
  signal result_ld       : std_logic;
  signal flags_we        : std_logic;
  signal alu_op          : aluop_t;
  signal sel_b           : std_logic;
  signal sel_res         : std_logic_vector(1 downto 0);

  -- monitor
  signal n_we, n_ld, n_fw : integer := 0;
  signal unstable         : integer := 0;   -- selecoes mudaram durante parser_block
  signal sim_end          : boolean := false;

begin

  clk <= not clk after T_CLK / 2 when not sim_end else '0';

  dut : entity work.cpu_control
    generic map (G_EXEC_CYCLES => 2)
    port map (
      clk => clk, rst => rst,
      cmd_valid => cmd_valid, cmd_error => cmd_error,
      opcode_i => opcode_i, rd_i => rd_i, ra_i => ra_i, rb_i => rb_i,
      imm_i => imm_i, format_done => format_done,
      parser_block => parser_block, resp_valid => resp_valid,
      resp_err => resp_err, resp_show_flags => resp_show_flags,
      ra => ra, rb => rb, rd => rd, imm => imm,
      reg_we => reg_we, result_ld => result_ld, flags_we => flags_we,
      alu_op => alu_op, sel_b => sel_b, sel_res => sel_res);

  -- Conta pulsos de escrita e verifica estabilidade das selecoes
  monitor : process (clk)
    variable prev_sel : std_logic_vector(15 downto 0) := (others => '0');
    variable cur_sel  : std_logic_vector(15 downto 0);
    variable prev_blk : std_logic := '0';
  begin
    if rising_edge(clk) then
      if reg_we = '1' then
        n_we <= n_we + 1;
      end if;
      if result_ld = '1' then
        n_ld <= n_ld + 1;
      end if;
      if flags_we = '1' then
        n_fw <= n_fw + 1;
      end if;
      if reg_we /= result_ld then
        unstable <= unstable + 1;          -- devem ocorrer na mesma borda
      end if;
      cur_sel := alu_op & sel_b & sel_res & ra & rb & rd;
      if prev_blk = '1' and parser_block = '1' and cur_sel /= prev_sel then
        unstable <= unstable + 1;
      end if;
      prev_sel := cur_sel;
      prev_blk := parser_block;
    end if;
  end process;

  stim : process
    variable errors : integer := 0;
    variable we0, ld0, fw0 : integer;

    procedure idle(n : integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    procedure check(cond : boolean; msg : string) is
    begin
      if not cond then
        report "FALHA: " & msg severity error;
        errors := errors + 1;
      end if;
    end procedure;

    -- Envia um comando valido, espera resp_valid, confere as selecoes
    -- capturadas, emula o formatter (format_done) e confere a liberacao.
    procedure run_cmd(op : opcode_t; d, a, b : integer; im : byte_t;
                      e_alu : aluop_t; e_selb : std_logic;
                      e_selr : std_logic_vector(1 downto 0);
                      e_flags : std_logic; name : string) is
    begin
      we0 := n_we; ld0 := n_ld; fw0 := n_fw;
      wait until rising_edge(clk);
      opcode_i  <= op;
      rd_i      <= std_logic_vector(to_unsigned(d, 3));
      ra_i      <= std_logic_vector(to_unsigned(a, 3));
      rb_i      <= std_logic_vector(to_unsigned(b, 3));
      imm_i     <= im;
      cmd_valid <= '1';
      wait until rising_edge(clk);
      cmd_valid <= '0';
      opcode_i  <= OP_LDI;               -- o parser poderia mudar os campos;
      imm_i     <= x"EE";                -- a UC deve ter guardado a copia

      wait until rising_edge(clk) and reg_we = '1' for 1 us;
      check(reg_we = '1', name & ": reg_we nao pulsou");
      check(parser_block = '1', name & ": parser deveria estar bloqueado");
      check(alu_op = e_alu or e_selr /= SELR_ALU, name & ": alu_op");
      check(sel_b = e_selb or e_selr /= SELR_ALU, name & ": sel_b");
      check(sel_res = e_selr, name & ": sel_res");
      check(to_integer(unsigned(rd)) = d, name & ": rd");
      check(to_integer(unsigned(ra)) = a, name & ": ra");
      check(to_integer(unsigned(rb)) = b, name & ": rb");
      check(imm = im, name & ": imm");
      check(flags_we = e_flags, name & ": flags_we");

      wait until rising_edge(clk) and resp_valid = '1' for 1 us;
      check(resp_valid = '1', name & ": resp_valid nao subiu");
      check(resp_err = '0', name & ": resp_err deveria ser 0");
      check(resp_show_flags = e_flags, name & ": resp_show_flags");

      idle(20);                           -- formatter enviando
      check(resp_valid = '1', name & ": resp_valid caiu antes de format_done");
      format_done <= '1';
      wait until rising_edge(clk);
      format_done <= '0';
      wait until rising_edge(clk);        -- LIBERA
      check(parser_block = '0', name & ": parser nao foi liberado");
      check(resp_valid = '0', name & ": resp_valid deveria cair");
      idle(3);
      check(n_we = we0 + 1, name & ": esperava exatamente 1 escrita");
      check(n_ld = ld0 + 1, name & ": esperava exatamente 1 captura");
      if e_flags = '1' then
        check(n_fw = fw0 + 1, name & ": flags deveriam ser atualizadas");
      else
        check(n_fw = fw0, name & ": flags deveriam ser preservadas");
      end if;
      report "ok   : " & name;
    end procedure;

  begin
    rst <= '1';
    idle(5);
    rst <= '0';
    idle(5);
    check(parser_block = '0', "parser bloqueado apos reset");

    --        op       rd ra rb imm    alu_op   sel_b     sel_res   flags
    run_cmd(OP_LDI,  1, 0, 0, x"05", ALU_ADD, SELB_REG, SELR_IMM, '0', "LDI R1,05");
    run_cmd(OP_LDI,  2, 0, 0, x"03", ALU_ADD, SELB_REG, SELR_IMM, '0', "LDI R2,03");
    run_cmd(OP_ADD,  3, 1, 2, x"00", ALU_ADD, SELB_REG, SELR_ALU, '1', "ADD R3,R1,R2");
    run_cmd(OP_ADD,  1, 1, 2, x"00", ALU_ADD, SELB_REG, SELR_ALU, '1', "ADD R1,R1,R2");
    run_cmd(OP_SUB,  4, 3, 1, x"00", ALU_SUB, SELB_REG, SELR_ALU, '1', "SUB R4,R3,R1");
    run_cmd(OP_AND,  5, 0, 7, x"00", ALU_AND, SELB_REG, SELR_ALU, '1', "AND R5,R0,R7");
    run_cmd(OP_OR,   6, 5, 4, x"00", ALU_OR,  SELB_REG, SELR_ALU, '1', "OR R6,R5,R4");
    run_cmd(OP_XOR,  0, 1, 2, x"00", ALU_XOR, SELB_REG, SELR_ALU, '1', "XOR R0,R1,R2");
    run_cmd(OP_NOT,  7, 6, 0, x"00", ALU_NOT, SELB_REG, SELR_ALU, '1', "NOT R7,R6");
    run_cmd(OP_MOV,  2, 7, 0, x"00", ALU_ADD, SELB_REG, SELR_A,   '0', "MOV R2,R7");
    run_cmd(OP_ADDI, 7, 6, 0, x"FF", ALU_ADD, SELB_IMM, SELR_ALU, '1', "ADDI R7,R6,FF");

    -- ---------------- comando invalido: nenhuma escrita ----------------
    we0 := n_we; ld0 := n_ld; fw0 := n_fw;
    wait until rising_edge(clk);
    cmd_error <= '1';
    wait until rising_edge(clk);
    cmd_error <= '0';
    wait until rising_edge(clk) and resp_valid = '1' for 1 us;
    check(resp_valid = '1', "ERR: resp_valid nao subiu");
    check(resp_err = '1', "ERR: resp_err deveria ser 1");
    check(resp_show_flags = '0', "ERR: nao deve mostrar flags");
    check(parser_block = '1', "ERR: parser deveria estar bloqueado");
    idle(10);
    format_done <= '1';
    wait until rising_edge(clk);
    format_done <= '0';
    idle(3);
    check(parser_block = '0', "ERR: parser nao foi liberado");
    check(n_we = we0 and n_ld = ld0 and n_fw = fw0, "ERR: houve escrita no banco");
    report "ok   : comando invalido";

    -- ---------------- reset durante a resposta ----------------
    wait until rising_edge(clk);
    opcode_i  <= OP_ADD;
    cmd_valid <= '1';
    wait until rising_edge(clk);
    cmd_valid <= '0';
    wait until rising_edge(clk) and resp_valid = '1' for 1 us;
    rst <= '1';
    idle(2);
    rst <= '0';
    wait until rising_edge(clk);
    check(parser_block = '0' and resp_valid = '0', "reset nao voltou a RECEBE");
    report "ok   : reset durante a resposta";

    check(unstable = 0, "selecoes instaveis ou reg_we/result_ld fora de fase");

    if errors = 0 then
      report "tb_cpu_control: TODOS OS TESTES PASSARAM";
    else
      report "tb_cpu_control: " & integer'image(errors) & " FALHA(S)" severity error;
    end if;
    sim_end <= true;
    wait;
  end process;

end architecture sim;
