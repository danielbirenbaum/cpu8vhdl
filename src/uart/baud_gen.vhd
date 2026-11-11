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

    constant CLKS_PER_TICK_16X : integer := CLK_HZ / (16 * BAUD);

    signal r_count_16x : integer range 0 to CLKS_PER_TICK_16X - 1 := 0;
    signal r_count_bit : integer range 0 to 15 := 0;

    signal r_tick_16x : std_logic := '0';
    signal r_tick_bit : std_logic := '0';

begin

    -- Divisor de clock: Gerador de tick_16x
    p_gen_16x: process (clk) 
    begin
        if rising_edge(clk) then
            if rst_s = '1' then
                r_count_16x <= 0;
                r_tick_16x  <= '0';
            else
                if r_count_16x = CLKS_PER_TICK_16X - 1 then
                    r_count_16x <= 0;
                    r_tick_16x  <= '1';
                else
                    r_count_16x <= r_count_16x + 1;
                    r_tick_16x  <= '0';
                end if;
            end if;
        end if;
    end process p_gen_16x;

    -- Contador de ticks: Gerador de tick_bit
    p_gen_bit : process (clk)
    begin
        if rising_edge(clk) then
            if rst_s = '1' then
                r_count_bit <= 0;
                r_tick_bit  <= '0';
            else
                r_tick_bit <= '0';

                if r_tick_16x = '1' then
                    if r_count_bit = 15 then 
                        r_count_bit <= 0;
                        r_tick_bit  <= '1';
                    else
                        r_count_bit <= r_count_bit + 1;
                    end if;
                end if;
            end if;
        end if;
    end process p_gen_bit;
    
    tick_16x <= r_tick_16x;
    tick_bit <= r_tick_bit;

end architecture rtl;