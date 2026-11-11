# Interface UART

A comunicação UART (Universal Asynchronous Receiver-Transmitter) é um protocolo serial assíncrono utilizado para a troca de dados entre o computador e o sistema digital (FPGA/ASIC). Por ser assíncrono, o sinal não carrega uma linha de relógio (clock) compartilhada; portanto, emissor e receptor devem concordar previamente com uma taxa de transmissão comum (Baud Rate, em bits por segundo).

## Baud Rate [`baud_gen.vhd`](/src/uart/baud_gen.vhd)
A correta leitura da entrada serial é essencial para seu funcionamento pleno. Para mensurar a quantidade de ciclos de clocks, convenciona-se que 1 bit deverá ser lido a partir de 16 "ticks". De tal maneira que toma-se a amostragem (leitura do bit) no oitavo bit. Para converter corretamente, temos que:

```math

\text{CLKS\_PER\_TICK\_16X} = \frac{\text{CLK\_HZ}}{16 \cdot BAUD}

```
Onde CLKS_PER_TICK_16X é uma variável que contabiliza quantos ciclos de clock **um (1)** tick toma da frequência.

Para a saída (transmissão) não é necessário 16 ticks para a correta amostragem, portanto, uma única saída `tick_bit` é suficiente. Para manter o padrão de que 16 ticks indicam um bit, o `tick_bit` espera o sinal `tick_16x`.





### Fontes e Referências


https://nandland.com/uart-serial-port-module/

https://www.youtube.com/watch?v=xLSgmDTRmCI

https://youtu.be/zAgO7IX_cTg?si=0tqmFfzmNgVkB5eB
