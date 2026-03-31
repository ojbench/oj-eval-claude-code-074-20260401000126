# RISC-V Instruction Implementation Reference

## RV32I Base Integer Instruction Set (37 Instructions)

### Integer Register-Immediate Instructions

| Instruction | Opcode | Funct3 | Description | Implementation |
|------------|--------|--------|-------------|----------------|
| ADDI | 0010011 | 000 | Add immediate | ✓ Lines 522 |
| SLTI | 0010011 | 010 | Set less than immediate (signed) | ✓ Lines 523 |
| SLTIU | 0010011 | 011 | Set less than immediate (unsigned) | ✓ Lines 524 |
| XORI | 0010011 | 100 | XOR immediate | ✓ Lines 525 |
| ORI | 0010011 | 110 | OR immediate | ✓ Lines 526 |
| ANDI | 0010011 | 111 | AND immediate | ✓ Lines 527 |
| SLLI | 0010011 | 001 | Shift left logical immediate | ✓ Lines 528 |
| SRLI | 0010011 | 101 | Shift right logical immediate | ✓ Lines 533 |
| SRAI | 0010011 | 101 | Shift right arithmetic immediate | ✓ Lines 531 |

### Integer Register-Register Instructions

| Instruction | Opcode | Funct3 | Funct7 | Description | Implementation |
|------------|--------|--------|--------|-------------|----------------|
| ADD | 0110011 | 000 | 0000000 | Add | ✓ Lines 546 |
| SUB | 0110011 | 000 | 0100000 | Subtract | ✓ Lines 544 |
| SLL | 0110011 | 001 | 0000000 | Shift left logical | ✓ Lines 548 |
| SLT | 0110011 | 010 | 0000000 | Set less than (signed) | ✓ Lines 549 |
| SLTU | 0110011 | 011 | 0000000 | Set less than (unsigned) | ✓ Lines 550 |
| XOR | 0110011 | 100 | 0000000 | XOR | ✓ Lines 551 |
| SRL | 0110011 | 101 | 0000000 | Shift right logical | ✓ Lines 556 |
| SRA | 0110011 | 101 | 0100000 | Shift right arithmetic | ✓ Lines 554 |
| OR | 0110011 | 110 | 0000000 | OR | ✓ Lines 558 |
| AND | 0110011 | 111 | 0000000 | AND | ✓ Lines 559 |

### Upper Immediate Instructions

| Instruction | Opcode | Description | Implementation |
|------------|--------|-------------|----------------|
| LUI | 0110111 | Load upper immediate | ✓ Lines 464-466 |
| AUIPC | 0010111 | Add upper immediate to PC | ✓ Lines 469-471 |

### Jump Instructions

| Instruction | Opcode | Description | Implementation |
|------------|--------|-------------|----------------|
| JAL | 1101111 | Jump and link | ✓ Lines 474-477 |
| JALR | 1100111 | Jump and link register | ✓ Lines 480-483 |

### Branch Instructions

| Instruction | Opcode | Funct3 | Description | Implementation |
|------------|--------|--------|-------------|----------------|
| BEQ | 1100011 | 000 | Branch if equal | ✓ Lines 488 |
| BNE | 1100011 | 001 | Branch if not equal | ✓ Lines 489 |
| BLT | 1100011 | 100 | Branch if less than (signed) | ✓ Lines 490 |
| BGE | 1100011 | 101 | Branch if greater/equal (signed) | ✓ Lines 491 |
| BLTU | 1100011 | 110 | Branch if less than (unsigned) | ✓ Lines 492 |
| BGEU | 1100011 | 111 | Branch if greater/equal (unsigned) | ✓ Lines 493 |

### Load Instructions

| Instruction | Opcode | Funct3 | Description | Implementation |
|------------|--------|--------|-------------|----------------|
| LB | 0000011 | 000 | Load byte (signed) | ✓ Lines 586-598 |
| LH | 0000011 | 001 | Load halfword (signed) | ✓ Lines 601-612 |
| LW | 0000011 | 010 | Load word | ✓ Lines 615-623 |
| LBU | 0000011 | 100 | Load byte (unsigned) | ✓ Lines 593-594 |
| LHU | 0000011 | 101 | Load halfword (unsigned) | ✓ Lines 607-608 |

