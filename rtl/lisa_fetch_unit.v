`timescale 1ns/1ps

module lisa_fetch_unit #(
    parameter integer MAX_BYTES = 16
) (
    input  wire [15:0]            fetch_window,
    output wire [7:0]             opcode,
    output wire [7:0]             inst_len,
    output wire                   len_valid
);
    // Byte 0 is opcode; byte 1 is total instruction length in bytes.
    assign opcode    = fetch_window[7:0];
    assign inst_len  = fetch_window[15:8];

    assign len_valid = (inst_len >= 8'd2) && ({24'd0, inst_len} <= MAX_BYTES);
endmodule
