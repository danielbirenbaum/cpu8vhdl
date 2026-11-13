library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity cpu_top is
    generic (
        CLK_HZ        : positive := 50_000_000; -- Oscilador principal (50 MHz)
        BAUD          : positive := 115_200;    -- Taxa de comunicacao UART
        ACC_W         : positive := 16;         -- Largura do acumulador NCO do baud_gen
        G_FULL_ISA    : boolean  := true;       -- true: ISA completa; false: apenas LDI e ADD
        G_MAX_LEN     : positive := 32;         -- Tamanho maximo da linha de comando
        G_EXEC_CYCLES : positive := 2;          -- Ciclos no estado EXECUTA do cpu_control
        G_FLAGS_EN    : boolean  := true        -- true: inclui Z C N V nas respostas da ULA
    );
    port (
        clk   : in  std_logic;
        rst_i : in  std_logic;
        rx_i  : in  std_logic;
        tx_o  : out std_logic
    );
end entity cpu_top;

architecture rtl of cpu_top is

    -- Sinais sincronizados (input_sync -> todos os blocos)
    signal rst_s : std_logic;
    signal rx_s  : std_logic;

    -- Habilitacoes de baud rate (baud_gen -> uart_rx / uart_tx)
    signal tick_16x : std_logic;
    signal tick_bit : std_logic;

    -- Interface uart_rx -> command_parser
    signal rx_data  : byte_t;
    signal rx_valid : std_logic;
    signal rx_error : std_logic;

    -- Interface command_parser <-> cpu_control
    signal parser_block : std_logic;
    signal cmd_opcode   : opcode_t;
    signal cmd_rd       : regidx_t;
    signal cmd_ra       : regidx_t;
    signal cmd_rb       : regidx_t;
    signal cmd_imm      : byte_t;
    signal cmd_valid    : std_logic;
    signal cmd_error    : std_logic;

    -- Interface cpu_control -> cpu_datapath
    signal dp_ra     : regidx_t;
    signal dp_rb     : regidx_t;
    signal dp_rd     : regidx_t;
    signal dp_imm    : byte_t;
    signal reg_we    : std_logic;
    signal result_ld : std_logic;
    signal flags_we  : std_logic;
    signal alu_op    : aluop_t;
    signal sel_b     : std_logic;
    signal sel_res   : std_logic_vector(1 downto 0);

    -- Interface cpu_control <-> response_formatter
    signal resp_valid      : std_logic;
    signal resp_err        : std_logic;
    signal resp_show_flags : std_logic;
    signal format_done     : std_logic;

    -- Interface cpu_datapath -> response_formatter
    signal resp_data  : byte_t;
    signal resp_idx   : regidx_t;
    signal resp_flags : std_logic_vector(3 downto 0);

    -- Interface response_formatter <-> uart_tx
    signal tx_busy  : std_logic;
    signal tx_data  : byte_t;
    signal tx_valid : std_logic;

begin

    -- 1. Sincronizacao de reset e entrada serial assincrona
    u_input_sync : entity work.input_sync
        port map (
            clk   => clk,
            rst_i => rst_i,
            rx_i  => rx_i,
            rx_s  => rx_s,
            rst_s => rst_s
        );

    -- 2. Gerador de ticks de baud rate (16x para RX, 1x para TX)
    u_baud_gen : entity work.baud_gen
        generic map (
            CLK_HZ => CLK_HZ,
            BAUD   => BAUD,
            ACC_W  => ACC_W
        )
        port map (
            clk      => clk,
            rst      => rst_s,
            tick_16x => tick_16x,
            tick_bit => tick_bit
        );

    -- 3. Recetor UART
    u_uart_rx : entity work.uart_rx
        port map (
            clk      => clk,
            rst      => rst_s,
            tick_16x => tick_16x,
            rx_s     => rx_s,
            rx_data  => rx_data,
            rx_valid => rx_valid,
            rx_error => rx_error
        );

    -- 4. Interpretador e validador de comandos ASCII
    u_command_parser : entity work.command_parser
        generic map (
            G_FULL_ISA => G_FULL_ISA,
            G_MAX_LEN  => G_MAX_LEN
        )
        port map (
            clk          => clk,
            rst          => rst_s,
            rx_data      => rx_data,
            rx_valid     => rx_valid,
            rx_error     => rx_error,
            parser_block => parser_block,
            opcode       => cmd_opcode,
            rd           => cmd_rd,
            ra           => cmd_ra,
            rb           => cmd_rb,
            imm          => cmd_imm,
            cmd_valid    => cmd_valid,
            cmd_error    => cmd_error
        );

    -- 5. Unidade de controlo principal (FSM)
    u_cpu_control : entity work.cpu_control
        generic map (
            G_EXEC_CYCLES => G_EXEC_CYCLES
        )
        port map (
            clk             => clk,
            rst             => rst_s,
            cmd_valid       => cmd_valid,
            cmd_error       => cmd_error,
            opcode_i        => cmd_opcode,
            rd_i            => cmd_rd,
            ra_i            => cmd_ra,
            rb_i            => cmd_rb,
            imm_i           => cmd_imm,
            format_done     => format_done,
            parser_block    => parser_block,
            resp_valid      => resp_valid,
            resp_err        => resp_err,
            resp_show_flags => resp_show_flags,
            ra              => dp_ra,
            rb              => dp_rb,
            rd              => dp_rd,
            imm             => dp_imm,
            reg_we          => reg_we,
            result_ld       => result_ld,
            flags_we        => flags_we,
            alu_op          => alu_op,
            sel_b           => sel_b,
            sel_res         => sel_res
        );

    -- 6. Caminho de dados (integra reg_file e alu internamente)
    u_cpu_datapath : entity work.cpu_datapath
        port map (
            clk        => clk,
            rst        => rst_s,
            ra         => dp_ra,
            rb         => dp_rb,
            rd         => dp_rd,
            imm        => dp_imm,
            reg_we     => reg_we,
            result_ld  => result_ld,
            flags_we   => flags_we,
            alu_op     => alu_op,
            sel_b      => sel_b,
            sel_res    => sel_res,
            resp_data  => resp_data,
            resp_idx   => resp_idx,
            resp_flags => resp_flags
        );

    -- 7. Formatador de resposta ASCII
    u_response_formatter : entity work.response_formatter
        generic map (
            G_FLAGS_EN => G_FLAGS_EN
        )
        port map (
            clk             => clk,
            rst             => rst_s,
            resp_valid      => resp_valid,
            resp_err        => resp_err,
            resp_show_flags => resp_show_flags,
            resp_idx        => resp_idx,
            resp_data       => resp_data,
            resp_flags      => resp_flags,
            tx_busy         => tx_busy,
            tx_data         => tx_data,
            tx_valid        => tx_valid,
            format_done     => format_done
        );

    -- 8. Transmissor UART
    u_uart_tx : entity work.uart_tx
        port map (
            clk      => clk,
            rst      => rst_s,
            tick_bit => tick_bit,
            tx_valid => tx_valid,
            tx_data  => tx_data,
            tx_o     => tx_o,
            tx_busy  => tx_busy
        );

end architecture rtl;