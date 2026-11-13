library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity input_sync is
  port (
    clk   : in std_logic;
    rst_i : in std_logic;
    rx_i  : in std_logic;

    rx_s  : out std_logic;
    rst_s : out std_logic
  );
end entity;

architecture rtl of input_sync is
  signal rx_ff  : std_logic_vector(1 downto 0) := "11";
  signal rst_ff : std_logic_vector(1 downto 0) := "11";
begin

  process (clk, rst_i)
  begin
    if rst_i = '1' then
      rst_ff <= "11";
    elsif rising_edge(clk) then
      rst_ff <= rst_ff(0) & '0';
    end if;
  end process;

  rst_s <= rst_ff(1);

  process (clk)
  begin
    if rising_edge(clk) then
      if rst_ff(1) = '1' then
        rx_ff <= "11";
      else
        rx_ff <= rx_ff(0) & rx_i;
      end if;
    end if;
  end process;
  rx_s <= rx_ff(1);
end architecture;