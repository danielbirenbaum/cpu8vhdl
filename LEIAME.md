# Módulos do Lucas: parser, unidade de controle e formatador

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| `cpu_pkg.vhd` | Pacote compartilhado: opcodes, códigos `alu_op`, seleções dos MUXes, ordem das flags e funções ASCII. **Compilar primeiro.** |
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

## Definições (a cargo do Lucas segundo a proposta)

Sintaxe (só maiúsculas; espaço obrigatório após a operação; espaços opcionais em volta das vírgulas):

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

Linha vazia é ignorada (por isso o LF de um CR+LF não gera resposta).

## Pontos a alinhar com o grupo

**Com o Luan (`cpu_datapath` / `alu`)**, constantes em `cpu_pkg.vhd`:
- `alu_op`: a ULA usa `op` de 3 bits; o datapath liga `op => alu_op(2 downto 0)`. ADD `0000`, SUB `0001`, AND `0010`, OR `0011`, XOR `0100`, NOT `0101` (NOT opera sobre A).
- `sel_b` (1 bit): `0` = Rb, `1` = imm.
- `sel_res` (2 bits): `00` = alu_result, `01` = Ra, `10` = Rb, `11` = imm.
- `resp_flags(3 downto 0)` = Z, C, N, V.
- O datapath captura `wr_data` e `rd` quando `result_ld = 1` e atualiza as flags quando `flags_we = 1`, na mesma borda de `reg_we`.

**Com o Daniel (`cpu_top` / UART)**:
- `rst` dos meus módulos é síncrono e ativo em `'1'` (`rst_s`).
- `rx_valid` deve ser um pulso de 1 ciclo. `rx_error` pode vir junto ou separado.
- `uart_tx` precisa aceitar o byte com `tx_valid` e manter `tx_busy = 1` até o fim do stop bit.
- O `cpu_control` tem uma saída a mais que o diagrama, `resp_show_flags`, ligada ao `response_formatter`.

## Generics (M1 × M2)

| Módulo | Generic | M1 | M2 |
|---|---|---|---|
| `command_parser` | `G_FULL_ISA` | `false` (só LDI e ADD) | `true` |
| `response_formatter` | `G_FLAGS_EN` | `false` (só `Rn = HH`) | `true` |
| `cpu_control` | `G_EXEC_CYCLES` | `2` | `2` |

## Simulação com GHDL

```sh
ghdl -a cpu_pkg.vhd alu.vhd reg_file.vhd cpu_datapath.vhd command_parser.vhd cpu_control.vhd response_formatter.vhd
ghdl -a tb_command_parser.vhd tb_cpu_control.vhd tb_response_formatter.vhd tb_lucas_integracao.vhd
ghdl -r tb_command_parser      --wave=parser.ghw
ghdl -r tb_cpu_control         --wave=control.ghw
ghdl -r tb_response_formatter  --wave=formatter.ghw
ghdl -r tb_lucas_integracao    --wave=integracao.ghw
```

Cada testbench termina com `TODOS OS TESTES PASSARAM` ou com a lista de falhas. No ModelSim/Questa, compile na mesma ordem (`vcom`) e rode `run -all`.
