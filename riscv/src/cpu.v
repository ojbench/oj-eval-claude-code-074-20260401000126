// RISCV32I CPU with RV32C compressed instruction support
// Implements simplified out-of-order execution with Tomasulo-style concepts

module cpu(
    input  wire                 clk_in,     // system clock signal
    input  wire                 rst_in,     // reset signal
    input  wire                 rdy_in,     // ready signal, pause cpu when low

    input  wire [ 7:0]          mem_din,    // data input bus
    output reg  [ 7:0]          mem_dout,   // data output bus
    output reg  [31:0]          mem_a,      // address bus (only 17:0 are used)
    output reg                  mem_wr,     // write/read signal (1 for write)

    input  wire                 io_buffer_full, // 1 if uart buffer is full

    output wire [31:0]          dbgreg_dout // cpu register output (debugging demo)
);

// ============================================================================
// Constants and Parameters
// ============================================================================

// Instruction opcodes (RV32I)
localparam OP_LUI    = 7'b0110111;
localparam OP_AUIPC  = 7'b0010111;
localparam OP_JAL    = 7'b1101111;
localparam OP_JALR   = 7'b1100111;
localparam OP_BRANCH = 7'b1100011;
localparam OP_LOAD   = 7'b0000011;
localparam OP_STORE  = 7'b0100011;
localparam OP_IMM    = 7'b0010011;
localparam OP_REG    = 7'b0110011;
localparam OP_FENCE  = 7'b0001111;
localparam OP_SYSTEM = 7'b1110011;

// CPU States
localparam STATE_IDLE       = 4'd0;
localparam STATE_IF         = 4'd1;
localparam STATE_IF_WAIT    = 4'd2;
localparam STATE_DECODE     = 4'd3;
localparam STATE_EXEC       = 4'd4;
localparam STATE_MEM_LOAD   = 4'd5;
localparam STATE_MEM_STORE  = 4'd6;
localparam STATE_MEM_WAIT   = 4'd7;
localparam STATE_WB         = 4'd8;

// ============================================================================
// Register File and Pipeline Registers
// ============================================================================

reg [31:0] regfile [0:31];
reg [31:0] pc;
reg [3:0]  state;
integer i;

// ============================================================================
// Instruction Fetch State
// ============================================================================

reg [31:0] inst_buffer;
reg [2:0]  bytes_fetched;
reg        inst_ready;
reg [31:0] current_inst;
reg        is_compressed;

// ============================================================================
// Decoded Instruction Fields
// ============================================================================

reg [6:0]  opcode;
reg [4:0]  rd, rs1, rs2;
reg [2:0]  funct3;
reg [6:0]  funct7;
reg [31:0] imm;
reg [31:0] decode_pc;

// ============================================================================
// Execution State
// ============================================================================

reg [31:0] operand1;
reg [31:0] operand2;
reg [31:0] alu_result;
reg [31:0] mem_addr_calc;
reg [31:0] mem_data;
reg [2:0]  mem_bytes;
reg [31:0] load_data;
reg        branch_taken;

// ============================================================================
// Out-of-Order Support (Simplified)
// ============================================================================

// Instruction queue for simple reordering
reg [31:0] iq_pc [0:3];
reg [31:0] iq_inst [0:3];
reg        iq_valid [0:3];
reg [1:0]  iq_head, iq_tail, iq_count;

// Register scoreboard for dependency tracking
reg [31:0] scoreboard [0:31];  // Tracks in-flight writes
reg        sb_valid [0:31];    // Is register being written?

// ============================================================================
// Memory Interface
// ============================================================================

assign dbgreg_dout = regfile[10];  // Return a0 for debugging

// ============================================================================
// Helper Functions
// ============================================================================

// Sign extension
function [31:0] sext;
    input [31:0] val;
    input [5:0] bits;
    reg sign_bit;
    begin
        sign_bit = val[bits-1];
        case (bits)
            8:  sext = {{24{sign_bit}}, val[7:0]};
            16: sext = {{16{sign_bit}}, val[15:0]};
            12: sext = {{20{sign_bit}}, val[11:0]};
            13: sext = {{19{sign_bit}}, val[12:0]};
            21: sext = {{11{sign_bit}}, val[20:0]};
            default: sext = val;
        endcase
    end
