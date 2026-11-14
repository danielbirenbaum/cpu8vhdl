# Documentação
[← Voltar ao README principal](../README.MD)

Este índice reúne a **tabela de arquivos**, as **definições da ISA** e os **protocolos internos** da CPU de 8 bits.

**Navegação:** [Arquivos](#arquivos) · [Documentação por módulo](#documentação-por-módulo) · [Definições](#definições) · [Protocolos](#protocolos-entre-módulos) · [Genéricos](#genéricos-do-topo) 
## Arquivos
### Código-fonte — [`src/`](../src/)

| Arquivo | Conteúdo | Doc | Autor |
|---|---|---|---|
| [`cpu_top.vhd`](../src/cpu_top.vhd) | Topo: instancia e conecta os 8 módulos; expõe `clk`, `rst_i`, `rx_i`, `tx_o` e os genéricos do projeto | [doc](implemented/cpu_top/readme.md) | Daniel |
| [`cpu_pkg.vhd`](../src/cpu_pkg.vhd) | Pacote compartilhado: subtipos, opcodes, códigos `alu_op`, seleções dos MUXes, índices das flags, constantes e funções ASCII | [doc](implemented/cpu_pkg/readme.md) | Compartilhado |

#### Interface UART — [`src/uart/`](../src/uart/)

| Arquivo | Conteúdo | Doc | Autor |
|---|---|---|---|
| [`input_sync.vhd`](../src/uart/input_sync.vhd) | Sincroniza `rx_i` e `rst_i` com 2 flip-flops cada; reset entra assíncrono e sai síncrono | [doc](implemented/uart/input_sync/readme.md) | Daniel |
| [`baud_gen.vhd`](../src/uart/baud_gen.vhd) | Acumulador de fase (NCO): gera `tick_16x` (16 × baud) e `tick_bit` (1 × baud) como *enables* de 1 ciclo | [doc](implemented/uart/baud_gen/readme.md) | Daniel |
| [`uart_rx.vhd`](../src/uart/uart_rx.vhd) | Receptor 8N1 com sobreamostragem 16×; entrega `rx_data`, `rx_valid` e `rx_error` | [doc](implemented/uart/uart_rx/readme.md) | Daniel |
| [`uart_tx.vhd`](../src/uart/uart_tx.vhd) | Transmissor 8N1 sincronizado em `tick_bit`; `tx_busy` sinaliza quadro em andamento | [doc](implemented/uart/uart_tx/readme.md) | Daniel |

#### CPU — [`src/cpu/`](../src/cpu/)

| Arquivo | Conteúdo | Doc | Autor |
|---|---|---|---|
| [`command_parser.vhd`](../src/cpu/command_parser.vhd) | Filtro de entrada, buffer de 32 caracteres, detector CR/LF/CR+LF, decodificador e validador; entrega os campos ao `cpu_control` | [doc](implemented/cpu/command_parser/readme.md) | Lucas |
| [`cpu_control.vhd`](../src/cpu/cpu_control.vhd) | FSM `RECEBE → EXECUTA/ERRO → RESPONDE → LIBERA`; saídas de controle tipo Moore | [doc](implemented/cpu/cpu_control/readme.md) | Lucas |
| [`response_formatter.vhd`](../src/cpu/response_formatter.vhd) | Monta `Rn = HH` / flags / `ERR` + CR LF e envia byte a byte à `uart_tx` com *handshake* | [doc](implemented/cpu/response_formatter/readme.md) | Lucas |
| [`cpu_datapath.vhd`](../src/cpu/cpu_datapath.vhd) | Banco + ULA + MUX B + MUX Resultado + registrador de flags + captura da resposta | [doc](implemented/cpu/cpu_datapath/readme.md) | Luan |
| [`reg_file.vhd`](../src/cpu/reg_file.vhd) | Banco R0–R7: 2 leituras combinacionais por MUX + 1 escrita síncrona com *enable* | [doc](implemented/cpu/reg_file/readme.md) | Luan |
| [`alu.vhd`](../src/cpu/alu.vhd) | ULA de 8 bits: ADD, SUB, AND, OR, XOR, NOT e flags Z, C, N, V | [doc](implemented/cpu/alu/readme.md) | Luan |

### Simulação — [`sim/`](../sim/)

Detalhes de cobertura e comandos em [`sim/README.md`](../sim/README.md).

| Testbench | Verifica | Forma de onda |
|---|---|---|
| [`tb_cpu_top.vhd`](../sim/tb_cpu_top.vhd) | Sistema completo pela UART: 7 comandos válidos e 1 inválido, com texto de resposta exato | — |
| [`cpu/tb_lucas_integracao.vhd`](../sim/cpu/tb_lucas_integracao.vhd) | `command_parser` + `cpu_control` + `response_formatter` + `cpu_datapath` real + modelo de `uart_tx`: critério do M1 e casos do M2 | [`tb_lucas_integracao.vcd`](../sim/cpu/tb_lucas_integracao.vcd) |
| [`cpu/command_parser/tb_command_parser.vhd`](../sim/cpu/command_parser/tb_command_parser.vhd) | Comandos válidos e inválidos, limite de 32, CR+LF, `rx_error`, linha vazia, bloqueio | [`.vcd`](../sim/cpu/command_parser/tb_command_parser.vcd) |
| [`cpu/cpu_control/tb_cpu_control.vhd`](../sim/cpu/cpu_control/tb_cpu_control.vhd) | Uma escrita por comando, erro sem escrita, seleções estáveis, `flags_we`, liberação | [`.vcd`](../sim/cpu/cpu_control/tb_cpu_control.vcd) |
| [`cpu/response_formatter/tb_response_formatter.vhd`](../sim/cpu/response_formatter/tb_response_formatter.vhd) | Texto exato, `ERR`, flags, `tx_busy`, `format_done` só no fim, sem resposta duplicada | — |
| [`cpu/cpu_datapath/tb_cpu_datapath_unit.vhd`](../sim/cpu/cpu_datapath/tb_cpu_datapath_unit.vhd) | Banco + MUX B + ULA + MUX Resultado + captura de resultado e flags, com controle aplicado direto | [`.vcd`](../sim/cpu/cpu_datapath/tb_cpu_datapath_unit.vcd) |
| [`cpu/reg_file/tb_reg_file_unit.vhd`](../sim/cpu/reg_file/tb_reg_file_unit.vhd) | Reset síncrono, escrita habilitada e desabilitada, duas leituras | [`.vcd`](../sim/cpu/reg_file/tb_reg_file_unit.vcd) |
| [`cpu/alu/tb_alu_unit.vhd`](../sim/cpu/alu/tb_alu_unit.vhd) | ADD, SUB, AND, OR, XOR, NOT, flags e opcode não usado | [`alu_wave.vcd`](../sim/cpu/alu/alu_wave.vcd) |
| [`uart/input_sync/tb_input_sync.vhd`](../sim/uart/input_sync/tb_input_sync.vhd) | Reset de power-up, latência de 2 bordas, reset assíncrono com liberação síncrona | [`input_sync_wave.vcd`](../sim/uart/input_sync/input_sync_wave.vcd) |
| [`uart/baud_gen/tb_baud_gen.vhd`](../sim/uart/baud_gen/tb_baud_gen.vhd) | Contagem de ticks em 2¹⁶ ciclos, intervalos, erro de baud ≤ 1 %, reset, BAUD = 9600 | [`baud_gen_wave.vcd`](../sim/uart/baud_gen/baud_gen_wave.vcd) |
| [`uart/uart_rx/tb_uart_rx.vhd`](../sim/uart/uart_rx/tb_uart_rx.vhd) | Bytes de teste, stop inválido, falso start, tolerância de ±2 % no baud, reset no meio do quadro | [`uart_rx_wave.vcd`](../sim/uart/uart_rx/uart_rx_wave.vcd) |
| [`uart/uart_tx/tb_uart_tx.vhd`](../sim/uart/uart_tx/tb_uart_tx.vhd) | Start/LSB-first/stop, `tx_busy`, duração do quadro, quadros seguidos, reset no meio | [`uart_tx_wave.vcd`](../sim/uart/uart_tx/uart_tx_wave.vcd) |

### Diagramas — [`docs/`](.)

**Pré-projeto** em [`theoretical/`](theoretical/) (um PNG por bloco):

| | | | |
|---|---|---|---|
| [`00_cpu_top_visao_geral.png`](theoretical/00_cpu_top_visao_geral.png) | [`01_input_sync.png`](theoretical/01_input_sync.png) | [`02_baud_gen.png`](theoretical/02_baud_gen.png) | [`03_uart_rx.png`](theoretical/03_uart_rx.png) |
| [`04_uart_tx.png`](theoretical/04_uart_tx.png) | [`05_command_parser.png`](theoretical/05_command_parser.png) | [`06_cpu_control.png`](theoretical/06_cpu_control.png) | [`07_reg_file.png`](theoretical/07_reg_file.png) |
| [`08_alu.png`](theoretical/08_alu.png) | [`09_cpu_datapath.png`](theoretical/09_cpu_datapath.png) | [`10_response_formatter.png`](theoretical/10_response_formatter.png) | |

**Implementado** em [`implemented/`](implemented/): diagrama de bloco (`<módulo>.svg`), esquemático RTL (`schematic_<módulo>.svg`) e FSM (`fsm_<módulo>_00.svg`) onde existem.

| Módulo | Diagrama de bloco | Esquemático RTL | FSM |
|---|---|---|---|
| `input_sync` | [svg](implemented/uart/input_sync/input_sync.svg) | [svg](implemented/uart/input_sync/schematic_input_sync.svg) | — |
| `baud_gen` | [svg](implemented/uart/baud_gen/baud_gen.svg) | [svg](implemented/uart/baud_gen/schematic_baud_gen.svg) | — |
| `uart_rx` | [svg](implemented/uart/uart_rx/uart_rx.svg) | [svg](implemented/uart/uart_rx/schematic_uart_rx.svg) | [svg](implemented/uart/uart_rx/fsm_uart_rx_00.svg) |
| `uart_tx` | [svg](implemented/uart/uart_tx/uart_tx.svg) | [svg](implemented/uart/uart_tx/schematic_uart_tx.svg) | [svg](implemented/uart/uart_tx/fsm_uart_tx_00.svg) |
| `command_parser` | [svg](implemented/cpu/command_parser/command_parser.svg) | — | — |
| `cpu_control` | [svg](implemented/cpu/cpu_control/cpu_control.svg) | — | [svg](implemented/cpu/cpu_control/fsm_cpu_control_00.svg) |
| `response_formatter` | [svg](implemented/cpu/response_formatter/response_formatter.svg) | — | [svg](implemented/cpu/response_formatter/fsm_response_formatter_00.svg) |
| `cpu_datapath` | [svg](implemented/cpu/cpu_datapath/cpu_datapath.svg) | — | — |
| `reg_file` | [svg](implemented/cpu/reg_file/reg_file.svg) | [svg](implemented/cpu/reg_file/schematic_reg_file.svg) | — |
| `alu` | — | — | — |
| `cpu_top` | — | — | — |


## Documentação por módulo

| Módulo | Página |
|---|---|
| Visão geral da interface UART | [`uart/README.md`](implemented/uart/README.md) |
| `input_sync` · `baud_gen` · `uart_rx` · `uart_tx` | [input_sync](implemented/uart/input_sync/readme.md) · [baud_gen](implemented/uart/baud_gen/readme.md) · [uart_rx](implemented/uart/uart_rx/readme.md) · [uart_tx](implemented/uart/uart_tx/readme.md) |
| `command_parser` · `cpu_control` · `response_formatter` | [command_parser](implemented/cpu/command_parser/readme.md) · [cpu_control](implemented/cpu/cpu_control/readme.md) · [response_formatter](implemented/cpu/response_formatter/readme.md) |
| `cpu_datapath` · `reg_file` · `alu` | [cpu_datapath](implemented/cpu/cpu_datapath/readme.md) · [reg_file](implemented/cpu/reg_file/readme.md) · [alu](implemented/cpu/alu/readme.md) |
| `cpu_top` · `cpu_pkg` | [cpu_top](implemented/cpu_top/readme.md) · [cpu_pkg](implemented/cpu_pkg/readme.md) |



## Definições

### Instruções

| Comando | Opcode | `alu_op` | Operação | Flags | Resposta |
|---|---|---|---|---|---|
| `LDI Rd,HH` | `0000` | — | `Rd ← HH` | preserva | `Rd = HH` |
| `ADD Rd,Ra,Rb` | `0001` | `0000` | `Rd ← Ra + Rb` | atualiza | `Rd = HH Z=z C=c N=n V=v` |
| `SUB Rd,Ra,Rb` | `0010` | `0001` | `Rd ← Ra − Rb` | atualiza | idem |
| `AND Rd,Ra,Rb` | `0011` | `0010` | `Rd ← Ra and Rb` | atualiza | idem |
| `OR Rd,Ra,Rb` | `0100` | `0011` | `Rd ← Ra or Rb` | atualiza | idem |
| `XOR Rd,Ra,Rb` | `0101` | `0100` | `Rd ← Ra xor Rb` | atualiza | idem |
| `NOT Rd,Ra` | `0110` | `0101` | `Rd ← not Ra` | atualiza | idem |
| `MOV Rd,Ra` | `0111` | — | `Rd ← Ra` | preserva | `Rd = HH` |
| `ADDI Rd,Ra,HH` | `1000` | `0000` | `Rd ← Ra + HH` | atualiza | idem |

### Flags

| Flag | Bit em `resp_flags` | Significado |
|---|---|---|
| `Z` | 3 | Resultado igual a `00` |
| `C` | 2 | Carry de saída no `ADD`; no `SUB`, `1` = **sem** *borrow* (`Ra ≥ Rb`); `0` nas lógicas |
| `N` | 1 | Bit 7 do resultado |
| `V` | 0 | Overflow em complemento de 2 (`ADD`/`SUB`); `0` nas lógicas |

### Seleções do caminho de dados

| Sinal | Valor | Fonte |
|---|---|---|
| `sel_b` | `0` | Segunda leitura do banco (`Rb`) |
| `sel_b` | `1` | Imediato |
| `sel_res` | `00` | Resultado da ULA |
| `sel_res` | `01` | Primeira leitura (`Ra`) |
| `sel_res` | `10` | Segunda leitura (`Rb`) |
| `sel_res` | `11` | Imediato |

## Protocolos entre módulos

### Respostas ASCII

`CR = 0x0D`, `LF = 0x0A`.

| Caso | Texto | Bytes |
|---|---|---|
| `LDI` / `MOV` | `Rn = HH` CR LF | 9 |
| Operações com flags | `Rn = HH Z=z C=c N=n V=v` CR LF | 25 |
| Erro | `ERR` CR LF | 5 |

### Handshakes

| Entre | Sinais | Regra |
|---|---|---|
| `command_parser` → `cpu_control` | `cmd_valid`, `cmd_error` | Pulsos de 1 ciclo; campos `opcode`, `rd`, `ra`, `rb`, `imm` ficam registrados |
| `cpu_control` → `command_parser` | `parser_block` | `0` em `RECEBE` e `LIBERA`; `1` nos demais estados. Garante **um comando por vez** |
| `cpu_control` ↔ `response_formatter` | `resp_valid` → … → `format_done` | O formatador só aceita nova resposta depois que `resp_valid` voltar a `0` |
| `response_formatter` ↔ `uart_tx` | `tx_valid`, `tx_busy` | `tx_valid` pulsa 1 ciclo só com `tx_busy = 0`; o formatador espera `tx_busy` subir e cair a cada byte |
| `baud_gen` → `uart_rx` / `uart_tx` | `tick_16x`, `tick_bit` | *Enables* de 1 ciclo no domínio do clock principal; não há clocks derivados |


## Genéricos do topo

Definidos em [`cpu_top`](../src/cpu_top.vhd) e repassados aos módulos.

| Genérico | Padrão | Efeito | Módulo |
|---|---|---|---|
| `CLK_HZ` | `50_000_000` | Frequência do oscilador, usada no cálculo do baud | `baud_gen` |
| `BAUD` | `115_200` | Taxa da UART | `baud_gen` |
| `ACC_W` | `16` | Largura do acumulador NCO | `baud_gen` |
| `G_FULL_ISA` | `true` | `false` aceita só `LDI` e `ADD` (marco M1) | `command_parser` |
| `G_MAX_LEN` | `32` | Tamanho máximo da linha de comando | `command_parser` |
| `G_EXEC_CYCLES` | `2` | Ciclos no estado `EXECUTA` (≥ 1) | `cpu_control` |
| `G_FLAGS_EN` | `true` | `false` nunca envia flags na resposta (marco M1) | `response_formatter` |