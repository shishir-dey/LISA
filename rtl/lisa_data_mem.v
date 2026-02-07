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
    localparam integer MEM_ADDR_W = $clog2(MEM_BYTES);

    reg [7:0] mem [0:MEM_BYTES-1];
    integer i;
    wire [31:0] addr_u32    = {16'd0, addr};
    wire [31:0] addr_p1_u32 = addr_u32 + 32'd1;
    wire [31:0] addr_p2_u32 = addr_u32 + 32'd2;
    wire [31:0] addr_p3_u32 = addr_u32 + 32'd3;

    wire [7:0] rd_b0 = (addr_u32    < MEM_BYTES) ? mem[addr_u32[MEM_ADDR_W-1:0]]    : 8'h00;
    wire [7:0] rd_b1 = (addr_p1_u32 < MEM_BYTES) ? mem[addr_p1_u32[MEM_ADDR_W-1:0]] : 8'h00;
    wire [7:0] rd_b2 = (addr_p2_u32 < MEM_BYTES) ? mem[addr_p2_u32[MEM_ADDR_W-1:0]] : 8'h00;
    wire [7:0] rd_b3 = (addr_p3_u32 < MEM_BYTES) ? mem[addr_p3_u32[MEM_ADDR_W-1:0]] : 8'h00;

    assign read_data = {rd_b3, rd_b2, rd_b1, rd_b0};

    initial begin
        for (i = 0; i < MEM_BYTES; i = i + 1) begin
            mem[i] = 8'h00;
        end
    end

    // Simplified little-endian 32-bit store semantics.
    always @(posedge clk) begin
        if (write_en) begin
            if (addr_u32    < MEM_BYTES) mem[addr_u32[MEM_ADDR_W-1:0]]    <= write_data[7:0];
            if (addr_p1_u32 < MEM_BYTES) mem[addr_p1_u32[MEM_ADDR_W-1:0]] <= write_data[15:8];
            if (addr_p2_u32 < MEM_BYTES) mem[addr_p2_u32[MEM_ADDR_W-1:0]] <= write_data[23:16];
            if (addr_p3_u32 < MEM_BYTES) mem[addr_p3_u32[MEM_ADDR_W-1:0]] <= write_data[31:24];
        end
    end
endmodule
