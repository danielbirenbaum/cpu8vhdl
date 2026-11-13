-- =============================================================================
-- Recebe bytes da UART, guarda a linha (ate 32 caracteres), detecta o
-- terminador (CR, LF ou CR+LF), decodifica e valida o comando e entrega os
-- campos registrados ao cpu_control.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity command_parser is
  generic (
    G_FULL_ISA : boolean  := true;   -- false: aceita apenas LDI e ADD (marco M1)
    G_MAX_LEN  : positive := 32      -- tamanho maximo da linha
  );
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;    -- reset sincrono, ativo em '1' (rst_s)
    -- da uart_rx
    rx_data      : in  byte_t;
    rx_valid     : in  std_logic;    -- pulso de 1 ciclo
    rx_error     : in  std_logic;    -- erro de quadro: invalida a linha atual
    -- do cpu_control
    parser_block : in  std_logic;
    -- para o cpu_control
    opcode       : out opcode_t;
    rd           : out regidx_t;
    ra           : out regidx_t;
    rb           : out regidx_t;
    imm          : out byte_t;
    cmd_valid    : out std_logic;
    cmd_error    : out std_logic
  );
end entity command_parser;

architecture rtl of command_parser is

  -- Buffer de linha
  type buf_t is array (0 to G_MAX_LEN - 1) of byte_t;
  signal buf      : buf_t := (others => (others => '0'));
  signal len      : integer range 0 to G_MAX_LEN := 0;
  signal line_bad : std_logic := '0';   -- rx_error ou excesso de caracteres

  -- Estados principais
  type state_t is (ST_RX,         -- recebendo caracteres
                   ST_DECODE,     -- varrendo o buffer (1 caractere por ciclo)
                   ST_VALIDATE,   -- conferindo operacao x operandos
                   ST_WAIT_ACK,   -- comando entregue: espera parser_block = 1
                   ST_WAIT_REL);  -- espera parser_block = 0 (LIBERA)
  signal state : state_t := ST_RX;

  -- Fases do decodificador
  type phase_t is (PH_MNEM,    -- lendo as letras da operacao
                   PH_SKIP,    -- pulando espacos antes de um operando
                   PH_TOKEN,   -- lendo Rn ou HH
                   PH_AFTER);  -- depois de um operando: espaco, virgula ou fim
  signal phase : phase_t := PH_MNEM;
  signal ptr   : integer range 0 to G_MAX_LEN := 0;

  -- Resultado da decodificacao
  signal mnem   : std_logic_vector(31 downto 0) := x"20202020";
  signal mlen   : integer range 0 to 4 := 0;
  type opval_t is array (0 to 2) of byte_t;
  signal op_val : opval_t := (others => (others => '0'));
  signal op_imm : std_logic_vector(0 to 2) := "000";  -- '1' = imediato, '0' = registrador
  signal nops   : integer range 0 to 3 := 0;

  -- Campos registrados (saidas)
  signal opcode_r    : opcode_t := OP_LDI;
  signal rd_r        : regidx_t := "000";
  signal ra_r        : regidx_t := "000";
  signal rb_r        : regidx_t := "000";
  signal imm_r       : byte_t   := x"00";
  signal cmd_valid_r : std_logic := '0';
  signal cmd_error_r : std_logic := '0';

