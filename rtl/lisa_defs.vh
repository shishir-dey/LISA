`ifndef LLVM_DEFS_VH
`define LLVM_DEFS_VH

// Instruction opcodes for the LLVM-like bytecode stream.
`define LLVM_OP_ICONST 8'h01
`define LLVM_OP_ADD    8'h02
`define LLVM_OP_SUB    8'h03
`define LLVM_OP_MUL    8'h04
`define LLVM_OP_LOAD   8'h05
`define LLVM_OP_STORE  8'h06
`define LLVM_OP_BR     8'h07
`define LLVM_OP_JMP    8'h08
`define LLVM_OP_RET    8'h09
`define LLVM_OP_PHI    8'h0A
`define LLVM_OP_HALT   8'hFF

// Decoded micro-ops used inside the core control path.
`define LLVM_UOP_NOP    5'd0
`define LLVM_UOP_ICONST 5'd1
`define LLVM_UOP_ADD    5'd2
`define LLVM_UOP_SUB    5'd3
`define LLVM_UOP_MUL    5'd4
`define LLVM_UOP_LOAD   5'd5
`define LLVM_UOP_STORE  5'd6
`define LLVM_UOP_BR     5'd7
`define LLVM_UOP_JMP    5'd8
`define LLVM_UOP_RET    5'd9
`define LLVM_UOP_PHI    5'd10
`define LLVM_UOP_HALT   5'd31

`define LLVM_MAX_FETCH_BYTES 16

`endif
