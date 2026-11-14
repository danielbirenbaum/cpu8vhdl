# `cpu_pkg`

[← Índice da documentação](../../readme.md)

| | |
|---|---|
| **Fonte** | [`src/cpu_pkg.vhd`](../../../src/cpu_pkg.vhd) |
| **Usado por** | `cpu_top`, `command_parser`, `cpu_control`, `cpu_datapath`, `alu`, `response_formatter` |

## Subtipos

| Nome | Definição | Uso |
|---|---|---|
| `byte_t` | `std_logic_vector(7 downto 0)` | Dados e caracteres |
| `opcode_t` | `std_logic_vector(3 downto 0)` | Operação decodificada |
| `aluop_t` | `std_logic_vector(3 downto 0)` | Operação da ULA |
| `regidx_t` | `std_logic_vector(2 downto 0)` | Índice de registrador (R0–R7) |

## Opcodes

Gerados pelo `command_parser` e consumidos pelo `cpu_control`.

| Constante | Valor | Sintaxe |
|---|---|---|
| `OP_LDI` | `0000` | `LDI Rd,HH` |
| `OP_ADD` | `0001` | `ADD Rd,Ra,Rb` |
| `OP_SUB` | `0010` | `SUB Rd,Ra,Rb` |
| `OP_AND` | `0011` | `AND Rd,Ra,Rb` |
| `OP_OR` | `0100` | `OR Rd,Ra,Rb` |
| `OP_XOR` | `0101` | `XOR Rd,Ra,Rb` |
| `OP_NOT` | `0110` | `NOT Rd,Ra` |
| `OP_MOV` | `0111` | `MOV Rd,Ra` |
| `OP_ADDI` | `1000` | `ADDI Rd,Ra,HH` |

## Códigos da ULA

Devem estar alinhados com [`alu.vhd`](../../../src/cpu/alu.vhd).

| Constante | Valor |
|---|---|
| `ALU_ADD` | `0000` |
| `ALU_SUB` | `0001` |
| `ALU_AND` | `0010` |
| `ALU_OR` | `0011` |
| `ALU_XOR` | `0100` |
| `ALU_NOT` | `0101` (opera sobre A) |

## Seleções dos MUXes

| Constante | Valor | Fonte |
|---|---|---|
| `SELB_REG` | `'0'` | Segunda leitura do banco (`Rb`) |
| `SELB_IMM` | `'1'` | Imediato |
| `SELR_ALU` | `"00"` | `alu_result` |
| `SELR_A` | `"01"` | Primeira leitura (`Ra`) |
| `SELR_B` | `"10"` | Segunda leitura (`Rb`) |
| `SELR_IMM` | `"11"` | Imediato |

## Índices das flags em `resp_flags`

| Constante | Índice |
|---|---|
| `FLAG_Z` | 3 |
| `FLAG_C` | 2 |
| `FLAG_N` | 1 |
| `FLAG_V` | 0 |

## ASCII e funções

| Constante | Valor |
|---|---|
| `ASCII_CR` | `0x0D` |
| `ASCII_LF` | `0x0A` |
| `ASCII_SPACE` | `0x20` |
| `ASCII_COMMA` | `0x2C` |
| `ASCII_EQUAL` | `0x3D` |

| Função | Descrição |
|---|---|
| `to_byte(c)` | Caractere VHDL → byte ASCII |
| `hex_ascii(n)` | Nibble `0`–`F` → caractere `'0'`–`'9'`, `'A'`–`'F'` |
| `bit_ascii(b)` | Bit → `'0'` ou `'1'` |
| `is_hex(b)` | `true` para `0`–`9` e `A`–`F` (somente maiúsculas) |
| `is_upper(b)` | `true` para `A`–`Z` |
| `hex_val(b)` | Dígito hexadecimal ASCII → nibble (supõe `is_hex = true`) |
| `pack4(s)` | Empacota um mnemônico de até 4 letras, alinhado à direita e completado com espaços à esquerda. Ex.: `"ADD"` → `x"20414444"` |