begin

  process (clk)
    variable c, c2   : byte_t;
    variable fail    : boolean;
    variable done    : boolean;
    variable ok      : boolean;
    variable is_rrr  : boolean;
    variable is_rr   : boolean;
    variable is_ri   : boolean;
    variable is_rri  : boolean;
    variable v_op    : opcode_t;
    variable v_ra    : regidx_t;
    variable v_rb    : regidx_t;
    variable v_imm   : byte_t;
  begin
    if rising_edge(clk) then
      -- pulsos de 1 ciclo
      cmd_valid_r <= '0';
      cmd_error_r <= '0';

      if rst = '1' then
        state    <= ST_RX;
        phase    <= PH_MNEM;
        len      <= 0;
        ptr      <= 0;
        line_bad <= '0';
        mnem     <= x"20202020";
        mlen     <= 0;
        nops     <= 0;
        op_imm   <= "000";
        opcode_r <= OP_LDI;
        rd_r     <= "000";
        ra_r     <= "000";
        rb_r     <= "000";
        imm_r    <= x"00";

      else
        case state is

          -- -------------------------------------------------------------------
          -- Filtro de entrada + detector de terminador + buffer de linha
          -- -------------------------------------------------------------------
          when ST_RX =>
            if parser_block = '0' then
              if rx_error = '1' then
                line_bad <= '1';                       -- invalida ate o terminador
              elsif rx_valid = '1' then
                if rx_data = ASCII_CR or rx_data = ASCII_LF then
                  if line_bad = '1' then
                    cmd_error_r <= '1';
                    len         <= 0;
                    line_bad    <= '0';
                    state       <= ST_WAIT_ACK;
                  elsif len /= 0 then
                    ptr    <= 0;
                    phase  <= PH_MNEM;
                    mnem   <= x"20202020";
                    mlen   <= 0;
                    nops   <= 0;
                    op_imm <= "000";
                    state  <= ST_DECODE;
                  end if;                              -- linha vazia: ignorada
                elsif len = G_MAX_LEN then
                  line_bad <= '1';                     -- excesso de caracteres
                else
                  buf(len) <= rx_data;
                  len      <= len + 1;
                end if;
              end if;
            end if;

          -- -------------------------------------------------------------------
          -- Decodificador: um caractere por ciclo
          -- -------------------------------------------------------------------
          when ST_DECODE =>
            fail := false;
            done := false;

            if ptr >= len then
              -- fim da linha
              if phase = PH_AFTER then
                done := true;
              else
                fail := true;   -- faltou operando, ou so havia a operacao
              end if;
            else
              c := buf(ptr);
              if ptr + 1 < len then
                c2 := buf(ptr + 1);
              else
                c2 := x"00";
              end if;

              case phase is
                when PH_MNEM =>
                  if is_upper(c) then
                    if mlen = 4 then
                      fail := true;                    -- operacao longa demais
                    else
                      mnem <= mnem(23 downto 0) & c;
                      mlen <= mlen + 1;
                      ptr  <= ptr + 1;
                    end if;
                  elsif c = ASCII_SPACE and mlen /= 0 then
                    phase <= PH_SKIP;
                    ptr   <= ptr + 1;
                  else
                    fail := true;
                  end if;

                when PH_SKIP =>
                  if c = ASCII_SPACE then
                    ptr <= ptr + 1;
                  else
                    phase <= PH_TOKEN;
                  end if;

                when PH_TOKEN =>
                  if nops = 3 then
                    fail := true;                      -- operandos demais
                  elsif c = to_byte('R') and
                        unsigned(c2) >= 16#30# and unsigned(c2) <= 16#37# then
                    op_val(nops) <= "00000" & c2(2 downto 0);   -- R0..R7
                    op_imm(nops) <= '0';
                    nops  <= nops + 1;
                    ptr   <= ptr + 2;
                    phase <= PH_AFTER;
                  elsif is_hex(c) and is_hex(c2) then
                    op_val(nops) <= hex_val(c) & hex_val(c2);   -- 00..FF
                    op_imm(nops) <= '1';
                    nops  <= nops + 1;
                    ptr   <= ptr + 2;
                    phase <= PH_AFTER;
                  else
                    fail := true;
                  end if;

                when PH_AFTER =>
                  if c = ASCII_SPACE then
                    ptr <= ptr + 1;
                  elsif c = ASCII_COMMA then
                    ptr   <= ptr + 1;
                    phase <= PH_SKIP;
                  else
                    fail := true;                      -- ex.: R12, 0FF, R1R2
                  end if;
              end case;
            end if;

            if fail then
              cmd_error_r <= '1';
              len         <= 0;
              line_bad    <= '0';
              state       <= ST_WAIT_ACK;
            elsif done then
              state <= ST_VALIDATE;
            end if;

          -- -------------------------------------------------------------------
          -- Validador: operacao conhecida + formato dos operandos
          -- -------------------------------------------------------------------
          when ST_VALIDATE =>
            is_rrr := (nops = 3) and (op_imm = "000");
            is_rr  := (nops = 2) and (op_imm(0 to 1) = "00");
            is_ri  := (nops = 2) and (op_imm(0 to 1) = "01");
            is_rri := (nops = 3) and (op_imm = "001");

            ok    := true;
            v_op  := OP_LDI;
            v_ra  := "000";
            v_rb  := "000";
            v_imm := x"00";

            if mnem = pack4("LDI") and is_ri then
              v_op  := OP_LDI;
              v_imm := op_val(1);
            elsif mnem = pack4("ADD") and is_rrr then
              v_op := OP_ADD;
              v_ra := op_val(1)(2 downto 0);
              v_rb := op_val(2)(2 downto 0);
            elsif G_FULL_ISA and mnem = pack4("SUB") and is_rrr then
              v_op := OP_SUB;
              v_ra := op_val(1)(2 downto 0);
              v_rb := op_val(2)(2 downto 0);
            elsif G_FULL_ISA and mnem = pack4("AND") and is_rrr then
              v_op := OP_AND;
              v_ra := op_val(1)(2 downto 0);
              v_rb := op_val(2)(2 downto 0);
            elsif G_FULL_ISA and mnem = pack4("OR") and is_rrr then
              v_op := OP_OR;
              v_ra := op_val(1)(2 downto 0);
              v_rb := op_val(2)(2 downto 0);
            elsif G_FULL_ISA and mnem = pack4("XOR") and is_rrr then
              v_op := OP_XOR;
              v_ra := op_val(1)(2 downto 0);
              v_rb := op_val(2)(2 downto 0);
            elsif G_FULL_ISA and mnem = pack4("NOT") and is_rr then
              v_op := OP_NOT;
              v_ra := op_val(1)(2 downto 0);
            elsif G_FULL_ISA and mnem = pack4("MOV") and is_rr then
              v_op := OP_MOV;
              v_ra := op_val(1)(2 downto 0);
            elsif G_FULL_ISA and mnem = pack4("ADDI") and is_rri then
              v_op  := OP_ADDI;
              v_ra  := op_val(1)(2 downto 0);
              v_imm := op_val(2);
            else
              ok := false;
            end if;

            if ok then
              opcode_r    <= v_op;
              rd_r        <= op_val(0)(2 downto 0);
              ra_r        <= v_ra;
              rb_r        <= v_rb;
              imm_r       <= v_imm;
              cmd_valid_r <= '1';
            else
              cmd_error_r <= '1';
            end if;
            len      <= 0;
            line_bad <= '0';
            state    <= ST_WAIT_ACK;

          -- -------------------------------------------------------------------
          -- Bloqueio: um comando por vez
          -- -------------------------------------------------------------------
          when ST_WAIT_ACK =>
            if parser_block = '1' then
              state <= ST_WAIT_REL;
            end if;

          when ST_WAIT_REL =>
            if parser_block = '0' then
              state <= ST_RX;
            end if;

        end case;
      end if;
    end if;
  end process;

  opcode    <= opcode_r;
  rd        <= rd_r;
  ra        <= ra_r;
  rb        <= rb_r;
  imm       <= imm_r;
  cmd_valid <= cmd_valid_r;
  cmd_error <= cmd_error_r;

end architecture rtl;
