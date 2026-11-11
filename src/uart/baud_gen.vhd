library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity baud_gen is
    generic (
        CLK_HZ : integer := 50_000_000;
        BAUD   : integer := 115_200
    );
    port (
        clk      : in  std_logic;
        rst_s    : in  std_logic;
        tick_16x : out std_logic;
        tick_bit : out std_logic
    );
end entity baud_gen;

architecture rtl of baud_gen is
    -- Quantidade de ciclos de clock por tick
    constant CLKS_PER_TICK_16X : integer := CLK_HZ / (16 * BAUD);
    -- r_count_16x monitora a quantidade de clocks até chegar no número para um tick
    -- r_c
    signal r_count_16x : integer range 0 to CLKS_PER_TICK_16X - 1 := 0;
    signal r_count_bit : integer range 0 to 15 := 0;

    --r_tick_16x retorna quando há 1 tick
    --r_tick_bit retorna quando há 16 ticks (1 bit) (para transmissão)
    signal r_tick_16x : std_logic := '0';
    signal r_tick_bit : std_logic := '0';

begin

    p_gen : process (clk)
    begin
        if rising_edge(clk) then
            if rst_s = '1' then
                r_count_16x <= 0;
                r_count_bit <= 0;
                r_tick_16x  <= '0';
                r_tick_bit  <= '0';
            else
                r_tick_16x <= '0';
                r_tick_bit <= '0';

                if r_count_16x = CLKS_PER_TICK_16X - 1 then
                    r_count_16x <= 0;
                    r_tick_16x  <= '1';

                    -- Incrementa a contagem de bits sincronizada com o tick 16x
                    if r_count_bit = 15 then
                        r_count_bit <= 0;
                        r_tick_bit  <= '1'; -- Dispara tick_bit no mesmo ciclo do 16º tick_16x
                    else
                        r_count_bit <= r_count_bit + 1;
                    end if;
                else
                    r_count_16x <= r_count_16x + 1;
                end if;
            end if;
        end if;
    end process p_gen;

    tick_16x <= r_tick_16x;
    tick_bit <= r_tick_bit;

end architecture rtl;