`timescale 1ns/1ps
`include "lisa_defs.vh"

module lisa_control_flow_unit (
    input  wire [4:0]  uop,
    input  wire [15:0] pc,
    input  wire [7:0]  inst_len,
    input  wire [31:0] cond_value,
    input  wire [15:0] target_a,
    input  wire [15:0] target_b,
    input  wire [7:0]  tag_a,
    input  wire [7:0]  tag_b,

    output reg  [15:0] next_pc,
    output reg         pred_tag_we,
    output reg  [7:0]  pred_tag_next,
    output reg         halt
);
    always @(*) begin
        next_pc      = pc + {8'h00, inst_len};
        pred_tag_we  = 1'b0;
        pred_tag_next = 8'h00;
        halt         = 1'b0;

        case (uop)
            `LLVM_UOP_BR: begin
                pred_tag_we = 1'b1;
                if (cond_value != 32'h0000_0000) begin
                    next_pc       = target_a;
                    pred_tag_next = tag_a;
                end else begin
                    next_pc       = target_b;
                    pred_tag_next = tag_b;
                end
            end

            `LLVM_UOP_JMP: begin
                next_pc       = target_a;
                pred_tag_we   = 1'b1;
                pred_tag_next = tag_a;
            end

            `LLVM_UOP_RET: begin
                halt = 1'b1;
            end

            `LLVM_UOP_HALT: begin
                halt = 1'b1;
            end

            default: begin
                // Fall-through already set to sequential execution.
            end
        endcase
    end
endmodule
