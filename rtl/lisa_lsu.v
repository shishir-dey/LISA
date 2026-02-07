`timescale 1ns/1ps

module lisa_lsu (
    input  wire        do_load,
    input  wire        do_store,
    input  wire [31:0] addr,
    input  wire [31:0] store_data,
    input  wire [31:0] mem_read_data,

    output wire [15:0] mem_addr,
    output wire        mem_write_en,
    output wire [31:0] mem_write_data,
    output wire [31:0] load_data
);
    assign mem_addr       = addr[15:0];
    assign mem_write_en   = do_store;
    assign mem_write_data = store_data;
    assign load_data      = do_load ? mem_read_data : 32'h0000_0000;
endmodule
