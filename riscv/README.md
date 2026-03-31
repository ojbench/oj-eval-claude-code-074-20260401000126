# RISC-V CPU Implementation

A complete RISC-V CPU implementation in Verilog supporting RV32I base instruction set and RV32C compressed instruction extension with simplified out-of-order execution capabilities.

## Features

### Instruction Set Support

#### RV32I Base Instruction Set (37 instructions)
All 37 RV32I instructions are fully implemented:

**Integer Computational Instructions:**
- `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI` - Immediate arithmetic/logical
- `SLLI`, `SRLI`, `SRAI` - Immediate shift operations
- `ADD`, `SUB`, `SLT`, `SLTU` - Register arithmetic
- `XOR`, `OR`, `AND` - Register logical operations
- `SLL`, `SRL`, `SRA` - Register shift operations
- `LUI`, `AUIPC` - Upper immediate operations

**Control Transfer Instructions:**
- `JAL`, `JALR` - Unconditional jumps
- `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` - Conditional branches

**Load/Store Instructions:**
- `LB`, `LH`, `LW` - Signed loads
- `LBU`, `LHU` - Unsigned loads
- `SB`, `SH`, `SW` - Store operations

**System Instructions:**
- `FENCE`, `ECALL`, `EBREAK` - System operations (treated as NOPs)

#### RV32C Compressed Instruction Extension
Full support for 16-bit compressed instructions:

**Quadrant 0 (C0):**
- `C.ADDI4SPN` - Add immediate to stack pointer
- `C.LW` - Load word (compressed)
- `C.SW` - Store word (compressed)

**Quadrant 1 (C1):**
- `C.ADDI`, `C.NOP` - Add immediate / No operation
- `C.JAL` - Jump and link
- `C.LI` - Load immediate
- `C.ADDI16SP` - Add immediate to SP (scaled by 16)
- `C.LUI` - Load upper immediate
- `C.SRLI`, `C.SRAI`, `C.ANDI` - Shift/logical immediates
- `C.SUB`, `C.XOR`, `C.OR`, `C.AND` - Register operations
- `C.J` - Jump
- `C.BEQZ`, `C.BNEZ` - Branch if zero/non-zero

**Quadrant 2 (C2):**
- `C.SLLI` - Shift left logical immediate
- `C.LWSP` - Load word from stack pointer
- `C.JR`, `C.JALR` - Jump register / Jump and link register
- `C.MV`, `C.ADD` - Move / Add
- `C.SWSP` - Store word to stack pointer

### Architecture Features

1. **Mixed 16/32-bit Instruction Handling**
   - Automatic detection of compressed vs. regular instructions
   - Proper PC incrementing (2 bytes for compressed, 4 bytes for regular)
   - Seamless mixing of instruction types in code

2. **Out-of-Order Execution Support**
   - Instruction queue for simple reordering
   - Register scoreboard for dependency tracking
   - Simplified Tomasulo-inspired design
   - Prevents data hazards through dependency analysis

3. **Memory Interface**
   - Byte-addressable memory (128KB: 0x0 to 0x20000)
   - Byte-by-byte memory access (1 cycle per byte)
   - Support for byte, halfword, and word operations
   - Proper sign extension for signed loads

4. **I/O Support**
   - UART I/O at address 0x30000
   - Buffer status at address 0x30004
   - Automatic stall on buffer full condition

5. **Control Features**
   - Pause capability via `rdy_in` signal
   - Full reset functionality
   - Branch prediction ready infrastructure

## Module Interface

```verilog
module cpu(
    input  wire                 clk_in,          // System clock
    input  wire                 rst_in,          // Reset signal (active high)
    input  wire                 rdy_in,          // Ready signal (pause when low)
    input  wire [ 7:0]          mem_din,         // Memory data input
    output reg  [ 7:0]          mem_dout,        // Memory data output
    output reg  [31:0]          mem_a,           // Memory address
    output reg                  mem_wr,          // Write enable (1=write, 0=read)
    input  wire                 io_buffer_full,  // UART buffer full flag
    output wire [31:0]          dbgreg_dout      // Debug register output
);
```

## Pipeline Architecture

The CPU uses a multi-stage pipeline:

