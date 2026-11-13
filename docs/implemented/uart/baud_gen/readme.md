
# Entity: baud_gen 
- **File**: baud_gen.vhd

## Diagram
![Diagram](baud_gen.svg "Diagram")
## Generics

| Generic name | Type     | Value      | Description |
| ------------ | -------- | ---------- | ----------- |
| CLK_HZ       | positive | 50_000_000 |             |
| BAUD         | positive | 115_200    |             |
| ACC_W        | positive | 16         |             |

## Ports

| Port name | Direction | Type      | Description |
| --------- | --------- | --------- | ----------- |
| clk       | in        | std_logic |             |
| rst       | in        | std_logic |             |
| tick_16x  | out       | std_logic |             |
| tick_bit  | out       | std_logic |             |

## Signals

| Name  | Type                         | Description |
| ----- | ---------------------------- | ----------- |
| acc   | unsigned(ACC_W - 1 downto 0) |             |
| sum   | unsigned(ACC_W downto 0)     |             |
| t16   | std_logic                    |             |
| cnt16 | unsigned(3 downto 0)         |             |

## Constants

| Name | Type    | Value                                                             | Description |
| ---- | ------- | ----------------------------------------------------------------- | ----------- |
| INC  | natural | integer(round(real(BAUD) * 16.0 * (2.0 ** ACC_W) / real(CLK_HZ))) |             |

## Processes
- unnamed: ( clk )
