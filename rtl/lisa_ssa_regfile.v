`timescale 1ns/1ps

module lisa_ssa_regfile #(
    parameter integer NUM_REGS = 256,
    parameter integer DATA_W   = 32
) (
    input  wire               clk,
    input  wire               rst,

    input  wire [7:0]         raddr0,
    input  wire [7:0]         raddr1,
    input  wire [7:0]         raddr2,
    output wire [DATA_W-1:0]  rdata0,
    output wire [DATA_W-1:0]  rdata1,
    output wire [DATA_W-1:0]  rdata2,
    output wire               rvalid0,
    output wire               rvalid1,
    output wire               rvalid2,

    input  wire               wen,
    input  wire [7:0]         waddr,
    input  wire [DATA_W-1:0]  wdata
);
    reg [DATA_W-1:0] regs       [0:NUM_REGS-1];
    reg              valid_bits [0:NUM_REGS-1];
    integer i;

    assign rdata0  = regs[raddr0];
    assign rdata1  = regs[raddr1];
    assign rdata2  = regs[raddr2];
    assign rvalid0 = valid_bits[raddr0];
    assign rvalid1 = valid_bits[raddr1];
    assign rvalid2 = valid_bits[raddr2];

    // Fixed-size mapping from SSA ID -> physical storage slot.
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < NUM_REGS; i = i + 1) begin
                regs[i]       <= {DATA_W{1'b0}};
                valid_bits[i] <= 1'b0;
            end
        end else if (wen) begin
            regs[waddr]       <= wdata;
            valid_bits[waddr] <= 1'b1;
        end
    end
endmodule
