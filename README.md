# MCore32
FPGA-based MCU/SoC

## File Structure
`rtl/`
- `alu.sv`              -- combinational, operand_a/b + op -> result
- `regfile.sv`          -- 32x32-bit registers, x0 hardwired zero
- `decoder.sv`          -- instruction -> opcode/funct/rd/rs1/rs2/imm
- `pc.sv`               -- program counter register + next-PC mux
- `cpu_core.sv`         -- wires the above together
- `imem.sv `            -- instruction memory (BRAM, initialized from hex)
- `dmem.sv`             -- data memory (BRAM)
- `top.sv`              -- top-level, connects cpu_core + imem + dmem + board I/O

`sim/`
- `alu_tb.sv`
- `regfile_tb.sv`
- `cpu_core_tb.sv`
- `test_program.hex`    -- hand-assembled test instructions