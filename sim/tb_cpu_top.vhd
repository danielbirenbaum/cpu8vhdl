library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity tb_cpu_top is
end entity tb_cpu_top;

architecture sim of tb_cpu_top is

    constant C_CLK_HZ     : positive := 50_000_000;
    constant C_BAUD       : positive := 115_200;
    constant C_CLK_PERIOD : time     := 1 sec / C_CLK_HZ; -- 20 ns
    constant C_BIT_PERIOD : time     := 1 sec / C_BAUD;   -- ~8.68 us

    signal clk      : std_logic := '0';
    signal rst_i    : std_logic := '1';
    signal rx_i     : std_logic := '1'; -- Linha UART idle em '1'
    signal tx_o     : std_logic;
    signal sim_done : boolean   := false;

    -- Envia 1 byte no formato UART 8N1 (1 start, 8 bits LSB-first, 1 stop)
    procedure uart_send_byte (
        constant data_in : in  std_logic_vector(7 downto 0);
        signal   tx_line : out std_logic
    ) is
    begin
        tx_line <= '0'; -- Start bit
        wait for C_BIT_PERIOD;

        for i in 0 to 7 loop
            tx_line <= data_in(i);
            wait for C_BIT_PERIOD;
        end loop;

        tx_line <= '1'; -- Stop bit
        wait for C_BIT_PERIOD;
    end procedure uart_send_byte;

    -- Envia uma linha ASCII terminada por CR+LF
    procedure uart_send_line (
        constant cmd_str : in  string;
        signal   tx_line : out std_logic
    ) is
        variable char_byte : std_logic_vector(7 downto 0);
    begin
        for idx in cmd_str'range loop
            char_byte := std_logic_vector(to_unsigned(character'pos(cmd_str(idx)), 8));
            uart_send_byte(char_byte, tx_line);
        end loop;
        uart_send_byte(x"0D", tx_line); -- CR
        uart_send_byte(x"0A", tx_line); -- LF
    end procedure uart_send_line;

    -- Recebe 1 byte transmitido em tx_o
    procedure uart_receive_byte (
        signal   rx_line   : in  std_logic;
        variable data_out  : out std_logic_vector(7 downto 0);
        variable timed_out : out boolean;
        constant timeout   : in  time := 2 ms
    ) is
    begin
        timed_out := false;
        data_out  := (others => '0');

        if rx_line /= '0' then
            wait until rx_line = '0' for timeout;
        end if;

        if rx_line /= '0' then
            timed_out := true;
            return;
        end if;

        -- Meio do start bit
        wait for C_BIT_PERIOD / 2;
        assert rx_line = '0'
            report "Falha UART TX: start bit invalido."
            severity error;

        -- Amostra os 8 bits de dados
        for i in 0 to 7 loop
            wait for C_BIT_PERIOD;
            data_out(i) := rx_line;
        end loop;

        -- Stop bit
        wait for C_BIT_PERIOD;
        assert rx_line = '1'
            report "Falha UART TX: stop bit ausente."
            severity error;
    end procedure uart_receive_byte;

    -- Le uma linha completa terminada por LF (0x0A) e verifica o conteudo ASCII
    procedure uart_check_response (
        signal   rx_line  : in std_logic;
        constant expected : in string
    ) is
        constant C_MAX_RESP : positive := 64;
        variable rx_buf     : string(1 to C_MAX_RESP) := (others => ' ');
        variable rx_len     : natural := 0;
        variable rx_byte    : std_logic_vector(7 downto 0);
        variable timed_out  : boolean;
    begin
        loop
            uart_receive_byte(rx_line, rx_byte, timed_out, 2 ms);
            assert not timed_out
                report "Timeout aguardando resposta UART. Esperado: """ & expected & """"
                severity failure;

            -- Ignora CR (0x0D) e encerra ao receber LF (0x0A)
            if rx_byte = x"0A" then
                exit;
            elsif rx_byte /= x"0D" then
                if rx_len < C_MAX_RESP then
                    rx_len := rx_len + 1;
                    rx_buf(rx_len) := character'val(to_integer(unsigned(rx_byte)));
                end if;
            end if;
        end loop;

        report "Resposta recebida: """ & rx_buf(1 to rx_len) & """" severity note;

        assert rx_buf(1 to rx_len) = expected
            report "Divergencia na resposta! Esperado: """ & expected &
                   """, Recebido: """ & rx_buf(1 to rx_len) & """"
            severity error;
    end procedure uart_check_response;

begin

    dut : entity work.cpu_top
        generic map (
            CLK_HZ        => C_CLK_HZ,
            BAUD          => C_BAUD,
            ACC_W         => 16,
            G_FULL_ISA    => true,
            G_MAX_LEN     => 32,
            G_EXEC_CYCLES => 2,
            G_FLAGS_EN    => true
        )
        port map (
            clk   => clk,
            rst_i => rst_i,
            rx_i  => rx_i,
            tx_o  => tx_o
        );

    -- Geracao do clock de 50 MHz
    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for C_CLK_PERIOD / 2;
            clk <= '1';
            wait for C_CLK_PERIOD / 2;
        end loop;
        wait;
    end process clk_gen;

    -- Sequencia de testes funcionais ponta a ponta
    stim_proc : process
    begin
        rst_i <= '1';
        rx_i  <= '1';
        wait for 20 * C_CLK_PERIOD;
        rst_i <= '0';
        wait for 20 * C_CLK_PERIOD;

        report "=== Iniciando testes de integracao da cpu_top ===" severity note;

        -- 1. LDI R0, 0F (15 decimal; LDI nao exibe flags)
        uart_send_line("LDI R0, 0F", rx_i);
        uart_check_response(tx_o, "R0 = 0F");

        -- 2. LDI R1, 1B (27 decimal)
        uart_send_line("LDI R1, 1B", rx_i);
        uart_check_response(tx_o, "R1 = 1B");

        -- 3. ADD R2, R0, R1 (0x0F + 0x1B = 0x2A; Z=0 C=0 N=0 V=0)
        uart_send_line("ADD R2, R0, R1", rx_i);
        uart_check_response(tx_o, "R2 = 2A Z=0 C=0 N=0 V=0");

        -- 4. SUB R3, R0, R1 (0x0F - 0x1B = 0xF4; borrow => C=0, negativo => N=1)
        uart_send_line("SUB R3, R0, R1", rx_i);
        uart_check_response(tx_o, "R3 = F4 Z=0 C=0 N=1 V=0");

        -- 5. SUB R4, R1, R1 (0x1B - 0x1B = 0x00; Z=1, sem borrow => C=1)
        uart_send_line("SUB R4, R1, R1", rx_i);
        uart_check_response(tx_o, "R4 = 00 Z=1 C=1 N=0 V=0");

        -- 6. MOV R5, R2 (copia 0x2A para R5; MOV nao exibe flags)
        uart_send_line("MOV R5, R2", rx_i);
        uart_check_response(tx_o, "R5 = 2A");

        -- 7. ADDI R6, R5, 06 (0x2A + 0x06 = 0x30; Z=0 C=0 N=0 V=0)
        uart_send_line("ADDI R6, R5, 06", rx_i);
        uart_check_response(tx_o, "R6 = 30 Z=0 C=0 N=0 V=0");

        -- 8. Comando invalido -> deve retornar ERR
        uart_send_line("INVALIDO R0, 01", rx_i);
        uart_check_response(tx_o, "ERR");

        report "=== Todos os testes da cpu_top foram concluidos ===" severity note;
        sim_done <= true;
        wait;
    end process stim_proc;

end architecture sim;