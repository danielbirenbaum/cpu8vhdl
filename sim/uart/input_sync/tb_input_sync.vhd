library ieee;
use ieee.std_logic_1164.all;

-- Testbench de input_sync (autoverificavel).
-- Verifica:
--  1) power-up: a FPGA nasce em reset (rst_s = 1) e libera apos 2 bordas;
--  2) RX: latencia de exatamente 2 bordas e filtragem de pulsos entre bordas;
--  3) reset: assert assincrono, liberacao sincrona (2 bordas) em fases diferentes;
--  4) RX mantido em repouso (1) enquanto rst_s = 1;
--  5) pulso de reset mais curto que o clock e alongado ate 2 bordas.
entity tb_input_sync is
end entity tb_input_sync;

architecture sim of tb_input_sync is
    constant T_CLK : time := 20 ns;                 -- 50 MHz

    signal clk   : std_logic := '0';
    signal rst_i : std_logic := '0';
    signal rx_i  : std_logic := '1';
    signal rx_s  : std_logic;
    signal rst_s : std_logic;
    signal done  : boolean := false;
begin
    clk_gen : process
    begin
        while not done loop
            clk <= '0'; wait for T_CLK / 2;
            clk <= '1'; wait for T_CLK / 2;
        end loop;
        wait;
    end process;

    dut : entity work.input_sync
        port map (clk => clk, rst_i => rst_i, rx_i => rx_i, rx_s => rx_s, rst_s => rst_s);

    stim : process
        variable errors : natural := 0;
        variable ph     : integer;

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

        -- Muda rx_i 3 ns apos uma borda e confere a latencia de 2 bordas.
        procedure drive_rx_and_check(level : std_logic) is
        begin
            wait until rising_edge(clk);
            wait for 3 ns;
            rx_i <= level;
            wait until rising_edge(clk);
            wait for 1 ns;
            check(rx_s /= level, "rx_s nao deve refletir rx_i apos apenas 1 borda");
            wait until rising_edge(clk);
            wait for 1 ns;
            check(rx_s = level, "rx_s deve refletir rx_i apos 2 bordas");
        end procedure;
    begin
        -- 1) power-up ------------------------------------------------------
        wait for 1 ns;
        check(rst_s = '1', "power-up: rst_s deve iniciar em 1");
        check(rx_s  = '1', "power-up: rx_s deve iniciar em 1 (linha em repouso)");
        edges(1); wait for 1 ns;
        check(rst_s = '1', "power-up: rst_s ainda deve ser 1 apos a 1a borda");
        edges(1); wait for 1 ns;
        check(rst_s = '0', "power-up: rst_s deve cair apos a 2a borda");

        -- 2) RX: latencia de 2 bordas -------------------------------------
        drive_rx_and_check('0');
        drive_rx_and_check('1');
        drive_rx_and_check('0');

        -- pulso de rx_i inteiramente entre duas bordas nao pode aparecer em rx_s
        drive_rx_and_check('1');
        wait until rising_edge(clk);
        wait for 5 ns;
        rx_i <= '0';
        wait for 5 ns;
        rx_i <= '1';
        for i in 1 to 4 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            check(rx_s = '1', "pulso curto entre bordas nao deve passar pelo sincronizador");
        end loop;

        drive_rx_and_check('0');          -- deixa rx_i = 0 (rx_s = 0) para o teste de reset

        -- 3) reset assincrono com RX em nivel 0 ----------------------------
        wait until rising_edge(clk);
        wait for 5 ns;
        rst_i <= '1';
        wait for 1 ns;
        check(rst_s = '1', "assert assincrono: rst_s deve subir sem esperar o clock");
        check(rx_s  = '0', "rx_s so e forcado a 1 na proxima borda (reset do RX e sincrono)");
        wait until rising_edge(clk);
        wait for 1 ns;
        check(rx_s = '1', "RX deve ficar em repouso (1) durante o reset");
        edges(3);
        wait for 1 ns;
        check(rst_s = '1', "rst_s deve permanecer em 1 enquanto rst_i = 1");
        check(rx_s  = '1', "rx_s deve permanecer em 1 enquanto rst_s = 1");

        -- 4) liberacao em fase arbitraria ----------------------------------
        wait until rising_edge(clk);
        wait for 7 ns;
        rst_i <= '0';
        wait for 1 ns;
        check(rst_s = '1', "liberacao: rst_s nao pode cair fora de uma borda do clock");
        wait until rising_edge(clk);
        wait for 1 ns;
        check(rst_s = '1', "liberacao: rst_s ainda deve ser 1 apos a 1a borda");
        wait until rising_edge(clk);
        wait for 1 ns;
        check(rst_s = '0', "liberacao: rst_s deve cair na 2a borda");
        check(rx_s  = '1', "RX ainda em repouso logo apos liberar o reset");
        wait until rising_edge(clk);
        wait for 1 ns;
        check(rx_s = '1', "RX: primeira amostra apos reset ainda mostra repouso");
        wait until rising_edge(clk);
        wait for 1 ns;
        check(rx_s = '0', "RX volta a seguir a linha (0) apos o reset");

        -- 5) pulso de reset mais curto que o clock --------------------------
        wait until rising_edge(clk);
        wait for 5 ns;
        rst_i <= '1';
        wait for 3 ns;
        rst_i <= '0';
        check(rst_s = '1', "pulso curto de reset deve ser capturado (assert assincrono)");
        wait until rising_edge(clk);
        wait for 1 ns;
        check(rst_s = '1', "pulso curto: rst_s deve durar ao menos ate a 1a borda");
        wait until rising_edge(clk);
        wait for 1 ns;
        check(rst_s = '0', "pulso curto: rst_s deve liberar na 2a borda");

        rx_i <= '1';
        edges(6);

        -- 6) reset em varias fases do clock --------------------------------
        for k in 0 to 4 loop
            ph := 1 + 4 * k;                       -- 1, 5, 9, 13, 17 ns apos a borda
            wait until rising_edge(clk);
            wait for ph * 1 ns;
            rst_i <= '1';
            wait for 1 ns;
            check(rst_s = '1', "assert assincrono na fase " & integer'image(ph) & " ns");
            edges(2);
            wait until rising_edge(clk);
            wait for ph * 1 ns;
            rst_i <= '0';
            wait until rising_edge(clk);
            wait for 1 ns;
            check(rst_s = '1', "liberacao na fase " & integer'image(ph) & " ns: 1a borda");
            wait until rising_edge(clk);
            wait for 1 ns;
            check(rst_s = '0', "liberacao na fase " & integer'image(ph) & " ns: 2a borda");
            edges(2);
        end loop;

        -- resultado --------------------------------------------------------
        if errors = 0 then
            report "tb_input_sync: TODOS OS TESTES PASSARAM" severity note;
        else
            report "tb_input_sync: " & integer'image(errors) & " FALHA(S)" severity failure;
        end if;
        done <= true;
        wait;
    end process;
end architecture sim;
