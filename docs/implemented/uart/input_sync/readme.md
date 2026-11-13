
# Entity: input_sync 
- **File**: input_sync.vhd

## Diagram
![Diagram](input_sync.svg "Diagram")
## Ports

| Port name | Direction | Type      | Description |
| --------- | --------- | --------- | ----------- |
| clk       | in        | std_logic |             |
| rst_i     | in        | std_logic |             |
| rx_i      | in        | std_logic |             |
| rx_s      | out       | std_logic |             |
| rst_s     | out       | std_logic |             |

## Signals

| Name   | Type                         | Description |
| ------ | ---------------------------- | ----------- |
| rx_ff  | std_logic_vector(1 downto 0) |             |
| rst_ff | std_logic_vector(1 downto 0) |             |

## Processes
- unnamed: ( clk, rst_i )
- unnamed: ( clk )