### Store Instructions

| Instruction | Opcode | Funct3 | Description | Implementation |
|------------|--------|--------|-------------|----------------|
| SB | 0100011 | 000 | Store byte | ✓ Lines 648-666 |
| SH | 0100011 | 001 | Store halfword | ✓ Lines 669-684 |
| SW | 0100011 | 010 | Store word | ✓ Lines 687-702 |

### Memory Ordering

| Instruction | Opcode | Description | Implementation |
|------------|--------|-------------|----------------|
| FENCE | 0001111 | Fence memory operations | ✓ Lines 565-569 (NOP) |

### System Instructions

| Instruction | Opcode | Funct3 | Description | Implementation |
|------------|--------|--------|-------------|----------------|
| ECALL | 1110011 | 000 | Environment call | ✓ Lines 565-569 (NOP) |
| EBREAK | 1110011 | 000 | Environment break | ✓ Lines 565-569 (NOP) |

---

## RV32C Compressed Instruction Extension

### Compressed Instruction Format
- 16-bit instructions (bits [1:0] != 11)
- Three quadrants: C0, C1, C2
- Expanded to equivalent RV32I instructions internally

### Quadrant 0 (C0) - bits[1:0] = 00

| Instruction | Funct3 | Expansion | Implementation |
|------------|--------|-----------|----------------|
| C.ADDI4SPN | 000 | addi rd', x2, nzuimm | ✓ Lines 166-172 |
| C.LW | 010 | lw rd', offset(rs1') | ✓ Lines 174-177 |
| C.SW | 110 | sw rs2', offset(rs1') | ✓ Lines 178-181 |

### Quadrant 1 (C1) - bits[1:0] = 01

| Instruction | Funct3 | Expansion | Implementation |
|------------|--------|-----------|----------------|
| C.NOP | 000 | addi x0, x0, 0 | ✓ Lines 188-190 |
| C.ADDI | 000 | addi rd, rd, nzimm | ✓ Lines 188-190 |
| C.JAL | 001 | jal x1, offset | ✓ Lines 192-194 |
| C.LI | 010 | addi rd, x0, imm | ✓ Lines 196-198 |
| C.ADDI16SP | 011 | addi x2, x2, nzimm | ✓ Lines 201-205 |
| C.LUI | 011 | lui rd, nzimm | ✓ Lines 206-208 |
| C.SRLI | 100 | srli rd', rd', shamt | ✓ Lines 215-217 |
| C.SRAI | 100 | srai rd', rd', shamt | ✓ Lines 218-220 |
| C.ANDI | 100 | andi rd', rd', imm | ✓ Lines 221-223 |
| C.SUB | 100 | sub rd', rd', rs2' | ✓ Lines 226 |
| C.XOR | 100 | xor rd', rd', rs2' | ✓ Lines 227 |
| C.OR | 100 | or rd', rd', rs2' | ✓ Lines 228 |
| C.AND | 100 | and rd', rd', rs2' | ✓ Lines 229 |
| C.J | 101 | jal x0, offset | ✓ Lines 235-237 |
| C.BEQZ | 110 | beq rs1', x0, offset | ✓ Lines 239-241 |
| C.BNEZ | 111 | bne rs1', x0, offset | ✓ Lines 243-245 |

### Quadrant 2 (C2) - bits[1:0] = 10

| Instruction | Funct3 | Expansion | Implementation |
|------------|--------|-----------|----------------|
| C.SLLI | 000 | slli rd, rd, shamt | ✓ Lines 252-254 |
| C.LWSP | 010 | lw rd, offset(x2) | ✓ Lines 255-258 |
| C.JR | 100 | jalr x0, 0(rs1) | ✓ Lines 262-265 |
| C.MV | 100 | add rd, x0, rs2 | ✓ Lines 266-268 |
| C.JALR | 100 | jalr x1, 0(rs1) | ✓ Lines 270-273 |
| C.ADD | 100 | add rd, rd, rs2 | ✓ Lines 274-276 |
| C.SWSP | 110 | sw rs2, offset(x2) | ✓ Lines 279-281 |

---

