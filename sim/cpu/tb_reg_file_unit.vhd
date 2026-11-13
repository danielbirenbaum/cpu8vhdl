-- Testbench do banco de registradores R0..R7.
-- Testa reset sincrono, escrita habilitada, escrita desabilitada e duas leituras.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_reg_file_unit is
end entity tb_reg_file_unit;

architecture test of tb_reg_file_unit is
    signal clk       : std_logic := '0';
    signal rst       : std_logic := '0';
    signal we        : std_logic := '0';
    signal wr_addr   : std_logic_vector(2 downto 0) := "000";
    signal wr_data   : std_logic_vector(7 downto 0) := x"00";
    signal rd_addr_a : std_logic_vector(2 downto 0) := "000";
    signal rd_addr_b : std_logic_vector(2 downto 0) := "000";
    signal rd_data_a : std_logic_vector(7 downto 0);
    signal rd_data_b : std_logic_vector(7 downto 0);
begin
    -- Clock de periodo 10 ns.
    clk <= not clk after 5 ns;

    dut : entity work.reg_file
        port map (
            clk       => clk,
            rst       => rst,
            we        => we,
            wr_addr   => wr_addr,
            wr_data   => wr_data,
            rd_addr_a => rd_addr_a,
            rd_addr_b => rd_addr_b,
            rd_data_a => rd_data_a,
            rd_data_b => rd_data_b
        );

    stimulus : process
        variable expected : std_logic_vector(7 downto 0);
    begin
        -- Reset sincrono: so deve agir na borda de subida.
        rst <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert rd_data_a = x"00" and rd_data_b = x"00"
            report "Falha: reset nao zerou o banco" severity failure;
        report "PASS: reset inicial" severity note;
        rst <= '0';

        -- Escreve um valor diferente em cada um dos oito registradores.
        we <= '1';
        for i in 0 to 7 loop
            wr_addr <= std_logic_vector(to_unsigned(i, 3));
            wr_data <= std_logic_vector(to_unsigned(i * 17 + 3, 8));
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;
        we <= '0';

        -- Verifica os oito registradores usando as duas portas de leitura.
        for i in 0 to 7 loop
            rd_addr_a <= std_logic_vector(to_unsigned(i, 3));
            rd_addr_b <= std_logic_vector(to_unsigned(7 - i, 3));
            wait for 1 ns;
            expected := std_logic_vector(to_unsigned(i * 17 + 3, 8));
            assert rd_data_a = expected
                report "Falha na leitura A do registrador " & integer'image(i)
                severity failure;
            expected := std_logic_vector(to_unsigned((7 - i) * 17 + 3, 8));
            assert rd_data_b = expected
                report "Falha na leitura B do registrador " & integer'image(7 - i)
                severity failure;
        end loop;
        report "PASS: escrita e leitura dos oito registradores" severity note;

        -- Com we=0, a tentativa de escrita deve ser ignorada.
        wr_addr <= "011";
        wr_data <= x"FF";
        we <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        rd_addr_a <= "011";
        wait for 1 ns;
        assert rd_data_a = x"36"
            report "Falha: banco escreveu mesmo com we=0" severity failure;
        report "PASS: escrita desabilitada" severity note;

        -- Sobrescreve R3 quando we=1.
        wr_addr <= "011";
        wr_data <= x"A5";
        we <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        we <= '0';
        rd_addr_a <= "011";
        wait for 1 ns;
        assert rd_data_a = x"A5"
            report "Falha: nao foi possivel sobrescrever R3" severity failure;
        report "PASS: sobrescrita de registrador" severity note;

        -- Um novo reset deve limpar todos os registradores.
        rst <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        rst <= '0';
        for i in 0 to 7 loop
            rd_addr_a <= std_logic_vector(to_unsigned(i, 3));
            rd_addr_b <= std_logic_vector(to_unsigned(i, 3));
            wait for 1 ns;
            assert rd_data_a = x"00" and rd_data_b = x"00"
                report "Falha: reset nao limpou R" & integer'image(i)
                severity failure;
        end loop;
        report "PASS: reset dos oito registradores" severity note;

        report "Todos os testes do banco de registradores passaram." severity note;
        stop;
        wait;
    end process;
end architecture test;
