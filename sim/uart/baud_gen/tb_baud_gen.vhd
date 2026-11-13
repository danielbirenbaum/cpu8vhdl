library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_baud_gen is
end entity tb_baud_gen;

architecture sim of tb_baud_gen is

  constant CLK_HZ     : integer := 50_000_000;
  constant BAUD       : integer := 115_200;
  constant CLK_PERIOD : time    := 20 ns;

  signal clk      : std_logic := '0';
  signal rst_s    : std_logic := '0';
  signal tick_16x : std_logic;
  signal tick_bit : std_logic;

  signal sim_finished : boolean := false;

begin

  -- Instanciação
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

  -- Gerador de Clock (50 MHz)
  p_clk : process
  begin
    while not sim_finished loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
    wait;
  end process p_clk;

  -- Processo de Teste
  p_stimulus : process
    variable count_ticks : integer := 0;
  begin
    -- Reset inicial síncrono
    rst_s <= '1';
    wait for CLK_PERIOD * 5;
    wait until rising_edge(clk);
    rst_s <= '0';

    report "[TB] Reset liberado. Iniciando verificacao..." severity note;

    -- Monitora 32 ticks_16x
    for i in 1 to 32 loop
      wait until rising_edge(clk) and tick_16x = '1';
      count_ticks := count_ticks + 1;

      if (count_ticks mod 16) = 0 then
        assert tick_bit = '1'
          report "[ERRO] tick_bit nao disparou no 16º tick!" severity error;
        report "[TB] [OK] tick_bit disparou no tick_16x #" & integer'image(count_ticks) severity note;
      else
        assert tick_bit = '0'
          report "[ERRO] tick_bit disparou fora de hora!" severity error;
      end if;
    end loop;

    report "[TB] SUCESSO! Todos os testes passaram." severity note;
    sim_finished <= true;
    wait;
  end process p_stimulus;

end architecture sim;