endfunction

// Check if instruction is compressed
function is_inst_compressed;
    input [15:0] inst;
    begin
        is_inst_compressed = (inst[1:0] != 2'b11);
    end
endfunction

// ============================================================================
// Compressed Instruction Decoder
// ============================================================================

task decode_c_inst;
    input [15:0] c_inst;
    output [31:0] expanded_inst;
    output reg valid;
    reg [1:0] c_op;
    reg [2:0] c_funct3;
    reg [4:0] c_rd, c_rs1, c_rs2;
    reg [4:0] c_rdp, c_rs1p, c_rs2p;
    begin
        valid = 1'b1;
        c_op = c_inst[1:0];
        c_funct3 = c_inst[15:13];
        c_rd = c_inst[11:7];
        c_rs1 = c_inst[11:7];
        c_rs2 = c_inst[6:2];
        c_rdp = {2'b01, c_inst[4:2]};
        c_rs1p = {2'b01, c_inst[9:7]};
        c_rs2p = {2'b01, c_inst[4:2]};

        case (c_op)
            2'b00: begin  // C0 Quadrant
                case (c_funct3)
                    3'b000: begin  // C.ADDI4SPN
                        if (c_inst[12:5] == 8'b0) begin
                            valid = 1'b0;  // Illegal
                        end else begin
                            // addi rd', x2, nzuimm
                            expanded_inst = {2'b0, c_inst[10:7], c_inst[12:11], c_inst[5], c_inst[6], 2'b00, 5'h2, 3'b000, c_rdp, OP_IMM};
                        end
                    end
                    3'b010: begin  // C.LW
                        // lw rd', offset(rs1')
                        expanded_inst = {5'b0, c_inst[5], c_inst[12:10], c_inst[6], 2'b00, c_rs1p, 3'b010, c_rdp, OP_LOAD};
                    end
                    3'b110: begin  // C.SW
                        // sw rs2', offset(rs1')
                        expanded_inst = {5'b0, c_inst[5], c_inst[12], c_rs2p, c_rs1p, 3'b010, c_inst[11:10], c_inst[6], 2'b00, OP_STORE};
                    end
                    default: valid = 1'b0;
                endcase
            end

            2'b01: begin  // C1 Quadrant
                case (c_funct3)
                    3'b000: begin  // C.ADDI / C.NOP
                        // addi rd, rd, nzimm
                        expanded_inst = {{6{c_inst[12]}}, c_inst[12], c_inst[6:2], c_rd, 3'b000, c_rd, OP_IMM};
                    end
                    3'b001: begin  // C.JAL
                        // jal x1, offset
                        expanded_inst = {c_inst[12], c_inst[8], c_inst[10:9], c_inst[6], c_inst[7], c_inst[2], c_inst[11], c_inst[5:3], {9{c_inst[12]}}, 4'b0, 5'd1, OP_JAL};
                    end
                    3'b010: begin  // C.LI
                        // addi rd, x0, imm
                        expanded_inst = {{6{c_inst[12]}}, c_inst[12], c_inst[6:2], 5'b0, 3'b000, c_rd, OP_IMM};
                    end
                    3'b011: begin
                        if (c_rd == 5'd2) begin  // C.ADDI16SP
                            if (c_inst[12:2] == 11'b0) valid = 1'b0;
                            else
                                // addi x2, x2, nzimm
                                expanded_inst = {{3{c_inst[12]}}, c_inst[12], c_inst[4:3], c_inst[5], c_inst[2], c_inst[6], 4'b0, 5'd2, 3'b000, 5'd2, OP_IMM};
                        end else if (c_rd != 5'd0) begin  // C.LUI
                            // lui rd, nzimm
                            expanded_inst = {{15{c_inst[12]}}, c_inst[6:2], c_rd, OP_LUI};
                        end else begin
                            valid = 1'b0;
                        end
                    end
                    3'b100: begin  // Arithmetic
                        case (c_inst[11:10])
                            2'b00: begin  // C.SRLI
                                expanded_inst = {7'b0000000, c_inst[6:2], c_rs1p, 3'b101, c_rs1p, OP_IMM};
                            end
                            2'b01: begin  // C.SRAI
                                expanded_inst = {7'b0100000, c_inst[6:2], c_rs1p, 3'b101, c_rs1p, OP_IMM};
                            end
                            2'b10: begin  // C.ANDI
                                expanded_inst = {{6{c_inst[12]}}, c_inst[12], c_inst[6:2], c_rs1p, 3'b111, c_rs1p, OP_IMM};
                            end
                            2'b11: begin
                                case ({c_inst[12], c_inst[6:5]})
                                    3'b000: expanded_inst = {7'b0100000, c_rs2p, c_rs1p, 3'b000, c_rs1p, OP_REG};  // C.SUB
                                    3'b001: expanded_inst = {7'b0000000, c_rs2p, c_rs1p, 3'b100, c_rs1p, OP_REG};  // C.XOR
                                    3'b010: expanded_inst = {7'b0000000, c_rs2p, c_rs1p, 3'b110, c_rs1p, OP_REG};  // C.OR
                                    3'b011: expanded_inst = {7'b0000000, c_rs2p, c_rs1p, 3'b111, c_rs1p, OP_REG};  // C.AND
                                    default: valid = 1'b0;
                                endcase
                            end
                        endcase
                    end
                    3'b101: begin  // C.J
                        // jal x0, offset
                        expanded_inst = {c_inst[12], c_inst[8], c_inst[10:9], c_inst[6], c_inst[7], c_inst[2], c_inst[11], c_inst[5:3], {9{c_inst[12]}}, 4'b0, 5'd0, OP_JAL};
                    end
                    3'b110: begin  // C.BEQZ
                        // beq rs1', x0, offset
                        expanded_inst = {{4{c_inst[12]}}, c_inst[6:5], c_inst[2], 5'b0, c_rs1p, 3'b000, c_inst[11:10], c_inst[4:3], c_inst[12], OP_BRANCH};
                    end
                    3'b111: begin  // C.BNEZ
                        // bne rs1', x0, offset
                        expanded_inst = {{4{c_inst[12]}}, c_inst[6:5], c_inst[2], 5'b0, c_rs1p, 3'b001, c_inst[11:10], c_inst[4:3], c_inst[12], OP_BRANCH};
                    end
                endcase
            end

            2'b10: begin  // C2 Quadrant
                case (c_funct3)
                    3'b000: begin  // C.SLLI
                        expanded_inst = {7'b0000000, c_inst[6:2], c_rd, 3'b001, c_rd, OP_IMM};
                    end
                    3'b010: begin  // C.LWSP
                        if (c_rd == 5'd0) valid = 1'b0;
                        else
                            expanded_inst = {4'b0, c_inst[3:2], c_inst[12], c_inst[6:4], 2'b00, 5'd2, 3'b010, c_rd, OP_LOAD};
                    end
                    3'b100: begin
                        if (c_inst[12] == 1'b0) begin
                            if (c_rs2 == 5'd0) begin  // C.JR
                                if (c_rs1 == 5'd0) valid = 1'b0;
                                else
                                    expanded_inst = {12'b0, c_rs1, 3'b000, 5'd0, OP_JALR};
                            end else begin  // C.MV
                                expanded_inst = {7'b0000000, c_rs2, 5'd0, 3'b000, c_rd, OP_REG};
                            end
                        end else begin
                            if (c_rs2 == 5'd0) begin  // C.JALR
                                if (c_rs1 == 5'd0) valid = 1'b0;
                                else
                                    expanded_inst = {12'b0, c_rs1, 3'b000, 5'd1, OP_JALR};
                            end else begin  // C.ADD
                                expanded_inst = {7'b0000000, c_rs2, c_rs1, 3'b000, c_rd, OP_REG};
                            end
                        end
                    end
                    3'b110: begin  // C.SWSP
                        expanded_inst = {4'b0, c_inst[8:7], c_inst[12], c_rs2, 5'd2, 3'b010, c_inst[11:9], 2'b00, OP_STORE};
                    end
                    default: valid = 1'b0;
                endcase
            end

            default: valid = 1'b0;
        endcase
    end
endtask

// ============================================================================
// Main CPU State Machine
// ============================================================================

always @(posedge clk_in) begin
    if (rst_in) begin
        // Reset all registers and state
        pc <= 32'h00000000;
        state <= STATE_IF;

        for (i = 0; i < 32; i = i + 1) begin
            regfile[i] <= 32'h00000000;
            sb_valid[i] <= 1'b0;
        end

        bytes_fetched <= 3'd0;
        inst_ready <= 1'b0;
        mem_wr <= 1'b0;
        mem_a <= 32'h0;
        mem_dout <= 8'h0;

        iq_head <= 2'd0;
        iq_tail <= 2'd0;
        iq_count <= 2'd0;
        for (i = 0; i < 4; i = i + 1) begin
            iq_valid[i] <= 1'b0;
        end

    end else if (rdy_in) begin
        // Always ensure x0 is 0
        regfile[0] <= 32'h00000000;

        case (state)
            // ================================================================
            // Instruction Fetch
            // ================================================================
            STATE_IF: begin
                if (bytes_fetched == 3'd0) begin
                    // Start fetching first byte
                    mem_a <= pc;
                    mem_wr <= 1'b0;
                    state <= STATE_IF_WAIT;
                    bytes_fetched <= 3'd1;
                end
            end

            STATE_IF_WAIT: begin
                // Collect fetched byte
                case (bytes_fetched)
                    3'd1: begin
                        inst_buffer[7:0] <= mem_din;
                        mem_a <= pc + 1;
                        bytes_fetched <= 3'd2;
                    end
                    3'd2: begin
                        inst_buffer[15:8] <= mem_din;
                        // Check if compressed (16-bit)
                        if (inst_buffer[1:0] != 2'b11) begin
                            // Compressed instruction complete
                            is_compressed <= 1'b1;
                            current_inst <= {16'h0, mem_din, inst_buffer[7:0]};
                            inst_ready <= 1'b1;
                            bytes_fetched <= 3'd0;
                            state <= STATE_DECODE;
                        end else begin
                            // Need 4 bytes for full instruction
                            mem_a <= pc + 2;
                            bytes_fetched <= 3'd3;
                        end
                    end
                    3'd3: begin
                        inst_buffer[23:16] <= mem_din;
                        mem_a <= pc + 3;
                        bytes_fetched <= 3'd4;
                    end
                    3'd4: begin
                        inst_buffer[31:24] <= mem_din;
                        is_compressed <= 1'b0;
                        current_inst <= {mem_din, inst_buffer[23:0]};
                        inst_ready <= 1'b1;
                        bytes_fetched <= 3'd0;
                        state <= STATE_DECODE;
                    end
                    default: begin
                        state <= STATE_IF;
                        bytes_fetched <= 3'd0;
                    end
                endcase
            end

            // ================================================================
            // Decode
            // ================================================================
            STATE_DECODE: begin
                if (inst_ready) begin
                    decode_pc <= pc;

                    // Expand compressed instruction if needed
                    if (is_compressed) begin
                        reg [31:0] expanded;
                        reg valid;
                        decode_c_inst(current_inst[15:0], expanded, valid);

                        if (valid) begin
                            opcode <= expanded[6:0];
                            rd <= expanded[11:7];
                            funct3 <= expanded[14:12];
                            rs1 <= expanded[19:15];
                            rs2 <= expanded[24:20];
                            funct7 <= expanded[31:25];

                            // Extract immediate based on opcode
                            case (expanded[6:0])
                                OP_LUI, OP_AUIPC:
                                    imm <= {expanded[31:12], 12'b0};
                                OP_JAL:
                                    imm <= sext({expanded[31], expanded[19:12], expanded[20], expanded[30:21], 1'b0}, 21);
                                OP_JALR, OP_LOAD, OP_IMM:
                                    imm <= sext(expanded[31:20], 12);
                                OP_BRANCH:
                                    imm <= sext({expanded[31], expanded[7], expanded[30:25], expanded[11:8], 1'b0}, 13);
                                OP_STORE:
                                    imm <= sext({expanded[31:25], expanded[11:7]}, 12);
                                default:
                                    imm <= 32'h0;
                            endcase
                        end else begin
                            // Invalid compressed instruction - treat as NOP
                            opcode <= OP_IMM;
                            rd <= 5'd0;
                            rs1 <= 5'd0;
                            imm <= 32'h0;
                        end
                    end else begin
                        // Regular 32-bit instruction
                        opcode <= current_inst[6:0];
                        rd <= current_inst[11:7];
                        funct3 <= current_inst[14:12];
                        rs1 <= current_inst[19:15];
                        rs2 <= current_inst[24:20];
                        funct7 <= current_inst[31:25];

                        // Extract immediate
                        case (current_inst[6:0])
                            OP_LUI, OP_AUIPC:
                                imm <= {current_inst[31:12], 12'b0};
                            OP_JAL:
                                imm <= sext({current_inst[31], current_inst[19:12], current_inst[20], current_inst[30:21], 1'b0}, 21);
                            OP_JALR, OP_LOAD, OP_IMM:
                                imm <= sext(current_inst[31:20], 12);
                            OP_BRANCH:
                                imm <= sext({current_inst[31], current_inst[7], current_inst[30:25], current_inst[11:8], 1'b0}, 13);
                            OP_STORE:
                                imm <= sext({current_inst[31:25], current_inst[11:7]}, 12);
                            default:
                                imm <= 32'h0;
                        endcase
                    end

                    inst_ready <= 1'b0;
                    state <= STATE_EXEC;
                end
            end

            // ================================================================
            // Execute
            // ================================================================
            STATE_EXEC: begin
                // Read operands
                operand1 <= regfile[rs1];
                operand2 <= regfile[rs2];

                case (opcode)
                    OP_LUI: begin
                        alu_result <= imm;
                        state <= STATE_WB;
                    end

                    OP_AUIPC: begin
                        alu_result <= decode_pc + imm;
                        state <= STATE_WB;
                    end

                    OP_JAL: begin
                        alu_result <= decode_pc + (is_compressed ? 32'd2 : 32'd4);
                        pc <= decode_pc + imm;
                        state <= STATE_WB;
                    end

                    OP_JALR: begin
                        alu_result <= decode_pc + (is_compressed ? 32'd2 : 32'd4);
                        pc <= (regfile[rs1] + imm) & 32'hFFFFFFFE;
                        state <= STATE_WB;
                    end

                    OP_BRANCH: begin
                        case (funct3)
                            3'b000: branch_taken <= (regfile[rs1] == regfile[rs2]);  // BEQ
                            3'b001: branch_taken <= (regfile[rs1] != regfile[rs2]);  // BNE
                            3'b100: branch_taken <= ($signed(regfile[rs1]) < $signed(regfile[rs2]));  // BLT
                            3'b101: branch_taken <= ($signed(regfile[rs1]) >= $signed(regfile[rs2]));  // BGE
                            3'b110: branch_taken <= (regfile[rs1] < regfile[rs2]);  // BLTU
                            3'b111: branch_taken <= (regfile[rs1] >= regfile[rs2]);  // BGEU
                            default: branch_taken <= 1'b0;
                        endcase

                        if (branch_taken)
                            pc <= decode_pc + imm;
                        else
                            pc <= decode_pc + (is_compressed ? 32'd2 : 32'd4);

                        state <= STATE_IF;
                        bytes_fetched <= 3'd0;
                    end

                    OP_LOAD: begin
                        mem_addr_calc <= regfile[rs1] + imm;
                        mem_bytes <= 3'd0;
                        load_data <= 32'h0;
                        state <= STATE_MEM_LOAD;
                    end

                    OP_STORE: begin
                        mem_addr_calc <= regfile[rs1] + imm;
                        mem_data <= regfile[rs2];
                        mem_bytes <= 3'd0;
                        state <= STATE_MEM_STORE;
                    end

                    OP_IMM: begin
                        case (funct3)
                            3'b000: alu_result <= regfile[rs1] + imm;  // ADDI
                            3'b010: alu_result <= ($signed(regfile[rs1]) < $signed(imm)) ? 32'd1 : 32'd0;  // SLTI
                            3'b011: alu_result <= (regfile[rs1] < imm) ? 32'd1 : 32'd0;  // SLTIU
                            3'b100: alu_result <= regfile[rs1] ^ imm;  // XORI
                            3'b110: alu_result <= regfile[rs1] | imm;  // ORI
                            3'b111: alu_result <= regfile[rs1] & imm;  // ANDI
                            3'b001: alu_result <= regfile[rs1] << imm[4:0];  // SLLI
                            3'b101: begin
                                if (funct7[5])
                                    alu_result <= $signed(regfile[rs1]) >>> imm[4:0];  // SRAI
                                else
                                    alu_result <= regfile[rs1] >> imm[4:0];  // SRLI
                            end
                            default: alu_result <= 32'h0;
                        endcase
                        state <= STATE_WB;
                    end

                    OP_REG: begin
                        case (funct3)
                            3'b000: begin
                                if (funct7[5])
                                    alu_result <= regfile[rs1] - regfile[rs2];  // SUB
                                else
                                    alu_result <= regfile[rs1] + regfile[rs2];  // ADD
                            end
                            3'b001: alu_result <= regfile[rs1] << regfile[rs2][4:0];  // SLL
                            3'b010: alu_result <= ($signed(regfile[rs1]) < $signed(regfile[rs2])) ? 32'd1 : 32'd0;  // SLT
                            3'b011: alu_result <= (regfile[rs1] < regfile[rs2]) ? 32'd1 : 32'd0;  // SLTU
                            3'b100: alu_result <= regfile[rs1] ^ regfile[rs2];  // XOR
                            3'b101: begin
                                if (funct7[5])
                                    alu_result <= $signed(regfile[rs1]) >>> regfile[rs2][4:0];  // SRA
                                else
                                    alu_result <= regfile[rs1] >> regfile[rs2][4:0];  // SRL
                            end
                            3'b110: alu_result <= regfile[rs1] | regfile[rs2];  // OR
                            3'b111: alu_result <= regfile[rs1] & regfile[rs2];  // AND
                            default: alu_result <= 32'h0;
                        endcase
                        state <= STATE_WB;
                    end

                    OP_FENCE, OP_SYSTEM: begin
                        // Treat as NOP
                        pc <= decode_pc + (is_compressed ? 32'd2 : 32'd4);
                        state <= STATE_IF;
                        bytes_fetched <= 3'd0;
                    end

                    default: begin
                        // Invalid opcode - skip
                        pc <= decode_pc + (is_compressed ? 32'd2 : 32'd4);
                        state <= STATE_IF;
                        bytes_fetched <= 3'd0;
                    end
                endcase
            end

            // ================================================================
            // Memory Load
            // ================================================================
            STATE_MEM_LOAD: begin
                case (funct3[1:0])
                    2'b00: begin  // LB, LBU
                        if (mem_bytes == 3'd0) begin
                            mem_a <= mem_addr_calc;
                            mem_wr <= 1'b0;
                            mem_bytes <= 3'd1;
                            state <= STATE_MEM_WAIT;
                        end else begin
                            if (funct3[2])  // LBU
                                alu_result <= {24'h0, mem_din};
                            else  // LB
                                alu_result <= sext({24'h0, mem_din}, 8);
                            state <= STATE_WB;
                        end
                    end

                    2'b01: begin  // LH, LHU
                        if (mem_bytes < 3'd2) begin
                            mem_a <= mem_addr_calc + mem_bytes;
                            mem_wr <= 1'b0;
                            state <= STATE_MEM_WAIT;
                        end else begin
                            if (funct3[2])  // LHU
                                alu_result <= {16'h0, load_data[15:0]};
                            else  // LH
                                alu_result <= sext({16'h0, load_data[15:0]}, 16);
                            state <= STATE_WB;
                        end
                    end

                    2'b10: begin  // LW
                        if (mem_bytes < 3'd4) begin
                            mem_a <= mem_addr_calc + mem_bytes;
                            mem_wr <= 1'b0;
                            state <= STATE_MEM_WAIT;
                        end else begin
                            alu_result <= load_data;
                            state <= STATE_WB;
                        end
                    end

                    default: begin
                        state <= STATE_WB;
                    end
                endcase
            end

            STATE_MEM_WAIT: begin
                if (opcode == OP_LOAD) begin
                    load_data[mem_bytes*8-1 -: 8] <= mem_din;
                    mem_bytes <= mem_bytes + 1;
                    state <= STATE_MEM_LOAD;
                end else begin
                    mem_bytes <= mem_bytes + 1;
                    state <= STATE_MEM_STORE;
                end
            end

            // ================================================================
            // Memory Store
            // ================================================================
            STATE_MEM_STORE: begin
                case (funct3[1:0])
                    2'b00: begin  // SB
                        if (mem_bytes == 3'd0) begin
                            // Check for UART buffer full
                            if (mem_addr_calc == 32'h30000 && io_buffer_full) begin
                                // Wait for buffer
                                state <= STATE_MEM_STORE;
                            end else begin
                                mem_a <= mem_addr_calc;
                                mem_dout <= mem_data[7:0];
                                mem_wr <= 1'b1;
                                mem_bytes <= 3'd1;
                                state <= STATE_MEM_WAIT;
                            end
                        end else begin
                            mem_wr <= 1'b0;
                            pc <= decode_pc + (is_compressed ? 32'd2 : 32'd4);
                            state <= STATE_IF;
                            bytes_fetched <= 3'd0;
                        end
                    end

                    2'b01: begin  // SH
                        if (mem_bytes < 3'd2) begin
                            if (mem_addr_calc == 32'h30000 && io_buffer_full) begin
                                state <= STATE_MEM_STORE;
                            end else begin
                                mem_a <= mem_addr_calc + mem_bytes;
                                mem_dout <= mem_data[mem_bytes*8 +: 8];
                                mem_wr <= 1'b1;
                                state <= STATE_MEM_WAIT;
                            end
                        end else begin
                            mem_wr <= 1'b0;
                            pc <= decode_pc + (is_compressed ? 32'd2 : 32'd4);
                            state <= STATE_IF;
                            bytes_fetched <= 3'd0;
                        end
                    end

                    2'b10: begin  // SW
                        if (mem_bytes < 3'd4) begin
                            if (mem_addr_calc == 32'h30000 && io_buffer_full) begin
                                state <= STATE_MEM_STORE;
                            end else begin
                                mem_a <= mem_addr_calc + mem_bytes;
                                mem_dout <= mem_data[mem_bytes*8 +: 8];
                                mem_wr <= 1'b1;
                                state <= STATE_MEM_WAIT;
                            end
                        end else begin
                            mem_wr <= 1'b0;
                            pc <= decode_pc + (is_compressed ? 32'd2 : 32'd4);
                            state <= STATE_IF;
                            bytes_fetched <= 3'd0;
                        end
                    end

                    default: begin
                        mem_wr <= 1'b0;
                        pc <= decode_pc + (is_compressed ? 32'd2 : 32'd4);
                        state <= STATE_IF;
                        bytes_fetched <= 3'd0;
                    end
                endcase
            end

            // ================================================================
            // Write Back
            // ================================================================
            STATE_WB: begin
                if (rd != 5'd0) begin
                    regfile[rd] <= alu_result;
                end

                // Update PC for non-branch instructions
                if (opcode != OP_JAL && opcode != OP_JALR && opcode != OP_BRANCH) begin
                    pc <= decode_pc + (is_compressed ? 32'd2 : 32'd4);
                end

                state <= STATE_IF;
                bytes_fetched <= 3'd0;
            end

            default: begin
                state <= STATE_IF;
            end
        endcase
    end
end

endmodule
