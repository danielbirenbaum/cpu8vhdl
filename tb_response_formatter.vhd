-- =============================================================================
-- tb_response_formatter.vhd
-- Resposta ASCII exata e ordem dos bytes; ERR; resposta com flags (M2);
-- tx_valid so com tx_busy = 0; format_done somente apos o ultimo byte;
-- nenhuma resposta duplicada.
-- Usa um modelo simples de uart_tx (busy por BUSY_CYC ciclos por byte).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity tb_response_formatter is
end entity;

architecture sim of tb_response_formatter is

  constant T_CLK    : time    := 20 ns;
  constant BUSY_CYC : integer := 12;      -- duracao de um "quadro" no modelo

  constant CR : character := character'val(13);
  constant LF : character := character'val(10);

  signal clk             : std_logic := '0';
  signal rst             : std_logic := '1';
  signal resp_valid      : std_logic := '0';
  signal resp_err        : std_logic := '0';
  signal resp_show_flags : std_logic := '0';
  signal resp_idx        : regidx_t := "000";
  signal resp_data       : byte_t := x"00";
  signal resp_flags      : std_logic_vector(3 downto 0) := "0000";
  signal tx_busy         : std_logic := '0';
  signal tx_data         : byte_t;
  signal tx_valid        : std_logic;
  signal format_done     : std_logic;

  -- captura do modelo de uart_tx
  signal cap_str   : string(1 to 64) := (others => ' ');
  signal cap_len   : integer := 0;
  signal cap_clear : std_logic := '0';
  signal viol      : integer := 0;       -- tx_valid com tx_busy = 1
  signal sim_end   : boolean := false;

begin

  clk <= not clk after T_CLK / 2 when not sim_end else '0';

  dut : entity work.response_formatter
    generic map (G_FLAGS_EN => true)
    port map (
      clk => clk, rst => rst,
      resp_valid => resp_valid, resp_err => resp_err,
      resp_show_flags => resp_show_flags,
      resp_idx => resp_idx, resp_data => resp_data, resp_flags => resp_flags,
      tx_busy => tx_busy, tx_data => tx_data, tx_valid => tx_valid,
      format_done => format_done);

  -- Modelo de uart_tx: aceita o byte com tx_valid, fica ocupado BUSY_CYC ciclos
  uart_model : process (clk)
    variable cnt : integer := 0;
  begin
    if rising_edge(clk) then
      if cap_clear = '1' then
        cap_len <= 0;
      end if;
      if tx_valid = '1' then
        if tx_busy = '1' then
          viol <= viol + 1;
        else
          if cap_clear = '0' and cap_len < 64 then
            cap_str(cap_len + 1) <= character'val(to_integer(unsigned(tx_data)));
            cap_len <= cap_len + 1;
          end if;
          tx_busy <= '1';
          cnt := BUSY_CYC;
        end if;
      elsif cnt > 0 then
        cnt := cnt - 1;
        if cnt = 0 then
          tx_busy <= '0';
        end if;
      end if;
    end if;
  end process;

  stim : process
    variable errors : integer := 0;

    procedure idle(n : integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    -- Emula o cpu_control: resp_valid ate format_done; confere o texto enviado.
    procedure run(err : std_logic; show : std_logic; idx : integer;
                  data : byte_t; flg : std_logic_vector(3 downto 0);
                  expected : string) is
      variable ok : boolean;
    begin
      cap_clear <= '1';
      wait until rising_edge(clk);
      cap_clear <= '0';

      resp_err        <= err;
      resp_show_flags <= show;
      resp_idx        <= std_logic_vector(to_unsigned(idx, 3));
      resp_data       <= data;
      resp_flags      <= flg;
      resp_valid      <= '1';

      wait until rising_edge(clk) and format_done = '1' for 100 us;
      if format_done /= '1' then
        report "FALHA: format_done nao chegou (" & expected & ")" severity error;
        errors := errors + 1;
      end if;
      -- format_done so depois do ultimo byte terminado
      if tx_busy /= '0' or cap_len /= expected'length then
        report "FALHA: format_done antes do fim da transmissao" severity error;
        errors := errors + 1;
      end if;
      resp_valid <= '0';            -- UC vai para LIBERA

      idle(3 * BUSY_CYC);           -- nada mais pode ser enviado

      ok := (cap_len = expected'length);
      if ok then
        for i in 1 to expected'length loop
          if cap_str(i) /= expected(expected'low + i - 1) then
            ok := false;
          end if;
        end loop;
      end if;
      if not ok then
        report "FALHA: recebido """ & cap_str(1 to cap_len) &
               """, esperado """ & expected & """" severity error;
        errors := errors + 1;
      else
        report "ok   : " & integer'image(expected'length) & " bytes";
      end if;
    end procedure;

  begin
    rst <= '1';
    idle(5);
    rst <= '0';
    idle(5);

    -- M1: R3 = 08
    run('0', '0', 3, x"08", "0000", "R3 = 08" & CR & LF);
    -- ERR
    run('1', '0', 0, x"00", "0000", "ERR" & CR & LF);
    -- M2 com flags: R3 = 08 Z=0 C=0 N=0 V=0
    run('0', '1', 3, x"08", "0000", "R3 = 08 Z=0 C=0 N=0 V=0" & CR & LF);
    -- 255 + 1: R0 = 00 Z=1 C=1 N=0 V=0   (flags = Z C N V)
    run('0', '1', 0, x"00", "1100", "R0 = 00 Z=1 C=1 N=0 V=0" & CR & LF);
    -- 127 + 1: R7 = 80 Z=0 C=0 N=1 V=1
    run('0', '1', 7, x"80", "0011", "R7 = 80 Z=0 C=0 N=1 V=1" & CR & LF);
    -- hexadecimal com letras
    run('0', '0', 5, x"AF", "0000", "R5 = AF" & CR & LF);
    -- ERR ignora show_flags
    run('1', '1', 2, x"55", "1111", "ERR" & CR & LF);

    if viol /= 0 then
      report "FALHA: tx_valid com tx_busy = 1 (" & integer'image(viol) & "x)"
        severity error;
      errors := errors + 1;
    end if;

    if errors = 0 then
      report "tb_response_formatter: TODOS OS TESTES PASSARAM";
    else
      report "tb_response_formatter: " & integer'image(errors) & " FALHA(S)"
        severity error;
    end if;
    sim_end <= true;
    wait;
  end process;

end architecture sim;
