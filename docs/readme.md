## Arquivos
<!--TODO: atualizar a lista de arquivos com o novo paradigma de topo e novos arquivos--> 
| Arquivo | Conteúdo |
|---|---|
| `cpu_pkg.vhd` | Pacote compartilhado: opcodes, códigos `alu_op`, seleções dos MUXes, ordem das flags e funções ASCII.|
| `command_parser.vhd` | Filtro de entrada, buffer de 32 caracteres, detector CR/LF/CR+LF, decodificador e validador |
| `cpu_control.vhd` | FSM RECEBE → EXECUTA/ERRO → RESPONDE → LIBERA |
| `response_formatter.vhd` | `Rn = HH` / flags / `ERR` + CR LF, handshake byte a byte com `uart_tx` |
| `alu.vhd` | ULA do Luan (sem alterações) |
| `reg_file.vhd` | Banco R0–R7, 2 leituras por MUX + 1 escrita com enable |
| `cpu_datapath.vhd` | Banco + ULA + MUX B + MUX Resultado + flags + captura da resposta |
| `tb_command_parser.vhd` | Comandos válidos e inválidos, limite de 32, CR+LF, `rx_error`, bloqueio |
| `tb_cpu_control.vhd` | Uma escrita por comando, erro sem escrita, seleções estáveis, flags, liberação |
| `tb_response_formatter.vhd` | Texto exato, ERR, flags, `tx_busy`, `format_done` só no fim |
| `tb_lucas_integracao.vhd` | Os 3 módulos + `cpu_datapath` real + modelo de `uart_tx`: critério do M1 e casos do M2 |

## Definições


| Comando | Opcode | Operação | Flags | Resposta |
|---|---|---|---|---|
| `LDI Rd,HH` | `0000` | Rd ← HH | preserva | `Rd = HH` |
| `ADD Rd,Ra,Rb` | `0001` | Ra + Rb | atualiza | `Rd = HH Z=z C=c N=n V=v` |
| `SUB Rd,Ra,Rb` | `0010` | Ra − Rb | atualiza | idem |
| `AND Rd,Ra,Rb` | `0011` | Ra and Rb | atualiza | idem |
| `OR Rd,Ra,Rb` | `0100` | Ra or Rb | atualiza | idem |
| `XOR Rd,Ra,Rb` | `0101` | Ra xor Rb | atualiza | idem |
| `NOT Rd,Ra` | `0110` | not Ra | atualiza | idem |
| `MOV Rd,Ra` | `0111` | Rd ← Ra | preserva | `Rd = HH` |
| `ADDI Rd,Ra,HH` | `1000` | Ra + HH | atualiza | idem |
