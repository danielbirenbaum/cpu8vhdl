-- =============================================================================
-- cpu_datapath.vhd
-- Integra banco de registradores, ULA, MUX B, MUX Resultado, registrador de
-- flags e captura estavel da resposta.
--
--   MUX B         : sel_b   = '0' -> Rb (2a leitura) | '1' -> imm
--   MUX Resultado : sel_res = "00" alu_result | "01" Ra | "10" Rb | "11" imm
--   wr_data (saida do MUX Resultado) alimenta o banco e a captura.
--
-- Na mesma borda (fim de EXECUTA):
--   reg_we    = 1 -> banco(rd) <= wr_data
--   result_ld = 1 -> resp_data <= wr_data ; resp_idx <= rd
--   flags_we  = 1 -> flags <= Z C N V da ULA (LDI e MOV mantem as anteriores)
-- Como a captura usa wr_data (e nao uma nova leitura do banco), a resposta
-- fica correta mesmo quando o destino coincide com uma fonte (ADD R1,R1,R2).
--
-- resp_flags(3 downto 0) = Z, C, N, V (ver FLAG_* em cpu_pkg.vhd).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity cpu_datapath is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;     -- sincrono, ativo em '1' (rst_s)
    -- do cpu_control
    ra         : in  regidx_t;
    rb         : in  regidx_t;
    rd         : in  regidx_t;
    imm        : in  byte_t;
    reg_we     : in  std_logic;
    result_ld  : in  std_logic;
    flags_we   : in  std_logic;
    alu_op     : in  aluop_t;
    sel_b      : in  std_logic;
    sel_res    : in  std_logic_vector(1 downto 0);
    -- para o response_formatter
    resp_data  : out byte_t;
    resp_idx   : out regidx_t;
    resp_flags : out std_logic_vector(3 downto 0)   -- Z C N V
  );
end entity cpu_datapath;

architecture rtl of cpu_datapath is

  signal rd_a, rd_b   : byte_t;
  signal op_b         : byte_t;
  signal alu_result   : byte_t;
  signal alu_z, alu_c : std_logic;
  signal alu_n, alu_v : std_logic;
  signal wr_data      : byte_t;

  signal flags_r : std_logic_vector(3 downto 0) := "0000";
  signal data_r  : byte_t   := x"00";
  signal idx_r   : regidx_t := "000";

begin

  -- ---------------------------------------------------------------------------
  -- Banco de registradores
  -- ---------------------------------------------------------------------------
  u_regs : entity work.reg_file
    port map (
      clk       => clk,
      rst       => rst,
      we        => reg_we,
      wr_addr   => rd,
      wr_data   => wr_data,
      rd_addr_a => ra,
      rd_addr_b => rb,
      rd_data_a => rd_a,
      rd_data_b => rd_b);

  -- ---------------------------------------------------------------------------
  -- MUX B
  -- ---------------------------------------------------------------------------
  op_b <= imm when sel_b = SELB_IMM else rd_b;

  -- ---------------------------------------------------------------------------
  -- ULA (op de 3 bits: usa alu_op(2 downto 0); o bit 3 e sempre 0.
  --      Se a porta op da ULA passar a ter 4 bits, ligar op => alu_op.)
  -- ---------------------------------------------------------------------------
  u_alu : entity work.alu
    port map (
      a         => rd_a,
      b         => op_b,
      op        => alu_op(2 downto 0),
      resultado => alu_result,
      z         => alu_z,
      c         => alu_c,
      n         => alu_n,
      v         => alu_v);

  -- ---------------------------------------------------------------------------
  -- MUX Resultado -> wr_data
  -- ---------------------------------------------------------------------------
  with sel_res select
    wr_data <= alu_result when "00",    -- SELR_ALU
               rd_a       when "01",    -- SELR_A
               rd_b       when "10",    -- SELR_B
               imm        when others;  -- SELR_IMM

  -- ---------------------------------------------------------------------------
  -- Registrador de flags e captura da resposta
  -- ---------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        flags_r <= "0000";
        data_r  <= x"00";
        idx_r   <= "000";
      else
        if flags_we = '1' then
          flags_r(FLAG_Z) <= alu_z;
          flags_r(FLAG_C) <= alu_c;
          flags_r(FLAG_N) <= alu_n;
          flags_r(FLAG_V) <= alu_v;
        end if;
        if result_ld = '1' then
          data_r <= wr_data;
          idx_r  <= rd;
        end if;
      end if;
    end if;
  end process;

  resp_data  <= data_r;
  resp_idx   <= idx_r;
  resp_flags <= flags_r;

end architecture rtl;
