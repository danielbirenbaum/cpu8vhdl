library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity uart_rx is
  port (
    clk      : in std_logic;
    rst      : in std_logic;
    tick_16x : in std_logic;
    rx_s     : in std_logic;

    rx_data  : out std_logic_vector(7 downto 0);
    rx_valid : out std_logic;
    rx_error : out std_logic
  );
end entity uart_rx;

architecture rtl of uart_rx is
  type state_t is (S_IDLE, S_START, S_DATA, S_STOP, S_WAIT_HIGH);
  signal st      : state_t                      := S_IDLE;
  signal tcnt    : unsigned(3 downto 0)         := (others => '0');
  signal bcnt    : unsigned(2 downto 0)         := (others => '0');
  signal sh      : std_logic_vector(7 downto 0) := (others => '0');
  signal data_r  : std_logic_vector(7 downto 0) := (others => '0');
  signal valid_r : std_logic                    := '0';
  signal err_r   : std_logic                    := '0';
begin
  process (clk)
  begin
    if rising_edge(clk) then
      valid_r <= '0';
      err_r   <= '0';
      if rst = '1' then
        st   <= S_IDLE;
        tcnt <= (others => '0');
        bcnt <= (others => '0');

      else
        case st is
          when S_IDLE     =>
            tcnt <= (others => '0');
            if rx_s = '0' then
              st <= S_START;
            end if;
          when S_START =>
            if tick_16x = '1' then
              if tcnt = 7 then
                if rx_s = '0' then
                  tcnt <= (others => '0');
                  bcnt <= (others => '0');
                  st   <= S_DATA;
                else
                  st <= S_IDLE;
                end if;
              else
                tcnt <= tcnt + 1;
              end if;
            end if;
            -- Estado de captura de bit, enquanto não chegar no tick 16, não salva o bit
          when S_DATA =>
            if tick_16x = '1' then
              if tcnt = 15 then
                tcnt <= (others => '0');
                sh   <= rx_s & sh(7 downto 1);
                if bcnt = 7 then
                  st <= S_STOP;
                else
                  bcnt <= bcnt + 1;
                end if;
              else
                tcnt <= tcnt + 1;
              end if;
            end if;

          when S_STOP =>
            if tick_16x = '1' then
              if tcnt = 15 then
                tcnt <= (others => '0');
                if rx_s = '1' then
                  data_r  <= sh;
                  valid_r <= '1';
                  st      <= S_IDLE;
                else
                  err_r <= '1';
                  st    <= S_WAIT_HIGH;
                end if;
              else
                tcnt <= tcnt + 1;
              end if;
            end if;

          when S_WAIT_HIGH =>
            if rx_s = '1' then
              st <= S_IDLE;
            end if;
        end case;

      end if;
    end if;
  end process;

  rx_data  <= data_r;
  rx_valid <= valid_r;
  rx_error <= err_r;

end architecture;