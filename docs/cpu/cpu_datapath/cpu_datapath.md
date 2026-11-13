
# Entity: cpu_datapath 
- **File**: cpu_datapath.vhd

## Diagram
![Diagram](cpu_datapath.svg "Diagram")
## Ports

| Port name  | Direction | Type                         | Description |
| ---------- | --------- | ---------------------------- | ----------- |
| clk        | in        | std_logic                    |             |
| rst        | in        | std_logic                    |             |
| ra         | in        | regidx_t                     |             |
| rb         | in        | regidx_t                     |             |
| rd         | in        | regidx_t                     |             |
| imm        | in        | byte_t                       |             |
| reg_we     | in        | std_logic                    |             |
| result_ld  | in        | std_logic                    |             |
| flags_we   | in        | std_logic                    |             |
| alu_op     | in        | aluop_t                      |             |
| sel_b      | in        | std_logic                    |             |
| sel_res    | in        | std_logic_vector(1 downto 0) |             |
| resp_data  | out       | byte_t                       |             |
| resp_idx   | out       | regidx_t                     |             |
| resp_flags | out       | std_logic_vector(3 downto 0) |             |

## Signals

| Name       | Type                         | Description |
| ---------- | ---------------------------- | ----------- |
| rd_a       | byte_t                       |             |
| rd_b       | byte_t                       |             |
| op_b       | byte_t                       |             |
| alu_result | byte_t                       |             |
| alu_z      | std_logic                    |             |
| alu_c      | std_logic                    |             |
| alu_n      | std_logic                    |             |
| alu_v      | std_logic                    |             |
| wr_data    | byte_t                       |             |
| flags_r    | std_logic_vector(3 downto 0) |             |
| data_r     | byte_t                       |             |
| idx_r      | regidx_t                     |             |

## Processes
- unnamed: ( clk )

## Instantiations

- u_regs: work.reg_file
- u_alu: work.alu
