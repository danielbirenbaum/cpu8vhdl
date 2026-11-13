-- =============================================================================
-- response_formatter.vhd
-- Converte resultado e indice em ASCII, envia ERR e controla a sequencia TX.
--
-- Autor: Lucas Elbert
--
-- Respostas (CR = 0x0D, LF = 0x0A):
--   M1 / LDI / MOV : "Rn = HH" CR LF                              ( 9 bytes)
--   M2 com flags   : "Rn = HH Z=z C=c N=n V=v" CR LF              (25 bytes)
--   Erro           : "ERR" CR LF                                  ( 5 bytes)
--
-- Handshake com uart_tx (para cada byte):
--   ENVIA     : so com tx_busy = 0, pulsa tx_valid por 1 ciclo (tx_data estavel)
--   BUSY_UP   : espera tx_busy subir
--   BUSY_DOWN : espera tx_busy cair (fim do stop bit)
--   ultimo byte -> FIM: format_done = 1 por 1 ciclo -> ESPERA
--
-- Handshake com cpu_control:
--   aceita uma resposta quando resp_valid = 1, e so aceita outra depois que
--   resp_valid voltar a 0 (evita resposta duplicada).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu_pkg.all;

entity response_formatter is
  generic (
    G_FLAGS_EN : boolean := true    -- false: nunca envia flags (marco M1)
  );
  port (
    clk             : in  std_logic;
    rst             : in  std_logic;   -- reset sincrono, ativo em '1' (rst_s)
    -- do cpu_control
    resp_valid      : in  std_logic;
    resp_err        : in  std_logic;
    resp_show_flags : in  std_logic;
    -- do cpu_datapath (captura estavel da resposta)
    resp_idx        : in  regidx_t;
    resp_data       : in  byte_t;
    resp_flags      : in  std_logic_vector(3 downto 0);  -- Z C N V
    -- da/para uart_tx
    tx_busy         : in  std_logic;
    tx_data         : out byte_t;
    tx_valid        : out std_logic;
    -- para o cpu_control
    format_done     : out std_logic
  );
end entity response_formatter;

architecture rtl of response_formatter is

  type state_t is (ST_ESPERA, ST_ENVIA, ST_BUSY_UP, ST_BUSY_DOWN, ST_FIM);
  signal state : state_t := ST_ESPERA;

  constant LAST_ERR   : integer := 4;    -- "ERR" CR LF
  constant LAST_BASIC : integer := 8;    -- "Rn = HH" CR LF
  constant LAST_FLAGS : integer := 24;   -- "Rn = HH Z=z C=c N=n V=v" CR LF

  signal k     : integer range 0 to LAST_FLAGS := 0;   -- contador de byte
  signal last  : integer range 0 to LAST_FLAGS := 0;
  signal armed : std_logic := '1';                     -- resp_valid ja voltou a 0

  -- copia estavel da resposta
  signal err_l   : std_logic := '0';
  signal flags_l : std_logic := '0';
  signal idx_l   : regidx_t := "000";
  signal data_l  : byte_t   := x"00";
  signal flg_l   : std_logic_vector(3 downto 0) := "0000";

  signal tx_valid_r : std_logic := '0';
  signal char       : byte_t;

begin

  -- ---------------------------------------------------------------------------
  -- FSM de envio
  -- ---------------------------------------------------------------------------
  process (clk)
  begin
    if rising_edge(clk) then
      tx_valid_r <= '0';

      if rst = '1' then
        state   <= ST_ESPERA;
        k       <= 0;
        last    <= 0;
        armed   <= '1';
        err_l   <= '0';
        flags_l <= '0';
        idx_l   <= "000";
        data_l  <= x"00";
        flg_l   <= "0000";
      else
        if resp_valid = '0' then
          armed <= '1';
        end if;

        case state is
          when ST_ESPERA =>
            if resp_valid = '1' and armed = '1' then
              armed  <= '0';
              err_l  <= resp_err;
              idx_l  <= resp_idx;
              data_l <= resp_data;
              flg_l  <= resp_flags;
              k      <= 0;
              if resp_err = '1' then
                flags_l <= '0';
                last    <= LAST_ERR;
              elsif G_FLAGS_EN and resp_show_flags = '1' then
                flags_l <= '1';
                last    <= LAST_FLAGS;
              else
                flags_l <= '0';
                last    <= LAST_BASIC;
              end if;
              state <= ST_ENVIA;
            end if;

          when ST_ENVIA =>
            if tx_busy = '0' then
              tx_valid_r <= '1';            -- alto durante 1 ciclo
              state      <= ST_BUSY_UP;
            end if;

          when ST_BUSY_UP =>
            if tx_busy = '1' then
              state <= ST_BUSY_DOWN;
            end if;

          when ST_BUSY_DOWN =>
            if tx_busy = '0' then
              if k = last then
                state <= ST_FIM;
              else
                k     <= k + 1;
                state <= ST_ENVIA;
              end if;
            end if;

          when ST_FIM =>
            state <= ST_ESPERA;
        end case;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- MUX de caracteres: byte k da resposta
  -- ---------------------------------------------------------------------------
  process (k, err_l, flags_l, idx_l, data_l, flg_l)
  begin
    char <= ASCII_LF;
    if err_l = '1' then
      case k is
        when 0      => char <= to_byte('E');
        when 1      => char <= to_byte('R');
        when 2      => char <= to_byte('R');
        when 3      => char <= ASCII_CR;
        when others => char <= ASCII_LF;
      end case;
    else
      case k is
        when 0 => char <= to_byte('R');
        when 1 => char <= hex_ascii('0' & idx_l);
        when 2 => char <= ASCII_SPACE;
        when 3 => char <= ASCII_EQUAL;
        when 4 => char <= ASCII_SPACE;
        when 5 => char <= hex_ascii(data_l(7 downto 4));
        when 6 => char <= hex_ascii(data_l(3 downto 0));
        when others =>
          if flags_l = '0' then
            if k = 7 then
              char <= ASCII_CR;
            else
              char <= ASCII_LF;
            end if;
          else
            case k is
              when 7  => char <= ASCII_SPACE;
              when 8  => char <= to_byte('Z');
              when 9  => char <= ASCII_EQUAL;
              when 10 => char <= bit_ascii(flg_l(FLAG_Z));
              when 11 => char <= ASCII_SPACE;
              when 12 => char <= to_byte('C');
              when 13 => char <= ASCII_EQUAL;
              when 14 => char <= bit_ascii(flg_l(FLAG_C));
              when 15 => char <= ASCII_SPACE;
              when 16 => char <= to_byte('N');
              when 17 => char <= ASCII_EQUAL;
              when 18 => char <= bit_ascii(flg_l(FLAG_N));
              when 19 => char <= ASCII_SPACE;
              when 20 => char <= to_byte('V');
              when 21 => char <= ASCII_EQUAL;
              when 22 => char <= bit_ascii(flg_l(FLAG_V));
              when 23 => char <= ASCII_CR;
              when others => char <= ASCII_LF;
            end case;
          end if;
      end case;
    end if;
  end process;

  tx_data     <= char;
  tx_valid    <= tx_valid_r;
  format_done <= '1' when state = ST_FIM else '0';

end architecture rtl;
