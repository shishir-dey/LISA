`timescale 1ns/1ps
`include "lisa_defs.vh"

module lisa_bytecode_core (
    input  wire        clk,
    input  wire        rst,

    // Program loader for instruction memory.
    input  wire        prog_we,
    input  wire [15:0] prog_addr,
    input  wire [7:0]  prog_data,

    output reg         halted,
    output reg         ret_valid,
    output reg  [31:0] ret_value,

    output wire [15:0] pc_debug,
    output wire [1:0]  state_debug,
    output wire [7:0]  pred_tag_debug
);
    localparam [1:0] ST_FETCH  = 2'd0;
    localparam [1:0] ST_DECODE = 2'd1;
    localparam [1:0] ST_EXEC   = 2'd2;
    localparam [1:0] ST_WB     = 2'd3;

    reg [1:0]  state_q;
    reg [15:0] pc_q;
    reg [7:0]  pred_tag_q;

    reg  [7:0]  inst_opcode_q;
    reg  [7:0]  inst_len_q;
    reg         inst_len_valid_q;
    reg  [`LLVM_MAX_FETCH_BYTES*8-1:0] inst_bytes_q;

    reg         exec_wen_q;
    reg  [7:0]  exec_dest_q;
    reg  [31:0] exec_result_q;

    reg         exec_mem_we_q;
    reg  [15:0] exec_mem_addr_q;
    reg  [31:0] exec_mem_wdata_q;

    reg  [15:0] exec_next_pc_q;
    reg         exec_pred_we_q;
    reg  [7:0]  exec_pred_tag_q;
    reg         exec_halt_q;

    reg         exec_ret_q;
    reg  [31:0] exec_ret_value_q;

    // ---------------------------------------------------------------------
    // Instruction path: byte-addressable IMEM -> fetch window -> decoder
    // ---------------------------------------------------------------------
    wire [`LLVM_MAX_FETCH_BYTES*8-1:0] imem_fetch_window;
    wire [7:0] fetch_opcode;
    wire [7:0] fetch_len;
    wire [`LLVM_MAX_FETCH_BYTES*8-1:0] fetch_bytes;
    wire       fetch_len_valid;

    lisa_imem #(
        .MEM_BYTES(512),
        .FETCH_BYTES(`LLVM_MAX_FETCH_BYTES)
    ) imem (
        .clk(clk),
        .load_we(prog_we),
        .load_addr(prog_addr),
        .load_data(prog_data),
        .fetch_addr(pc_q),
        .fetch_window(imem_fetch_window)
    );

    lisa_fetch_unit #(
        .MAX_BYTES(`LLVM_MAX_FETCH_BYTES)
    ) fetch_u (
        .fetch_window(imem_fetch_window),
        .opcode(fetch_opcode),
        .inst_len(fetch_len),
        .inst_bytes(fetch_bytes),
        .len_valid(fetch_len_valid)
    );

    wire [4:0]  dec_uop;
    wire        dec_wb_en;
    wire [7:0]  dec_dest;
    wire [7:0]  dec_src_a;
    wire [7:0]  dec_src_b;
    wire [31:0] dec_imm32;
    wire [15:0] dec_target_a;
    wire [15:0] dec_target_b;
    wire [7:0]  dec_tag_a;
    wire [7:0]  dec_tag_b;
    wire        dec_illegal;

    lisa_decoder decoder_u (
        .opcode(inst_opcode_q),
        .inst_len(inst_len_q),
        .inst_bytes(inst_bytes_q),
        .len_valid(inst_len_valid_q),
        .uop(dec_uop),
        .writeback_en(dec_wb_en),
        .dest_ssa(dec_dest),
        .src_a_ssa(dec_src_a),
        .src_b_ssa(dec_src_b),
        .imm32(dec_imm32),
        .target_a(dec_target_a),
        .target_b(dec_target_b),
        .tag_a(dec_tag_a),
        .tag_b(dec_tag_b),
        .illegal(dec_illegal)
    );

    // ---------------------------------------------------------------------
    // SSA register file: SSA ID is used directly as register index.
    // ---------------------------------------------------------------------
    wire [31:0] rf_rdata0;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;
    wire        rf_rvalid0;
    wire        rf_rvalid1;
    wire        rf_rvalid2;

    wire rf_wen = (state_q == ST_WB) && exec_wen_q;

    lisa_ssa_regfile regfile_u (
        .clk(clk),
        .rst(rst),
        .raddr0(dec_src_a),
        .raddr1(dec_src_b),
        .raddr2(8'h00),
        .rdata0(rf_rdata0),
        .rdata1(rf_rdata1),
        .rdata2(rf_rdata2),
        .rvalid0(rf_rvalid0),
        .rvalid1(rf_rvalid1),
        .rvalid2(rf_rvalid2),
        .wen(rf_wen),
        .waddr(exec_dest_q),
        .wdata(exec_result_q)
    );

    // ---------------------------------------------------------------------
    // Integer ALU for arithmetic LLVM ops.
    // ---------------------------------------------------------------------
    wire [31:0] alu_y;
    lisa_int_alu alu_u (
        .uop(dec_uop),
        .a(rf_rdata0),
        .b(rf_rdata1),
        .y(alu_y)
    );

    // ---------------------------------------------------------------------
    // Memory subsystem: LSU + byte-addressable data memory.
    // ---------------------------------------------------------------------
    wire        lsu_do_load  = (dec_uop == `LLVM_UOP_LOAD);
    wire        lsu_do_store = (dec_uop == `LLVM_UOP_STORE);
    wire [31:0] lsu_addr_src = lsu_do_store ? rf_rdata1 : rf_rdata0;

    wire [15:0] lsu_mem_addr;
    wire        lsu_mem_we;
    wire [31:0] lsu_mem_wdata;
    wire [31:0] lsu_load_data;

    wire [15:0] dmem_addr_mux = (state_q == ST_EXEC) ? lsu_mem_addr : exec_mem_addr_q;
    wire        dmem_we_mux   = (state_q == ST_WB) ? exec_mem_we_q : 1'b0;
    wire [31:0] dmem_rdata;

    lisa_lsu lsu_u (
        .do_load(lsu_do_load),
        .do_store(lsu_do_store),
        .addr(lsu_addr_src),
        .store_data(rf_rdata0),
        .mem_read_data(dmem_rdata),
        .mem_addr(lsu_mem_addr),
        .mem_write_en(lsu_mem_we),
        .mem_write_data(lsu_mem_wdata),
        .load_data(lsu_load_data)
    );

    lisa_data_mem #(
        .MEM_BYTES(1024)
    ) dmem (
        .clk(clk),
        .write_en(dmem_we_mux),
        .addr(dmem_addr_mux),
        .write_data(exec_mem_wdata_q),
        .read_data(dmem_rdata)
    );

    // ---------------------------------------------------------------------
    // Control-flow unit computes next PC and predecessor-edge tag updates.
    // The predecessor tag models "which incoming edge was taken" for PHI.
    // ---------------------------------------------------------------------
    wire [15:0] cfu_next_pc;
    wire        cfu_pred_we;
    wire [7:0]  cfu_pred_tag_next;
    wire        cfu_halt;

    lisa_control_flow_unit cfu_u (
        .uop(dec_uop),
        .pc(pc_q),
        .inst_len(inst_len_q),
        .cond_value(rf_rdata0),
        .target_a(dec_target_a),
        .target_b(dec_target_b),
        .tag_a(dec_tag_a),
        .tag_b(dec_tag_b),
        .next_pc(cfu_next_pc),
        .pred_tag_we(cfu_pred_we),
        .pred_tag_next(cfu_pred_tag_next),
        .halt(cfu_halt)
    );

    // ---------------------------------------------------------------------
    // Multi-cycle control FSM: fetch -> decode -> execute -> writeback
    // ---------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_q          <= ST_FETCH;
            pc_q             <= 16'h0000;
            pred_tag_q       <= 8'h00;

            inst_opcode_q    <= 8'h00;
            inst_len_q       <= 8'h00;
            inst_len_valid_q <= 1'b0;
            inst_bytes_q     <= {(`LLVM_MAX_FETCH_BYTES*8){1'b0}};

            exec_wen_q       <= 1'b0;
            exec_dest_q      <= 8'h00;
            exec_result_q    <= 32'h0000_0000;

            exec_mem_we_q    <= 1'b0;
            exec_mem_addr_q  <= 16'h0000;
            exec_mem_wdata_q <= 32'h0000_0000;

            exec_next_pc_q   <= 16'h0000;
            exec_pred_we_q   <= 1'b0;
            exec_pred_tag_q  <= 8'h00;
            exec_halt_q      <= 1'b0;

            exec_ret_q       <= 1'b0;
            exec_ret_value_q <= 32'h0000_0000;

            halted           <= 1'b0;
            ret_valid        <= 1'b0;
            ret_value        <= 32'h0000_0000;
        end else if (!halted) begin
            case (state_q)
                ST_FETCH: begin
                    inst_opcode_q    <= fetch_opcode;
                    inst_len_q       <= fetch_len;
                    inst_len_valid_q <= fetch_len_valid;
                    inst_bytes_q     <= fetch_bytes;
                    state_q          <= ST_DECODE;
                end

                ST_DECODE: begin
                    state_q <= ST_EXEC;
                end

                ST_EXEC: begin
                    exec_wen_q       <= 1'b0;
                    exec_dest_q      <= dec_dest;
                    exec_result_q    <= 32'h0000_0000;

                    exec_mem_we_q    <= 1'b0;
                    exec_mem_addr_q  <= 16'h0000;
                    exec_mem_wdata_q <= 32'h0000_0000;

                    exec_next_pc_q   <= cfu_next_pc;
                    exec_pred_we_q   <= cfu_pred_we;
                    exec_pred_tag_q  <= cfu_pred_tag_next;
                    exec_halt_q      <= cfu_halt | dec_illegal;

                    exec_ret_q       <= 1'b0;
                    exec_ret_value_q <= 32'h0000_0000;

                    case (dec_uop)
                        `LLVM_UOP_ICONST: begin
                            exec_wen_q    <= dec_wb_en;
                            exec_dest_q   <= dec_dest;
                            exec_result_q <= dec_imm32;
                        end

                        `LLVM_UOP_ADD,
                        `LLVM_UOP_SUB,
                        `LLVM_UOP_MUL: begin
                            exec_wen_q    <= dec_wb_en;
                            exec_dest_q   <= dec_dest;
                            exec_result_q <= alu_y;
                        end

                        `LLVM_UOP_LOAD: begin
                            exec_wen_q    <= dec_wb_en;
                            exec_dest_q   <= dec_dest;
                            exec_result_q <= lsu_load_data;
                        end

                        `LLVM_UOP_STORE: begin
                            exec_mem_we_q    <= lsu_mem_we;
                            exec_mem_addr_q  <= lsu_mem_addr;
                            exec_mem_wdata_q <= lsu_mem_wdata;
                        end

                        `LLVM_UOP_PHI: begin
                            exec_wen_q  <= dec_wb_en;
                            exec_dest_q <= dec_dest;
                            if (pred_tag_q == dec_tag_a) begin
                                exec_result_q <= rf_rdata0;
                            end else begin
                                exec_result_q <= rf_rdata1;
                            end
                        end

                        `LLVM_UOP_RET: begin
                            exec_ret_q       <= 1'b1;
                            exec_ret_value_q <= rf_rdata0;
                        end

                        default: begin
                            // No extra datapath action.
                        end
                    endcase

                    state_q <= ST_WB;
                end

                ST_WB: begin
                    pc_q <= exec_next_pc_q;

                    if (exec_pred_we_q) begin
                        pred_tag_q <= exec_pred_tag_q;
                    end

                    if (exec_ret_q) begin
                        ret_valid <= 1'b1;
                        ret_value <= exec_ret_value_q;
                    end

                    if (exec_halt_q) begin
                        halted <= 1'b1;
                    end

                    state_q <= ST_FETCH;
                end

                default: begin
                    state_q <= ST_FETCH;
                end
            endcase
        end
    end

    assign pc_debug       = pc_q;
    assign state_debug    = state_q;
    assign pred_tag_debug = pred_tag_q;
endmodule
