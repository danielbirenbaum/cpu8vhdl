library ieee;
use ieee.std_logic_1164.all;

-- Testbench de uart_tx (autoverificavel). Usa baud_gen real (50 MHz, 115200 bit/s).
-- Um "receptor ideal" no testbench amostra tx_o no centro de cada bit.
-- Cobre: bytes 00, FF, 55, 41, A5; start=0, LSB primeiro, stop=1; tx_busy sobe no
-- ciclo seguinte a tx_valid e cai ao fim do stop bit; duracao do quadro (10 bits)
-- e largura de cada bit (padrao 55); tx_valid ignorado com tx_busy=1; quadros
-- consecutivos; reset no meio da transmissao.
entity tb_uart_tx is
end entity tb_uart_tx;

architecture sim of tb_uart_tx is
    constant T_CLK : time := 20 ns;                 -- 50 MHz
    constant T_BIT : time := 8681 ns;               -- 1 / 115200 s

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal tick_bit : std_logic;
    signal tx_valid : std_logic := '0';
    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_o     : std_logic;
    signal tx_busy  : std_logic;
    signal done     : boolean := false;
begin
    clk_gen : process
    begin
        while not done loop
            clk <= '0'; wait for T_CLK / 2;
            clk <= '1'; wait for T_CLK / 2;
        end loop;
        wait;
    end process;

    u_baud : entity work.baud_gen
        port map (clk => clk, rst => rst, tick_16x => open, tick_bit => tick_bit);

    dut : entity work.uart_tx
        port map (clk => clk, rst => rst, tick_bit => tick_bit,
                  tx_valid => tx_valid, tx_data => tx_data,
                  tx_o => tx_o, tx_busy => tx_busy);

    stim : process
        variable errors : natural := 0;
        variable ts, te : time;
        variable te1    : time;
        variable w      : time;

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

        -- tx_valid com 1 ciclo de clock; confere que tx_busy sobe no ciclo seguinte.
        procedure pulse_valid(b : std_logic_vector(7 downto 0)) is
        begin
            wait until rising_edge(clk);
            tx_data  <= b;
            tx_valid <= '1';
            wait until rising_edge(clk);
            tx_valid <= '0';
            wait for 1 ns;
            check(tx_busy = '1', "tx_busy deve subir no ciclo seguinte a tx_valid");
        end procedure;

        -- Receptor ideal: amostra no centro de cada bit; devolve instante do start
        -- e instante em que tx_busy cai.
        procedure receive_frame(b : std_logic_vector(7 downto 0);
                                inject : boolean;
                                variable t_start : out time;
                                variable t_end   : out time) is
            variable t0 : time;
        begin
            wait until tx_o = '0' for 3 * T_BIT;
            check(tx_o = '0', "start bit nao apareceu em tx_o");
            t0      := now;
            t_start := t0;
            for k in 0 to 9 loop
                wait for t0 + k * T_BIT + T_BIT / 2 - now;
                check(tx_busy = '1', "tx_busy deve ficar em 1 durante o quadro");
                if k = 0 then
                    check(tx_o = '0', "start bit deve ser 0");
                elsif k = 9 then
                    check(tx_o = '1', "stop bit deve ser 1");
                else
                    check(tx_o = b(k - 1),
                          "bit de dado d" & integer'image(k - 1) & " incorreto (LSB primeiro)");
                end if;
                if inject and k = 4 then          -- tx_valid com tx_busy = 1 deve ser ignorado
                    wait until rising_edge(clk);
                    tx_data  <= x"3C";
                    tx_valid <= '1';
                    wait until rising_edge(clk);
                    tx_valid <= '0';
                end if;
            end loop;
            wait until tx_busy = '0' for 2 * T_BIT;
            check(tx_busy = '0', "tx_busy deve cair ao fim do stop bit");
            check(tx_o = '1', "linha deve estar em 1 quando tx_busy cai");
            t_end := now;
            check(t_end - t0 >= 86700 ns and t_end - t0 <= 86900 ns,
                  "duracao do quadro deve ser 10 x 8,68 us (86,8 us +-0,1 %)");
        end procedure;

        -- Para o byte 55 cada transicao e uma fronteira de bit: mede todas as larguras.
        procedure measure_widths is
            variable t_prev : time;
            variable wd     : time;
        begin
            wait until tx_o = '0' for 3 * T_BIT;
            check(tx_o = '0', "start bit nao apareceu em tx_o");
            t_prev := now;
            for k in 1 to 9 loop
                wait on tx_o;
                wd     := now - t_prev;
                t_prev := now;
                check(wd >= 8660 ns and wd <= 8700 ns,
                      "largura do bit " & integer'image(k) & " fora de 8,68 us +-20 ns");
            end loop;
            wait until tx_busy = '0' for 2 * T_BIT;
            wd := now - t_prev;
            check(wd >= 8660 ns and wd <= 8700 ns, "largura do stop bit fora de 8,68 us +-20 ns");
        end procedure;
    begin
        -- reset ---------------------------------------------------------------
        rst <= '1';
        edges(5);
        rst <= '0';
        edges(5);
        check(tx_o = '1',    "linha deve ficar em 1 no repouso");
        check(tx_busy = '0', "tx_busy deve ser 0 no repouso");

        -- 1) bytes do plano de testes -------------------------------------------
        for n in 0 to 4 loop
            case n is
                when 0      => pulse_valid(x"00"); receive_frame(x"00", false, ts, te);
                when 1      => pulse_valid(x"FF"); receive_frame(x"FF", false, ts, te);
                when 2      => pulse_valid(x"55"); receive_frame(x"55", false, ts, te);
                when 3      => pulse_valid(x"41"); receive_frame(x"41", false, ts, te);
                when others => pulse_valid(x"A5"); receive_frame(x"A5", false, ts, te);
            end case;
            edges(5);
            check(tx_o = '1' and tx_busy = '0', "apos o quadro: linha em 1 e tx_busy = 0");
        end loop;

        -- 2) largura de cada bit (padrao 55) ----------------------------------------
        pulse_valid(x"55");
        measure_widths;
        edges(5);

        -- 3) tx_valid durante tx_busy = 1 e ignorado -------------------------------------
        pulse_valid(x"C3");
        receive_frame(x"C3", true, ts, te);
        wait for 3 * T_BIT;
        check(tx_o = '1' and tx_busy = '0', "tx_valid com tx_busy = 1 nao pode gerar novo quadro");

        -- 4) quadros consecutivos ----------------------------------------------------------
        pulse_valid(x"11");
        receive_frame(x"11", false, ts, te1);
        pulse_valid(x"22");
        receive_frame(x"22", false, ts, te);
        w := ts - te1;
        check(w >= 0 ns and w <= T_BIT + 100 ns,
              "intervalo entre quadros consecutivos deve ser no maximo ~1 bit");
        edges(5);

        -- 5) reset no meio da transmissao ------------------------------------------------------
        pulse_valid(x"F0");
        wait for 4 * T_BIT;
        wait until rising_edge(clk);
        rst <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        check(tx_o = '1' and tx_busy = '0', "reset deve devolver linha a 1 e tx_busy a 0");
        edges(3);
        rst <= '0';
        edges(3);
        pulse_valid(x"0F");
        receive_frame(x"0F", false, ts, te);

        -- resultado -----------------------------------------------------------------------------
        if errors = 0 then
            report "tb_uart_tx: TODOS OS TESTES PASSARAM" severity note;
        else
            report "tb_uart_tx: " & integer'image(errors) & " FALHA(S)" severity failure;
        end if;
        done <= true;
        wait;
    end process;
end architecture sim;
