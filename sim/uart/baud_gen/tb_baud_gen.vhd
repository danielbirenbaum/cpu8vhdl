library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

-- Testbench de baud_gen (autoverificavel), clock de 50 MHz (CLK_50MHZ da placa).
-- Verifica (para BAUD = 115200):
--  * saidas em 0 durante o reset;
--  * em 65536 ciclos (2**ACC_W) ha exatamente INC pulsos de tick_16x
--    e INC/16 pulsos de tick_bit (INC = 2416 -> 2416 e 151);
--  * tick_16x dura 1 ciclo e os intervalos sao de 27 ou 28 ciclos;
--  * tick_bit coincide com tick_16x e os intervalos sao de 434 ou 435 ciclos;
--  * erro do baud efetivo menor ou igual a 1 %;
--  * reset em instante arbitrario devolve o gerador a um estado conhecido
--    (mesma latencia ate o 1o tick apos cada reset);
--  * segunda instancia com BAUD = 9600 confirma a parametrizacao.
entity tb_baud_gen is
end entity tb_baud_gen;

architecture sim of tb_baud_gen is
    constant CLK_HZ : positive := 50_000_000;
    constant T_CLK  : time     := 20 ns;
    constant WIN    : natural  := 65536;          -- 2**ACC_W ciclos

    signal clk    : std_logic := '0';
    signal rst    : std_logic := '1';
    signal t16_a, tbit_a : std_logic;             -- 115200 bit/s
    signal t16_b, tbit_b : std_logic;             -- 9600 bit/s
    signal done   : boolean := false;

    function inc_of(baud : positive) return natural is
    begin
        return integer(round(real(baud) * 16.0 * (2.0 ** 16) / real(CLK_HZ)));
    end function;
begin
    clk_gen : process
    begin
        while not done loop
            clk <= '0'; wait for T_CLK / 2;
            clk <= '1'; wait for T_CLK / 2;
        end loop;
        wait;
    end process;

    dut_a : entity work.baud_gen
        generic map (CLK_HZ => CLK_HZ, BAUD => 115_200)
        port map (clk => clk, rst => rst, tick_16x => t16_a, tick_bit => tbit_a);

    dut_b : entity work.baud_gen
        generic map (CLK_HZ => CLK_HZ, BAUD => 9_600)
        port map (clk => clk, rst => rst, tick_16x => t16_b, tick_bit => tbit_b);

    stim : process
        variable errors   : natural := 0;
        variable lat_a    : natural;
        variable lat_b    : natural;
        variable n16a     : natural := 0;
        variable nbita    : natural := 0;
        variable n16b     : natural := 0;
        variable nbitb    : natural := 0;
        variable last16   : integer := 0;
        variable lastbit  : integer := -1;
        variable baud_eff : real;

        procedure check(cond : boolean; msg : string) is
        begin
            if not cond then
                errors := errors + 1;
                report "FALHA: " & msg severity error;
            end if;
        end procedure;

        procedure edges(n : natural) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        -- Conta bordas apos a liberacao do reset ate o 1o tick_16x da instancia A.
        procedure first_tick(variable lat : out natural) is
            variable n : natural := 0;
        begin
            loop
                wait until rising_edge(clk);
                n := n + 1;
                exit when t16_a = '1' or n > 200;
            end loop;
            lat := n;
        end procedure;
    begin
        -- reset inicial -----------------------------------------------------
        rst <= '1';
        edges(5);
        check(t16_a = '0' and tbit_a = '0' and t16_b = '0' and tbit_b = '0',
              "saidas devem ser 0 durante o reset");
        rst <= '0';                                  -- liberacao logo apos a borda

        -- latencia ate o 1o tick (estado conhecido apos reset) --------------
        first_tick(lat_a);
        check(lat_a >= 27 and lat_a <= 31,
              "latencia ate o 1o tick_16x fora do esperado: " & integer'image(lat_a));

        -- janela de 65536 amostras consecutivas, comecando no 1o tick -------
        n16a := 1;
        if t16_b = '1'  then n16b  := 1; end if;
        if tbit_b = '1' then nbitb := 1; end if;
        for i in 1 to WIN - 1 loop
            wait until rising_edge(clk);
            if t16_a = '1' then
                n16a := n16a + 1;
                check(i - last16 >= 27 and i - last16 <= 28,
                      "intervalo entre tick_16x deve ser 27 ou 28 ciclos (obtido "
                      & integer'image(i - last16) & ")");
                last16 := i;
            end if;
            if tbit_a = '1' then
                check(t16_a = '1', "tick_bit deve coincidir com tick_16x");
                nbita := nbita + 1;
                if lastbit >= 0 then
                    check(i - lastbit >= 434 and i - lastbit <= 435,
                          "intervalo entre tick_bit deve ser 434 ou 435 ciclos (obtido "
                          & integer'image(i - lastbit) & ")");
                end if;
                lastbit := i;
            end if;
            if t16_b = '1'  then n16b  := n16b  + 1; end if;
            if tbit_b = '1' then nbitb := nbitb + 1; end if;
        end loop;

        check(n16a = inc_of(115_200),
              "tick_16x em 65536 ciclos: esperado " & integer'image(inc_of(115_200))
              & ", obtido " & integer'image(n16a));
        check(nbita = inc_of(115_200) / 16,
              "tick_bit em 65536 ciclos: esperado " & integer'image(inc_of(115_200) / 16)
              & ", obtido " & integer'image(nbita));

        baud_eff := real(n16a) * real(CLK_HZ) / (16.0 * real(WIN));
        check(abs(baud_eff - 115200.0) / 115200.0 <= 0.01,
              "erro do baud efetivo maior que 1 %");
        report "baud efetivo (115200 nominal): " & integer'image(integer(baud_eff * 10.0))
               & " /10 bit/s" severity note;

        -- segunda instancia: 9600 bit/s -------------------------------------
        check(n16b = inc_of(9_600),
              "BAUD=9600: tick_16x esperado " & integer'image(inc_of(9_600))
              & ", obtido " & integer'image(n16b));
        check(nbitb >= inc_of(9_600) / 16 and nbitb <= inc_of(9_600) / 16 + 1,
              "BAUD=9600: contagem de tick_bit fora do esperado");

        -- reset em instante arbitrario --------------------------------------
        edges(1234);
        rst <= '1';
        edges(3);
        check(t16_a = '0' and tbit_a = '0' and t16_b = '0' and tbit_b = '0',
              "saidas devem voltar a 0 com reset no meio da operacao");
        rst <= '0';
        first_tick(lat_b);
        check(lat_b = lat_a,
              "apos reset a latencia ate o 1o tick deve ser igual a da 1a vez ("
              & integer'image(lat_b) & " x " & integer'image(lat_a) & ")");

        -- resultado ----------------------------------------------------------
        if errors = 0 then
            report "tb_baud_gen: TODOS OS TESTES PASSARAM" severity note;
        else
            report "tb_baud_gen: " & integer'image(errors) & " FALHA(S)" severity failure;
        end if;
        done <= true;
        wait;
    end process;
end architecture sim;
