library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Testbench de uart_rx (autoverificavel). Usa baud_gen real (50 MHz, 115200 bit/s)
-- para gerar tick_16x e injeta quadros 8N1 ideais em rx_s (ja sincronizado).
-- Cobre: bytes 00, FF, 55, 41, A5, 0D, 0A; LSB primeiro; rx_valid de 1 ciclo;
-- rx_data estavel; quadros sem intervalo; stop invalido (rx_error + recuperacao);
-- falso start (glitch); tolerancia de +-2 % no baud do transmissor; reset no meio
-- de um quadro.
entity tb_uart_rx is
end entity tb_uart_rx;

architecture sim of tb_uart_rx is
    constant T_CLK : time := 20 ns;                 -- 50 MHz
    constant T_BIT : time := 8681 ns;               -- 1 / 115200 s

    type byte_arr is array (natural range <>) of std_logic_vector(7 downto 0);
    constant TEST_BYTES : byte_arr := (x"00", x"FF", x"55", x"41", x"A5", x"0D", x"0A");

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal rx_s     : std_logic := '1';
    signal tick_16x : std_logic;
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;
    signal rx_error : std_logic;
    signal done     : boolean := false;

    -- Escritos somente pelo monitor.
    signal n_valid    : natural := 0;
    signal n_error    : natural := 0;
    signal n_pw_valid : natural := 0;     -- rx_valid com mais de 1 ciclo
    signal n_pw_error : natural := 0;     -- rx_error com mais de 1 ciclo
    signal n_unstable : natural := 0;     -- rx_data mudou fora de rx_valid
    signal last_data  : std_logic_vector(7 downto 0) := (others => '0');
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
        port map (clk => clk, rst => rst, tick_16x => tick_16x, tick_bit => open);

    dut : entity work.uart_rx
        port map (clk => clk, rst => rst, tick_16x => tick_16x, rx_s => rx_s,
                  rx_data => rx_data, rx_valid => rx_valid, rx_error => rx_error);

    monitor : process (clk)
        variable prev_valid : std_logic := '0';
        variable prev_error : std_logic := '0';
    begin
        if rising_edge(clk) then
            if rx_valid = '1' then
                n_valid   <= n_valid + 1;
                last_data <= rx_data;
                if prev_valid = '1' then
                    n_pw_valid <= n_pw_valid + 1;
                end if;
            elsif n_valid > 0 and rx_data /= last_data then
                n_unstable <= n_unstable + 1;
            end if;
            if rx_error = '1' then
                n_error <= n_error + 1;
                if prev_error = '1' then
                    n_pw_error <= n_pw_error + 1;
                end if;
            end if;
            prev_valid := rx_valid;
            prev_error := rx_error;
        end if;
    end process;

    stim : process
        variable errors : natural := 0;
        variable nv, ne : natural;
        variable tb     : time;

        procedure check(cond : boolean; msg : string) is
        begin
            if not cond then
                errors := errors + 1;
                report "FALHA: " & msg severity error;
            end if;
        end procedure;

        -- Quadro 8N1: start, d0..d7 (LSB primeiro), stop (nivel 'stop').
        procedure send_frame(b : std_logic_vector(7 downto 0);
                             stop : std_logic; bit_t : time) is
        begin
            rx_s <= '0';
            wait for bit_t;
            for i in 0 to 7 loop
                rx_s <= b(i);
                wait for bit_t;
            end loop;
            rx_s <= stop;
            wait for bit_t;
        end procedure;

        procedure send_and_check(b : std_logic_vector(7 downto 0); bit_t : time;
                                 msg : string) is
            variable n0 : natural;
        begin
            n0 := n_valid;
            send_frame(b, '1', bit_t);
            rx_s <= '1';
            wait for T_BIT;
            check(n_valid = n0 + 1, msg & ": deve haver exatamente 1 rx_valid (byte "
                  & integer'image(to_integer(unsigned(b))) & ")");
            check(last_data = b, msg & ": byte recebido incorreto (esperado "
                  & integer'image(to_integer(unsigned(b))) & ", obtido "
                  & integer'image(to_integer(unsigned(last_data))) & ")");
        end procedure;
    begin
        -- reset ---------------------------------------------------------------
        rst <= '1';
        wait for 10 * T_CLK;
        wait until rising_edge(clk);
        rst <= '0';
        wait for 5 * T_CLK;
        check(rx_valid = '0' and rx_error = '0', "apos o reset nao deve haver rx_valid/rx_error");

        -- 1) bytes do plano de testes -------------------------------------------
        for k in TEST_BYTES'range loop
            send_and_check(TEST_BYTES(k), T_BIT, "quadro nominal");
        end loop;

        -- 2) quadros sem intervalo entre stop e o proximo start ------------------
        nv := n_valid;
        send_frame(x"3C", '1', T_BIT);
        send_frame(x"C3", '1', T_BIT);
        rx_s <= '1';
        wait for T_BIT;
        check(n_valid = nv + 2, "quadros consecutivos: devem gerar 2 rx_valid");
        check(last_data = x"C3", "quadros consecutivos: ultimo byte incorreto");

        -- 3) stop invalido -> rx_error, sem rx_valid, e recupera depois ----------
        nv := n_valid;
        ne := n_error;
        send_frame(x"5A", '0', T_BIT);
        rx_s <= '1';
        wait for 2 * T_BIT;
        check(n_valid = nv,     "stop invalido: nao pode gerar rx_valid");
        check(n_error = ne + 1, "stop invalido: deve gerar exatamente 1 rx_error");
        send_and_check(x"96", T_BIT, "recuperacao apos erro de quadro");

        -- 4) falso start (glitch de 1/8 de bit) ---------------------------------
        nv := n_valid;
        ne := n_error;
        rx_s <= '0';
        wait for T_BIT / 8;
        rx_s <= '1';
        wait for 3 * T_BIT;
        check(n_valid = nv and n_error = ne, "glitch curto nao deve gerar rx_valid nem rx_error");
        send_and_check(x"7E", T_BIT, "quadro apos falso start");

        -- 5) tolerancia de +-2 % no baud do transmissor ---------------------------
        tb := (T_BIT * 980) / 1000;
        send_and_check(x"A5", tb, "transmissor 2 % mais rapido");
        send_and_check(x"5A", tb, "transmissor 2 % mais rapido");
        tb := (T_BIT * 1020) / 1000;
        send_and_check(x"A5", tb, "transmissor 2 % mais lento");
        send_and_check(x"5A", tb, "transmissor 2 % mais lento");

        -- 6) reset no meio de um quadro -------------------------------------------
        nv := n_valid;
        ne := n_error;
        rx_s <= '0';
        wait for 3 * T_BIT;                         -- start + 2 bits de dado
        wait until rising_edge(clk);
        rst  <= '1';
        rx_s <= '1';
        wait for 4 * T_CLK;
        wait until rising_edge(clk);
        rst <= '0';
        wait for 3 * T_BIT;
        check(n_valid = nv and n_error = ne, "reset no meio do quadro: nao deve sobrar rx_valid/rx_error");
        send_and_check(x"E1", T_BIT, "quadro apos reset no meio de um quadro");

        -- verificacoes globais ----------------------------------------------------
        check(n_pw_valid = 0, "rx_valid deve durar apenas 1 ciclo de clock");
        check(n_pw_error = 0, "rx_error deve durar apenas 1 ciclo de clock");
        check(n_unstable = 0, "rx_data deve ficar estavel entre pulsos de rx_valid");

        if errors = 0 then
            report "tb_uart_rx: TODOS OS TESTES PASSARAM" severity note;
        else
            report "tb_uart_rx: " & integer'image(errors) & " FALHA(S)" severity failure;
        end if;
        done <= true;
        wait;
    end process;
end architecture sim;