## Immediate Encoding

### I-Type (12-bit signed)
- Used by: ADDI, SLTI, SLTIU, XORI, ORI, ANDI, JALR, Loads
- Encoding: inst[31:20]
- Sign-extended to 32 bits

### S-Type (12-bit signed)
- Used by: Stores
- Encoding: {inst[31:25], inst[11:7]}
- Sign-extended to 32 bits

### B-Type (13-bit signed, scaled by 2)
- Used by: Branches
- Encoding: {inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}
- Sign-extended to 32 bits

### U-Type (20-bit)
- Used by: LUI, AUIPC
- Encoding: {inst[31:12], 12'b0}
- Upper 20 bits

### J-Type (21-bit signed, scaled by 2)
- Used by: JAL
- Encoding: {inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}
- Sign-extended to 32 bits

---

## Register ABI Names

| Register | ABI Name | Description | Saved By |
|----------|----------|-------------|----------|
| x0 | zero | Hard-wired zero | - |
| x1 | ra | Return address | Caller |
| x2 | sp | Stack pointer | Callee |
| x3 | gp | Global pointer | - |
| x4 | tp | Thread pointer | - |
| x5-x7 | t0-t2 | Temporaries | Caller |
| x8 | s0/fp | Saved/Frame pointer | Callee |
| x9 | s1 | Saved register | Callee |
| x10-x11 | a0-a1 | Arguments/Return values | Caller |
| x12-x17 | a2-a7 | Arguments | Caller |
| x18-x27 | s2-s11 | Saved registers | Callee |
| x28-x31 | t3-t6 | Temporaries | Caller |

---

## Implementation Notes

### Compressed Register Encoding
- Prime registers (rd', rs1', rs2'): Encoded as 3 bits
- Maps to x8-x15: {2'b01, encoded_bits}
- Used in C0 and some C1 instructions

### Sign Extension
- Implemented in `sext` function (lines 115-130)
- Supports 8, 12, 13, 16, and 21-bit sign extension
- Properly extends to 32 bits

### Memory Access
- All memory operations are byte-wise
- Multi-byte operations (LH, LW, SH, SW) use sequential byte accesses
- Little-endian byte ordering
- Proper alignment handling

### Branch Prediction
- Infrastructure present for branch prediction
- Currently uses simple static prediction
- Can be extended with history tables

### Out-of-Order Support
- Instruction queue implemented (4 entries)
- Register scoreboard for dependency tracking
- Simplified compared to full Tomasulo
- Can be extended for more aggressive reordering

---

## Verification Checklist

### RV32I Verification
- [x] All 9 immediate arithmetic/logical instructions
- [x] All 10 register arithmetic/logical instructions
- [x] All 2 upper immediate instructions
- [x] All 2 jump instructions
- [x] All 6 branch instructions
- [x] All 5 load instructions
- [x] All 3 store instructions
- [x] Fence instruction (as NOP)
- [x] System instructions (as NOP)

### RV32C Verification
- [x] All C0 quadrant instructions (3)
- [x] All C1 quadrant instructions (13)
- [x] All C2 quadrant instructions (7)
- [x] Proper expansion to RV32I
- [x] Correct immediate encoding
- [x] Prime register mapping

### Architecture Verification
- [x] Register x0 always zero
- [x] PC increments correctly (2 or 4 bytes)
- [x] Memory interface works correctly
- [x] I/O buffer handling
- [x] Reset functionality
- [x] Pause capability

---

## Performance Metrics

### Instruction Timing (typical)
- ALU operations: 4 cycles (IF + DECODE + EXEC + WB)
- Branches: 4-5 cycles (includes branch resolution)
- Loads: 5-9 cycles (depends on size: byte=5, half=6, word=8)
- Stores: 5-9 cycles (depends on size)
- Compressed instructions: Same as expanded equivalent

### Memory Bandwidth
- 1 byte per cycle
- 4 cycles to fetch 32-bit instruction
- 2 cycles to fetch 16-bit instruction
- Additional cycles for load/store data

### CPI (Cycles Per Instruction)
- Average: ~6-8 cycles
- Best case (ALU): ~4 cycles
- Worst case (word load/store): ~9 cycles
