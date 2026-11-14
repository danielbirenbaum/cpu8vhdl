# `reg_file`

[← Índice da documentação](../../../readme.md) · **Autor:** Luan Machado

| | |
|---|---|
| **Fonte** | [`src/cpu/reg_file.vhd`](../../../../src/cpu/reg_file.vhd) |
| **Testbench** | [`sim/cpu/reg_file/tb_reg_file_unit.vhd`](../../../../sim/cpu/reg_file/tb_reg_file_unit.vhd) |
| **Teórico** | [`07_reg_file.png`](../../../theoretical/07_reg_file.png) |
| **Esquemático RTL** | [`schematic_reg_file.svg`](schematic_reg_file.svg) |

## Diagrama

![Diagrama de bloco do reg_file](reg_file.svg)

## Portas

| Porta | Dir. | Tipo | Descrição |
|---|---|---|---|
| `clk` | in | `std_logic` | Clock principal |
| `rst` | in | `std_logic` | Reset síncrono: zera R0–R7 |
| `we` | in | `std_logic` | Habilita a escrita |
| `wr_addr` | in | `std_logic_vector(2 downto 0)` | Registrador a escrever |
| `wr_data` | in | `std_logic_vector(7 downto 0)` | Dado a escrever |
| `rd_addr_a` | in | `std_logic_vector(2 downto 0)` | Registrador da porta de leitura A |
| `rd_addr_b` | in | `std_logic_vector(2 downto 0)` | Registrador da porta de leitura B |
| `rd_data_a` | out | `std_logic_vector(7 downto 0)` | Dado da porta A |
| `rd_data_b` | out | `std_logic_vector(7 downto 0)` | Dado da porta B |

## Comportamento

- **Escrita:** na borda de subida, se `rst = 0` e `we = 1`, `regs(wr_addr) ← wr_data`.
- **Reset:** síncrono; todos os registradores vão a `00` (também no estado inicial).
- **Leitura:** combinacional por MUX (`rd_data_a = regs(rd_addr_a)`, idem B). Ler o endereço que está sendo escrito no mesmo ciclo devolve o valor **antigo**.

<details>
<summary>Sinais e tipos internos</summary>

| Nome | Tipo | Descrição |
|---|---|---|
| `regs_t` | `array (0 to 7) of std_logic_vector(7 downto 0)` | Tipo do banco |
| `regs` | `regs_t` | Os oito registradores |

</details>
