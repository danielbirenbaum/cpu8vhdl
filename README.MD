# CPU de 8 Bits descrita em VHDL
#### Autores:
- Daniel Birenbaum
- Luan Machado
- Lucas Elbert
#### Professor e Orientador:
- Prof. Fernando Dias

## Objetivos
O projeto consiste em um processador simples de **8 bits**, com oito registradores **R0 a R7**, que
executa comandos recebidos por um terminal serial. O computador envia uma instrução em texto; a
FPGA a interpreta, opera sobre os registradores e devolve o resultado em caracteres **ASCII**.
A arquitetura é dividida em **interface UART**, **unidade de controle** e **caminho de dados**. A unidade
de controle é uma **máquina de estados**. Não há memória de programa, memória de dados
externa, pipeline ou sobreposição entre comandos. Os buffers e registradores internos manterão
apenas o comando e o estado necessários à execução.
As fontes de dados são selecionadas por multiplexadores. O banco possui duas portas de leitura e
uma de escrita. Não são utilizados buffers Three-State ou barramentos internos em alta
impedância.

## Hierarquia do projeto

* [`/src`](/src/) contém todos os módulos .vhd do projeto, com duas subpastas e dois arquivo: [`cpu_top.vhd`](/src/cpu_top.vhd),[`cpu_pkg.vhd`](/src/cpu_pkg.vhd), [`/uart`](/src/uart/) e [`/cpu`](/src/cpu/).
* [`/sim`](/sim/) contém todos os Testbenches e formas de onda simulados no GTKWave através do GHDL.
* [`/docs`](/docs/) contém todos os diagramas esquemáticos e documentação de cada módulo implementado. [`/docs/theoretical`](/docs/theoretical/) contém os diagramas de pré-projeto, contendo especificações inciais teoricas. [`/docs/implemented`](/docs/implemented/) contém os refericos diagrmas e documentações implementados efetivamente.


## Divisão de responsabilidade

#### Daniel Birenbaum
- **Interface UART**: [`baud_gen.vhd`](/src/uart/baud_gen.vhd), [`input_sync.vhd`](/src/uart/input_sync.vhd), [`uart_rx.vhd`](/src/uart/uart_rx.vhd) e [`uart_tx.vhd`](/src/uart/uart_tx.vhd)

<!--TODO: Responsabilidades do Luan e Lucas-->
