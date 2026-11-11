----------------------------------------------------------------------
-- Módulo: tb_baud_gen.vhd
-- Descrição: Testbench auto-verificável para o gerador de Baud Rate
----------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_baud_gen is
end entity tb_baud_gen;

architecture sim of tb_baud_gen is

  -- Parâmetros de simulação (Clock do sistema de 50 MHz e Baud Rate de 115200)
  constant CLK_HZ : integer := 50_000_000;
  constant BAUD   : integer := 115_200;

  -- Período do clock: T = 1 / 50MHz = 20 ns
  constant CLK_PERIOD : time := 20 ns;

  -- Sinais de interface com a UUT (Unit Under Test)
  signal clk      : std_logic := '0';
  signal rst_s    : std_logic := '0';
  signal tick_16x : std_logic;
  signal tick_bit : std_logic;

  -- Flag para encerrar o gerador de clock ao fim da simulação
  signal sim_finished : boolean := false;

begin

  -- Instanciação da UUT (Unit Under Test)
  uut : entity work.baud_gen
    generic map (
      CLK_HZ => CLK_HZ,
      BAUD   => BAUD
    )
    port map (
      clk      => clk,
      rst_s    => rst_s,
      tick_16x => tick_16x,
      tick_bit => tick_bit
    );

  -- 1. Gerador de Clock Principal (50 MHz)
  p_clk_gen : process
  begin
    while not sim_finished loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
    wait;
  end process p_clk_gen;

  -- 2. Processo de Estímulo e Verificação Automática
  p_stimulus : process
    variable count_ticks : integer := 0;
  begin
    -- Reset inicial do sistema (ativo por 5 ciclos de clock)
    rst_s <= '1';
    wait for CLK_PERIOD * 5;
    rst_s <= '0';
    wait until rising_edge(clk);

    report "[TB] Reset liberado. A iniciar verificação do Baud Generator..." severity note;

    -- Monitoriza e valida 32 ticks_16x (o equivalente a 2 bits completos)
    for i in 1 to 32 loop
      -- Aguarda o próximo pulso de tick_16x
      wait until rising_edge(clk) and tick_16x = '1';
      count_ticks := count_ticks + 1;

      -- Verificação de alinhamento do tick_bit
      if (count_ticks mod 16) = 0 then
        -- No 16º e 32º tick_16x, tick_bit DEVE estar em '1'
        assert tick_bit = '1'
          report "[ERRO] tick_bit deveria ter disparado no 16º tick_16x!"
          severity error;

        report "[TB] [SUCESSO] tick_bit disparado corretamente no tick_16x #" & integer'image(count_ticks) severity note;
      else
        -- Em qualquer outro tick_16x, tick_bit DEVE estar em '0'
        assert tick_bit = '0'
          report "[ERRO] tick_bit disparou prematuramente fora do tempo de bit!"
          severity error;
      end if;
    end loop;

    report "[TB] Simulação concluída com sucesso! Todos os testes passaram." severity note;
    sim_finished <= true;
    wait;
  end process p_stimulus;

end architecture sim;