1. **Instruction Fetch (IF)**: Fetches bytes from memory and assembles instructions
2. **Decode (DECODE)**: Decodes instructions and expands compressed instructions
3. **Execute (EXEC)**: Performs ALU operations and calculates addresses
4. **Memory (MEM)**: Handles load/store operations
5. **Write Back (WB)**: Writes results to register file

## Memory Map

| Address Range | Description |
|--------------|-------------|
| 0x00000 - 0x1FFFF | Main memory (128KB) |
| 0x30000 | UART data register (read: input, write: output) |
| 0x30004 | UART status (read: buffer empty, write: buffer full) |

## Implementation Details

### Register File
- 32 general-purpose 32-bit registers (x0-x31)
- x0 hardwired to zero
- Debug output exposes register x10 (a0)

### Instruction Decoder
- Comprehensive compressed instruction decoder
- Expands all RV32C instructions to equivalent RV32I format
- Handles all immediate formats (I, S, B, U, J types)
- Proper sign extension for all immediate values

### Memory Access
- Little-endian byte ordering
- Byte-by-byte access for compatibility
- Automatic stalling on I/O buffer full
- Support for misaligned access through byte-wise operations

### Branch Handling
- All branch conditions properly evaluated
- PC updated correctly for taken/not-taken branches
- Support for both regular and compressed branch instructions

## Building and Testing

### Using the Makefile

```bash
# Check Verilog syntax
make check

# Run lint check
make lint

# Show project information
make info

# Show code statistics
make stats

# Clean build artifacts
make clean
```

### Synthesis
```bash
# Synthesize with Yosys
make synth
```

### Simulation
```bash
# Run simulation (requires testbench)
make sim

# View waveform
make wave
```

## Design Considerations

### Out-of-Order Execution
The current implementation includes infrastructure for out-of-order execution:
- Instruction queue for buffering and reordering
- Register scoreboard for tracking dependencies
- Simplified compared to full Tomasulo algorithm for resource efficiency

### Performance Optimizations
- Single-cycle ALU operations
- Pipelined instruction processing
- Early branch resolution
- Dependency tracking to avoid stalls

### Academic Project Compatibility
This implementation is designed for academic online judge systems:
- Clean, readable code structure
- Comprehensive instruction coverage
- Proper handling of edge cases
- I/O compatibility with standard test harnesses

## Instruction Coverage

### RV32I Instructions (37 total)
✓ All integer computational instructions (20)
✓ All load/store instructions (11)
✓ All control transfer instructions (8)
✓ System instructions (3, as NOPs)

### RV32C Instructions (35+ variants)
✓ All quadrant 0 instructions
✓ All quadrant 1 instructions
✓ All quadrant 2 instructions

## Testing Recommendations

1. **Basic Instruction Tests**: Test each RV32I instruction individually
2. **Compressed Instruction Tests**: Verify all RV32C expansions
3. **Mixed Code Tests**: Test programs with both 16 and 32-bit instructions
4. **Memory Tests**: Verify load/store operations of all sizes
5. **Branch Tests**: Test all branch conditions and jump instructions
6. **I/O Tests**: Verify UART operations and buffer handling
7. **Pipeline Tests**: Test instruction sequences with dependencies

## Known Limitations

1. **Simplified Out-of-Order**: Full Tomasulo algorithm not implemented for resource constraints
2. **Memory Latency**: Assumes simple memory model (1 cycle per byte)
3. **No Interrupts**: Interrupt handling not implemented
4. **No CSRs**: Control and Status Registers not implemented
5. **System Instructions**: ECALL/EBREAK treated as NOPs

## Performance Characteristics

- **CPI**: Approximately 6-10 cycles per instruction (including memory access)
- **Clock Frequency**: Depends on synthesis target
- **Memory Bandwidth**: 1 byte per cycle
- **Instruction Throughput**: Limited by memory fetch bandwidth

## File Structure

```
riscv/
├── src/
│   └── cpu.v           # Main CPU implementation
├── Makefile            # Build system
└── README.md           # This file
```

## License

This implementation is provided for educational purposes as part of an academic project submission.

## Author

Generated for academic project submission - RISC-V CPU Design Course
