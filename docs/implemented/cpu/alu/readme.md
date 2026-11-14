
# Entity: alu 
- **File**: alu.vhd

## Diagram
![Diagram](alu.svg "Diagram")
## Ports

| Port name | Direction | Type      | Description |
| --------- | --------- | --------- | ----------- |
| a         | in        | byte_t    |             |
| b         | in        | byte_t    |             |
| op        | in        | aluop_t   |             |
| resultado | out       | byte_t    |             |
| z         | out       | std_logic |             |
| c         | out       | std_logic |             |
| n         | out       | std_logic |             |
| v         | out       | std_logic |             |

## Processes
- unnamed: ( a, b, op )
