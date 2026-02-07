`timescale 1ns/1ps

module lisa_data_mem #(
    parameter integer MEM_BYTES = 1024
) (
    input  wire        clk,
    input  wire        write_en,
    input  wire [15:0] addr,
    input  wire [31:0] write_data,
    output wire [31:0] read_data
);
    reg [7:0] mem [0:MEM_BYTES-1];
    integer i;

    wire [7:0] rd_b0 = (addr < MEM_BYTES)       ? mem[addr]       : 8'h00;
    wire [7:0] rd_b1 = ((addr + 16'd1) < MEM_BYTES) ? mem[addr + 16'd1] : 8'h00;
    wire [7:0] rd_b2 = ((addr + 16'd2) < MEM_BYTES) ? mem[addr + 16'd2] : 8'h00;
    wire [7:0] rd_b3 = ((addr + 16'd3) < MEM_BYTES) ? mem[addr + 16'd3] : 8'h00;

    assign read_data = {rd_b3, rd_b2, rd_b1, rd_b0};

    initial begin
        for (i = 0; i < MEM_BYTES; i = i + 1) begin
            mem[i] = 8'h00;
        end
    end

    // Simplified little-endian 32-bit store semantics.
    always @(posedge clk) begin
        if (write_en) begin
            if (addr < MEM_BYTES) mem[addr] <= write_data[7:0];
            if ((addr + 16'd1) < MEM_BYTES) mem[addr + 16'd1] <= write_data[15:8];
            if ((addr + 16'd2) < MEM_BYTES) mem[addr + 16'd2] <= write_data[23:16];
            if ((addr + 16'd3) < MEM_BYTES) mem[addr + 16'd3] <= write_data[31:24];
        end
    end
endmodule
