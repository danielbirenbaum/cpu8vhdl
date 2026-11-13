-- =============================================================================
-- cpu_control.vhd
-- Unidade de controle: FSM RECEBE -> EXECUTA/ERRO -> RESPONDE -> LIBERA.
--
-- Autor: Lucas Elbert
--
-- RECEBE   parser livre (parser_block = 0). cmd_valid -> EXECUTA;
--          cmd_error -> ERRO. Os campos do parser sao copiados aqui.
-- EXECUTA  dura G_EXEC_CYCLES ciclos com as selecoes estaveis. No ultimo
--          ciclo, reg_we e result_ld (e flags_we, se a operacao atualiza
--          flags) ficam em '1': escrita no banco e captura da resposta
--          acontecem na mesma borda.
-- ERRO     nenhuma escrita no banco; resp_err = 1.
-- RESPONDE resp_valid = 1 ate format_done.
-- LIBERA   1 ciclo com parser_block = 0, volta a RECEBE.
--
-- Todas as saidas de controle sao funcoes do estado e de registradores
-- (Moore), portanto ficam estaveis durante cada estado.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity cpu_control is
  generic (
    G_EXEC_CYCLES : positive := 2   -- ciclos em EXECUTA (>= 1); 2 da folga
                                    -- para o caminho banco -> ULA -> MUX
  );
  port (
    clk             : in  std_logic;
    rst             : in  std_logic;   -- reset sincrono, ativo em '1' (rst_s)
    -- do command_parser
    cmd_valid       : in  std_logic;
    cmd_error       : in  std_logic;
    opcode_i        : in  opcode_t;
    rd_i            : in  regidx_t;
    ra_i            : in  regidx_t;
    rb_i            : in  regidx_t;
    imm_i           : in  byte_t;
    -- do response_formatter
    format_done     : in  std_logic;
    -- para o command_parser
    parser_block    : out std_logic;
    -- para o response_formatter
    resp_valid      : out std_logic;
    resp_err        : out std_logic;
    resp_show_flags : out std_logic;   -- '1': resposta inclui Z C N V (M2)
    -- para o cpu_datapath
    ra              : out regidx_t;
    rb              : out regidx_t;
    rd              : out regidx_t;
    imm             : out byte_t;
    reg_we          : out std_logic;
    result_ld       : out std_logic;
    flags_we        : out std_logic;
    alu_op          : out aluop_t;
    sel_b           : out std_logic;
    sel_res         : out std_logic_vector(1 downto 0)
  );
end entity cpu_control;

architecture rtl of cpu_control is

  type state_t is (ST_RECEBE, ST_EXECUTA, ST_ERRO, ST_RESPONDE, ST_LIBERA);
  signal state : state_t := ST_RECEBE;

  signal cnt : integer range 0 to G_EXEC_CYCLES - 1 := 0;

  -- campos do comando em execucao
  signal opcode_r : opcode_t := OP_LDI;
  signal rd_r     : regidx_t := "000";
  signal ra_r     : regidx_t := "000";
  signal rb_r     : regidx_t := "000";
  signal imm_r    : byte_t   := x"00";
  signal err_r    : std_logic := '0';

  -- decodificacao (combinacional a partir de opcode_r)
  signal dec_alu_op  : aluop_t;
  signal dec_sel_b   : std_logic;
  signal dec_sel_res : std_logic_vector(1 downto 0);
  signal dec_upd_flg : std_logic;    -- operacao atualiza flags

  signal last_exec : std_logic;

begin

  -- ---------------------------------------------------------------------------
  -- FSM
  -- ---------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state    <= ST_RECEBE;
        cnt      <= 0;
        err_r    <= '0';
        opcode_r <= OP_LDI;
        rd_r     <= "000";
        ra_r     <= "000";
        rb_r     <= "000";
        imm_r    <= x"00";
      else
        case state is
          when ST_RECEBE =>
            if cmd_valid = '1' then
              opcode_r <= opcode_i;
              rd_r     <= rd_i;
              ra_r     <= ra_i;
              rb_r     <= rb_i;
              imm_r    <= imm_i;
              err_r    <= '0';
              cnt      <= 0;
              state    <= ST_EXECUTA;
            elsif cmd_error = '1' then
              err_r <= '1';
              state <= ST_ERRO;
            end if;

          when ST_EXECUTA =>
            if cnt = G_EXEC_CYCLES - 1 then
              state <= ST_RESPONDE;
            else
              cnt <= cnt + 1;
            end if;

          when ST_ERRO =>
            state <= ST_RESPONDE;

          when ST_RESPONDE =>
            if format_done = '1' then
              state <= ST_LIBERA;
            end if;

          when ST_LIBERA =>
            err_r <= '0';
            state <= ST_RECEBE;
        end case;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- Decodificacao do opcode -> selecoes do datapath
  -- ---------------------------------------------------------------------------
  process (opcode_r)
  begin
    -- valores padrao
    dec_alu_op  <= ALU_ADD;
    dec_sel_b   <= SELB_REG;
    dec_sel_res <= SELR_ALU;
    dec_upd_flg <= '0';

    case opcode_r is
      when OP_LDI =>
        dec_sel_res <= SELR_IMM;                       -- Rd <- imm, flags mantidas
      when OP_ADD =>
        dec_alu_op  <= ALU_ADD;
        dec_upd_flg <= '1';
      when OP_SUB =>
        dec_alu_op  <= ALU_SUB;
        dec_upd_flg <= '1';
      when OP_AND =>
        dec_alu_op  <= ALU_AND;
        dec_upd_flg <= '1';
      when OP_OR =>
        dec_alu_op  <= ALU_OR;
        dec_upd_flg <= '1';
      when OP_XOR =>
        dec_alu_op  <= ALU_XOR;
        dec_upd_flg <= '1';
      when OP_NOT =>
        dec_alu_op  <= ALU_NOT;
        dec_upd_flg <= '1';
      when OP_MOV =>
        dec_sel_res <= SELR_A;                         -- Rd <- Ra, flags mantidas
      when OP_ADDI =>
        dec_alu_op  <= ALU_ADD;
        dec_sel_b   <= SELB_IMM;
        dec_upd_flg <= '1';
      when others =>
        dec_sel_res <= SELR_IMM;
    end case;
  end process;

  -- ---------------------------------------------------------------------------
  -- Saidas
  -- ---------------------------------------------------------------------------
  last_exec <= '1' when (state = ST_EXECUTA and cnt = G_EXEC_CYCLES - 1) else '0';

  parser_block <= '0' when (state = ST_RECEBE or state = ST_LIBERA) else '1';

  reg_we    <= last_exec;
  result_ld <= last_exec;
  flags_we  <= last_exec and dec_upd_flg;

  alu_op  <= dec_alu_op;
  sel_b   <= dec_sel_b;
  sel_res <= dec_sel_res;
  ra      <= ra_r;
  rb      <= rb_r;
  rd      <= rd_r;
  imm     <= imm_r;

  resp_valid      <= '1' when state = ST_RESPONDE else '0';
  resp_err        <= err_r;
  resp_show_flags <= dec_upd_flg and not err_r;

end architecture rtl;
