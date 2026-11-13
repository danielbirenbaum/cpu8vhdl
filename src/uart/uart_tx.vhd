library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
entity uart_tx is
  port (
    clk      : in std_logic;
    rst      : in std_logic;
    tick_bit : in std_logic;
    tx_valid : in std_logic;
    tx_data  : in std_logic_vector(7 downto 0);
    tx_o     : out std_logic;
    tx_busy  : out std_logic
  );
end entity;

architecture rtl of uart_tx is
  type state_t is (S_IDLE, S_SYNC, S_DATA, S_STOP, S_END);
  signal st   : state_t                      := S_IDLE;
  signal sh   : std_logic_vector(7 downto 0) := (others => '0');
  signal bcnt : unsigned(2 downto 0)         := (others => '0');
  signal tx_r : std_logic                    := '1';

begin

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        st   <= S_IDLE;
        tx_r <= '1';
        bcnt <= (others => '0');
      else
        case st is
          when S_IDLE =>
            tx_r <= '1';
            if tx_valid = '1' then
              sh <= tx_data;
              st <= S_SYNC;
            end if;
          when S_SYNC =>
            if tick_bit = '1' then
              tx_r <= '0';
              bcnt <= (others => '0');
              st   <= S_DATA;
            end if;

          when S_DATA =>
            if tick_bit = '1' then
              tx_r <= sh(0);
              sh   <= '1' & sh(7 downto 1);
              if bcnt = 7 then
                st <= S_STOP;
              else
                bcnt <= bcnt + 1;
              end if;
            end if;

          when S_STOP =>
            if tick_bit = '1' then
              tx_r <= '1';
              st   <= S_END;
            end if;

          when S_END =>
            if tick_bit = '1' then
              st <= S_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  tx_o    <= tx_r;
  tx_busy <= '0' when st = S_IDLE else
    '1';

end architecture;