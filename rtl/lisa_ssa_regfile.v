`timescale 1ns/1ps

module lisa_ssa_regfile #(
    parameter integer NUM_REGS = 256,
    parameter integer DATA_W   = 32
) (
    input  wire               clk,
    input  wire               rst,

    input  wire [7:0]         raddr0,
    input  wire [7:0]         raddr1,
    output wire [DATA_W-1:0]  rdata0,
    output wire [DATA_W-1:0]  rdata1,

    input  wire               wen,
    input  wire [7:0]         waddr,
    input  wire [DATA_W-1:0]  wdata
);
    reg [DATA_W-1:0] regs [0:NUM_REGS-1];
    integer i;

    assign rdata0 = regs[raddr0];
    assign rdata1 = regs[raddr1];

    // Fixed-size mapping from SSA ID -> physical storage slot.
    always @(posedge clk) begin
        if (rst) begin
            /* verilator lint_off BLKSEQ */
            for (i = 0; i < NUM_REGS; i = i + 1) begin
                // Use blocking assignment in reset loop for tool compatibility.
                regs[i] = {DATA_W{1'b0}};
            end
            /* verilator lint_on BLKSEQ */
        end else if (wen) begin
            regs[waddr] <= wdata;
        end
    end
endmodule
