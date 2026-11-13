
# Entity: baud_gen 
- **File**: baud_gen.vhd

## Diagram
![Diagram](baud_gen.svg "Diagram")
## Generics

| Generic name | Type    | Value      | Description |
| ------------ | ------- | ---------- | ----------- |
| CLK_HZ       | integer | 50_000_000 |             |
| BAUD         | integer | 115_200    |             |

## Ports

| Port name | Direction | Type      | Description |
| --------- | --------- | --------- | ----------- |
| clk       | in        | std_logic |             |
| rst_s     | in        | std_logic |             |
| tick_16x  | out       | std_logic |             |
| tick_bit  | out       | std_logic |             |

## Signals

| Name        | Type                                     | Description |
| ----------- | ---------------------------------------- | ----------- |
| r_count_16x | integer range 0 to CLKS_PER_TICK_16X - 1 |             |
| r_count_bit | integer range 0 to 15                    |             |
| r_tick_16x  | std_logic                                |             |
| r_tick_bit  | std_logic                                |             |

## Constants

| Name              | Type    | Value                | Description |
| ----------------- | ------- | -------------------- | ----------- |
| CLKS_PER_TICK_16X | integer | CLK_HZ / (16 * BAUD) |             |

## Processes
- p_gen: ( clk )
