library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity reg_file is
  port (
    clk     : in  std_logic;
    rst     : in  std_logic;                   
    we      : in  std_logic;                 
    wr_addr : in  std_logic_vector(2 downto 0);  
    wr_data : in  std_logic_vector(7 downto 0);
    rd_addr_a : in  std_logic_vector(2 downto 0);  
    rd_addr_b : in  std_logic_vector(2 downto 0); 
    rd_data_a : out std_logic_vector(7 downto 0);
    rd_data_b : out std_logic_vector(7 downto 0)
  );
end entity reg_file;

architecture rtl of reg_file is
  type regs_t is array (0 to 7) of std_logic_vector(7 downto 0);
  signal regs : regs_t := (others => (others => '0'));
begin

  process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        regs <= (others => (others => '0'));
      elsif we = '1' then
        regs(to_integer(unsigned(wr_addr))) <= wr_data;
      end if;
    end if;
  end process;

  -- leituras por MUX (sem three-state)
  rd_data_a <= regs(to_integer(unsigned(rd_addr_a)));
  rd_data_b <= regs(to_integer(unsigned(rd_addr_b)));

end architecture rtl;
