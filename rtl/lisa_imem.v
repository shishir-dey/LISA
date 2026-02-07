`timescale 1ns/1ps

module lisa_imem #(
    parameter integer MEM_BYTES = 512,
    parameter integer FETCH_BYTES = 16
) (
    input  wire                     clk,
    input  wire                     load_we,
    input  wire [15:0]              load_addr,
    input  wire [7:0]               load_data,
    input  wire [15:0]              fetch_addr,
    output reg  [FETCH_BYTES*8-1:0] fetch_window
);
    reg [7:0] mem [0:MEM_BYTES-1];
    integer i;

    initial begin
        for (i = 0; i < MEM_BYTES; i = i + 1) begin
            mem[i] = 8'h00;
        end
    end

    // Optional loader port (used by testbench) to place bytecode into instruction memory.
    always @(posedge clk) begin
        if (load_we && (load_addr < MEM_BYTES)) begin
            mem[load_addr] <= load_data;
        end
    end

    // Provide a fetch window so the fetch unit can support variable-length instructions.
    always @(*) begin
        for (i = 0; i < FETCH_BYTES; i = i + 1) begin
            if ((fetch_addr + i) < MEM_BYTES) begin
                fetch_window[(8*i) +: 8] = mem[fetch_addr + i];
            end else begin
                fetch_window[(8*i) +: 8] = 8'h00;
            end
        end
    end
endmodule
