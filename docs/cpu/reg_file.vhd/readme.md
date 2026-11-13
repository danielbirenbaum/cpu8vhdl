
# Entity: reg_file 
- **File**: reg_file.vhd

## Diagram
![Diagram](reg_file.svg "Diagram")
## Ports

| Port name | Direction | Type                         | Description |
| --------- | --------- | ---------------------------- | ----------- |
| clk       | in        | std_logic                    |             |
| rst       | in        | std_logic                    |             |
| we        | in        | std_logic                    |             |
| wr_addr   | in        | std_logic_vector(2 downto 0) |             |
| wr_data   | in        | std_logic_vector(7 downto 0) |             |
| rd_addr_a | in        | std_logic_vector(2 downto 0) |             |
| rd_addr_b | in        | std_logic_vector(2 downto 0) |             |
| rd_data_a | out       | std_logic_vector(7 downto 0) |             |
| rd_data_b | out       | std_logic_vector(7 downto 0) |             |

## Signals

| Name | Type   | Description |
| ---- | ------ | ----------- |
| regs | regs_t |             |

## Types

| Name   | Type | Description |
| ------ | ---- | ----------- |
| regs_t |      |             |

## Processes
- unnamed: ( clk )
