# `alu`

[← Índice da documentação](../../../readme.md) · **Autor:** Luan Machado

| | |
|---|---|
| **Fonte** | [`src/cpu/alu.vhd`](../../../../src/cpu/alu.vhd) |
| **Testbench** | [`sim/cpu/alu/tb_alu_unit.vhd`](../../../../sim/cpu/alu/tb_alu_unit.vhd) |
| **Teórico** | [`08_alu.png`](../../../theoretical/08_alu.png) |

## Diagrama

![Diagrama de bloco da alu](alu.svg)

## Portas

| Porta | Dir. | Tipo | Descrição |
|---|---|---|---|
| `a` | in | `byte_t` | Operando A (primeira leitura do banco) |
| `b` | in | `byte_t` | Operando B (`Rb` ou imediato, escolhido pelo MUX B) |
| `op` | in | `aluop_t` | Operação (códigos `ALU_*` do [`cpu_pkg`](../../cpu_pkg/readme.md)) |
| `resultado` | out | `byte_t` | Resultado da operação |
| `z` | out | `std_logic` | Resultado igual a `00` |
| `c` | out | `std_logic` | Carry (ver tabela) |
| `n` | out | `std_logic` | Bit 7 do resultado |
| `v` | out | `std_logic` | Overflow em complemento de 2 |

## Operações e flags

| `op` | Código | Resultado | `C` | `V` |
|---|---|---|---|---|
| `ALU_ADD` | `0000` | `a + b` | carry de saída (bit 8) | `1` se `a` e `b` têm o mesmo sinal e o sinal do resultado é diferente |
| `ALU_SUB` | `0001` | `a − b` | `1` se `a ≥ b` (**sem** *borrow*) | `1` se `a` e `b` têm sinais diferentes e o sinal do resultado difere do de `a` |
| `ALU_AND` | `0010` | `a and b` | `0` | `0` |
| `ALU_OR` | `0011` | `a or b` | `0` | `0` |
| `ALU_XOR` | `0100` | `a xor b` | `0` | `0` |
| `ALU_NOT` | `0101` | `not a` (ignora `b`) | `0` | `0` |
| outro | — | `00` | `0` | `0` |

`Z = 1` quando o resultado é `00` e `N` copia o bit 7 do resultado, em todas as operações.
