library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- Gera habilitacoes (enables de 1 ciclo) no dominio do clock principal.
-- Nao cria clocks internos.
--   tick_16x : 16 x BAUD, usado na amostragem do RX.
--   tick_bit : 1 x BAUD, usado pelo TX (coincide com um tick_16x a cada 16).
-- Acumulador de fase (NCO) parametrizado por CLK_HZ e BAUD:
--   INC = round(16 * BAUD * 2**ACC_W / CLK_HZ)
--   Para CLK_HZ = 50 MHz, BAUD = 115200, ACC_W = 16: INC = 2416
--   -> freq. media de tick_16x = 1 843 261,7 Hz (erro de +0,0033 % no baud).
entity baud_gen is
    generic (
        CLK_HZ : positive := 50_000_000;  -- oscilador CLK_50MHZ da placa
        BAUD   : positive := 115_200;
        ACC_W  : positive := 16
    );
    port (
        clk, rst : in  std_logic;
        tick_16x : out std_logic;
        tick_bit : out std_logic
    );
end entity baud_gen;

architecture rtl of baud_gen is
    constant INC : natural :=
        integer(round(real(BAUD) * 16.0 * (2.0 ** ACC_W) / real(CLK_HZ)));
    signal acc   : unsigned(ACC_W - 1 downto 0) := (others => '0');
    signal sum   : unsigned(ACC_W downto 0);
    signal t16   : std_logic := '0';
    signal cnt16 : unsigned(3 downto 0) := (others => '0');
begin
    assert INC > 0 and INC < 2 ** ACC_W
        report "baud_gen: INC fora da faixa; ajuste ACC_W / CLK_HZ / BAUD"
        severity failure;

    sum <= ('0' & acc) + to_unsigned(INC, ACC_W + 1);

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                acc   <= (others => '0');
                t16   <= '0';
                cnt16 <= (others => '0');
            else
                acc <= sum(ACC_W - 1 downto 0);
                t16 <= sum(ACC_W);              -- carry = tick
                if t16 = '1' then
                    cnt16 <= cnt16 + 1;         -- retorna a 0 apos 15
                end if;
            end if;
        end if;
    end process;

    tick_16x <= t16;
    tick_bit <= t16 when cnt16 = 15 else '0';
end architecture rtl;