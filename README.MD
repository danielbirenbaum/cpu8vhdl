# CPU de 8 Bits descrita em VHDL
#### Autores:
- Daniel Birenbaum
- Luan Machado
- Lucas Elbert
#### Professor e Orientador:
- Prof. Fernando Dias

## Objetivos
O projeto consiste em um processador simples de 8 bits, com oito registradores R0 a R7, que
executa comandos recebidos por um terminal serial. O computador envia uma instrução em texto; a
FPGA a interpreta, opera sobre os registradores e devolve o resultado em caracteres ASCII.
A arquitetura será dividida em interface UART, unidade de controle e caminho de dados. A unidade
de controle será uma máquina de estados. Não haverá memória de programa, memória de dados
externa, pipeline ou sobreposição entre comandos. Os buffers e registradores internos manterão
apenas o comando e o estado necessários à execução.
As fontes de dados serão selecionadas por multiplexadores. O banco terá duas portas de leitura e
uma de escrita. Não serão utilizados buffers Three-State ou barramentos internos em alta
impedância.