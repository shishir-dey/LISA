`timescale 1ns/1ps
`include "lisa_defs.vh"

module lisa_int_alu (
    input  wire [4:0]  uop,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] y
);
    always @(*) begin
        case (uop)
            `LLVM_UOP_ADD: y = a + b;
            `LLVM_UOP_SUB: y = a - b;
            `LLVM_UOP_MUL: y = a * b;
            default:       y = 32'h0000_0000;
        endcase
    end
endmodule
