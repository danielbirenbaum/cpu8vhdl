# `input_sync`

[← Interface UART](../README.md) · [Índice](../../../readme.md) · **Autor:** Daniel Birenbaum


| | |
|---|---|
| **Fonte** | [`src/uart/input_sync.vhd`](../../../../src/uart/input_sync.vhd) |
| **Testbench** | [`sim/uart/input_sync/tb_input_sync.vhd`](../../../../sim/uart/input_sync/tb_input_sync.vhd) |
| **Teórico** | [`01_input_sync.png`](../../../theoretical/01_input_sync.png) |
| **Esquemático RTL** | [`schematic_input_sync.svg`](schematic_input_sync.svg) |

## Diagrama

![Diagrama de bloco do input_sync](input_sync.svg)

## Portas

| Porta | Dir. | Tipo | Descrição |
|---|---|---|---|
| `clk` | in | `std_logic` | Clock principal |
| `rst_i` | in | `std_logic` | Reset externo (botão), ativo em `1`, assíncrono |
| `rx_i` | in | `std_logic` | Entrada serial vinda do conversor USB-UART, assíncrona |
| `rx_s` | out | `std_logic` | `rx_i` sincronizado; mantido em `1` (repouso) durante o reset |
| `rst_s` | out | `std_logic` | Reset sincronizado, distribuído a todos os blocos |

## Comportamento

- **Reset:** `rst_i = 1` força `rst_ff = "11"` na hora (assíncrono). Ao soltar, um `0` percorre os dois flip-flops, então `rst_s` cai **2 bordas** depois (liberação síncrona).
- **Power-up:** `rst_ff` inicia em `"11"`, então a FPGA nasce em reset.
- **RX:** `rx_ff` desloca `rx_i` a cada borda; `rx_s` sai com latência de **2 bordas**. Enquanto `rst_s = 1`, `rx_ff` fica em `"11"`.
- Um pulso de reset mais curto que o clock é alongado até 2 bordas.

<details>
<summary>Sinais internos</summary>

| Sinal | Tipo | Descrição |
|---|---|---|
| `rx_ff` | `std_logic_vector(1 downto 0)` | Cadeia de sincronização do RX |
| `rst_ff` | `std_logic_vector(1 downto 0)` | Cadeia de sincronização do reset |

</details>
