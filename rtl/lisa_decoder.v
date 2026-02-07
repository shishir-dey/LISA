`timescale 1ns/1ps
`include "lisa_defs.vh"

module lisa_decoder (
    input  wire [7:0]                    opcode,
    input  wire [7:0]                    inst_len,
    input  wire [`LLVM_MAX_FETCH_BYTES*8-1:0] inst_bytes,
    input  wire                          len_valid,

    output reg  [4:0]                    uop,
    output reg                           writeback_en,
    output reg  [7:0]                    dest_ssa,
    output reg  [7:0]                    src_a_ssa,
    output reg  [7:0]                    src_b_ssa,
    output reg  [31:0]                   imm32,
    output reg  [15:0]                   target_a,
    output reg  [15:0]                   target_b,
    output reg  [7:0]                    tag_a,
    output reg  [7:0]                    tag_b,
    output reg                           illegal
);
    // Fixed byte positions within the fetch window.
    wire [7:0] b2 = inst_bytes[23:16];
    wire [7:0] b3 = inst_bytes[31:24];
    wire [7:0] b4 = inst_bytes[39:32];
    wire [7:0] b5 = inst_bytes[47:40];
    wire [7:0] b6 = inst_bytes[55:48];
    wire [7:0] b7 = inst_bytes[63:56];
    wire [7:0] b8 = inst_bytes[71:64];

    always @(*) begin
        uop          = `LLVM_UOP_NOP;
        writeback_en = 1'b0;
        dest_ssa     = 8'h00;
        src_a_ssa    = 8'h00;
        src_b_ssa    = 8'h00;
        imm32        = 32'h0000_0000;
        target_a     = 16'h0000;
        target_b     = 16'h0000;
        tag_a        = 8'h00;
        tag_b        = 8'h00;
        illegal      = 1'b0;

        if (!len_valid) begin
            uop     = `LLVM_UOP_HALT;
            illegal = 1'b1;
        end else begin
            case (opcode)
                `LLVM_OP_ICONST: begin
                    if (inst_len != 8'd7) begin
                        illegal = 1'b1;
                        uop     = `LLVM_UOP_HALT;
                    end else begin
                        uop          = `LLVM_UOP_ICONST;
                        writeback_en = 1'b1;
                        dest_ssa     = b2;
                        imm32        = {b6, b5, b4, b3};
                    end
                end

                `LLVM_OP_ADD: begin
                    if (inst_len != 8'd5) begin
                        illegal = 1'b1;
                        uop     = `LLVM_UOP_HALT;
                    end else begin
                        uop          = `LLVM_UOP_ADD;
                        writeback_en = 1'b1;
                        dest_ssa     = b2;
                        src_a_ssa    = b3;
                        src_b_ssa    = b4;
                    end
                end

                `LLVM_OP_SUB: begin
                    if (inst_len != 8'd5) begin
                        illegal = 1'b1;
                        uop     = `LLVM_UOP_HALT;
                    end else begin
                        uop          = `LLVM_UOP_SUB;
                        writeback_en = 1'b1;
                        dest_ssa     = b2;
                        src_a_ssa    = b3;
                        src_b_ssa    = b4;
                    end
                end

                `LLVM_OP_MUL: begin
                    if (inst_len != 8'd5) begin
                        illegal = 1'b1;
                        uop     = `LLVM_UOP_HALT;
                    end else begin
                        uop          = `LLVM_UOP_MUL;
                        writeback_en = 1'b1;
                        dest_ssa     = b2;
                        src_a_ssa    = b3;
                        src_b_ssa    = b4;
                    end
                end

                `LLVM_OP_LOAD: begin
                    if (inst_len != 8'd4) begin
                        illegal = 1'b1;
                        uop     = `LLVM_UOP_HALT;
                    end else begin
                        uop          = `LLVM_UOP_LOAD;
                        writeback_en = 1'b1;
                        dest_ssa     = b2;
                        src_a_ssa    = b3; // Address register.
                    end
                end

                `LLVM_OP_STORE: begin
                    if (inst_len != 8'd4) begin
                        illegal = 1'b1;
                        uop     = `LLVM_UOP_HALT;
                    end else begin
                        uop       = `LLVM_UOP_STORE;
                        src_a_ssa = b2; // Data register.
                        src_b_ssa = b3; // Address register.
                    end
                end

                `LLVM_OP_BR: begin
                    if (inst_len != 8'd9) begin
                        illegal = 1'b1;
                        uop     = `LLVM_UOP_HALT;
                    end else begin
                        uop       = `LLVM_UOP_BR;
                        src_a_ssa = b2; // Branch condition register.
                        target_a  = {b4, b3};
                        target_b  = {b6, b5};
                        tag_a     = b7;
                        tag_b     = b8;
                    end
                end

                `LLVM_OP_JMP: begin
                    if (inst_len != 8'd5) begin
                        illegal = 1'b1;
                        uop     = `LLVM_UOP_HALT;
                    end else begin
                        uop      = `LLVM_UOP_JMP;
                        target_a = {b3, b2};
                        tag_a    = b4;
                    end
                end

                `LLVM_OP_RET: begin
                    if (inst_len != 8'd3) begin
                        illegal = 1'b1;
                        uop     = `LLVM_UOP_HALT;
                    end else begin
                        uop       = `LLVM_UOP_RET;
                        src_a_ssa = b2;
                    end
                end

                `LLVM_OP_PHI: begin
                    if (inst_len != 8'd7) begin
                        illegal = 1'b1;
                        uop     = `LLVM_UOP_HALT;
                    end else begin
                        // PHI encoding:
                        //   phi dest, src_a, src_b, tag_a, tag_b
                        // Value comes from src_a if last edge tag == tag_a, else src_b.
                        uop          = `LLVM_UOP_PHI;
                        writeback_en = 1'b1;
                        dest_ssa     = b2;
                        src_a_ssa    = b3;
                        src_b_ssa    = b4;
                        tag_a        = b5;
                        tag_b        = b6;
                    end
                end

                `LLVM_OP_HALT: begin
                    if (inst_len != 8'd2) begin
                        illegal = 1'b1;
                    end
                    uop = `LLVM_UOP_HALT;
                end

                default: begin
                    illegal = 1'b1;
                    uop     = `LLVM_UOP_HALT;
                end
            endcase
        end
    end
endmodule
