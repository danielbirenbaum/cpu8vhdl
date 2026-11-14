# `baud_gen`

[← Interface UART](../README.md) · [Índice](../../../readme.md) · **Autor:** Daniel Birenbaum


| | |
|---|---|
| **Fonte** | [`src/uart/baud_gen.vhd`](../../../../src/uart/baud_gen.vhd) |
| **Testbench** | [`sim/uart/baud_gen/tb_baud_gen.vhd`](../../../../sim/uart/baud_gen/tb_baud_gen.vhd) |
| **Teórico** | [`02_baud_gen.png`](../../../theoretical/02_baud_gen.png) |
| **Esquemático RTL** | [`schematic_baud_gen.svg`](schematic_baud_gen.svg) |

## Diagrama

![Diagrama de bloco do baud_gen](baud_gen.svg)

## Genéricos

| Genérico | Tipo | Padrão | Descrição |
|---|---|---|---|
| `CLK_HZ` | `positive` | `50_000_000` | Frequência do oscilador (`CLK_50MHZ` da placa) |
| `BAUD` | `positive` | `115_200` | Taxa de transmissão desejada |
| `ACC_W` | `positive` | `16` | Largura do acumulador; define a resolução do baud |

## Portas

| Porta | Dir. | Tipo | Descrição |
|---|---|---|---|
| `clk` | in | `std_logic` | Clock principal |
| `rst` | in | `std_logic` | Reset síncrono (`rst_s`) |
| `tick_16x` | out | `std_logic` | Pulso de 1 ciclo a `16 × BAUD`, usado na amostragem do RX |
| `tick_bit` | out | `std_logic` | Pulso de 1 ciclo a `1 × BAUD`, usado pelo TX; coincide com um `tick_16x` |

## Cálculo

```math
INC = \mathrm{round}\!\left(\frac{16 \cdot BAUD \cdot 2^{ACC\_W}}{CLK\_HZ}\right)
```

| `CLK_HZ` | `BAUD` | `ACC_W` | `INC` | `tick_16x` médio | Erro no baud |
|---|---|---|---|---|---|
| 50 MHz | 115200 | 16 | 2416 | 1 843 261,7 Hz | +0,0033 % |

Um `assert` interrompe a elaboração se `INC` sair de `0 < INC < 2^ACC_W`.

## Comportamento

A cada ciclo, `acc ← acc + INC`; o *carry* da soma vira `t16` (registrado) e `tick_16x = t16`.
Um contador `cnt16` conta os `tick_16x`, e `tick_bit = t16` quando `cnt16 = 15`.

- `tick_16x` dura 1 ciclo, com intervalos de 27 ou 28 ciclos.
- `tick_bit` tem intervalos de 434 ou 435 ciclos.

<details>
<summary>Sinais e constantes internos</summary>

| Nome | Tipo | Descrição |
|---|---|---|
| `INC` | `natural` (constante) | Incremento do NCO |
| `acc` | `unsigned(ACC_W-1 downto 0)` | Acumulador de fase |
| `sum` | `unsigned(ACC_W downto 0)` | `acc + INC` com um bit a mais para o *carry* |
| `t16` | `std_logic` | *Carry* registrado, ou seja, o `tick_16x` |
| `cnt16` | `unsigned(3 downto 0)` | Conta `tick_16x` de 0 a 15 |

</details>
