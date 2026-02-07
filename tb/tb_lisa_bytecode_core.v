`timescale 1ns/1ps

module tb_lisa_bytecode_core;
    reg         clk;
    reg         rst;
    reg         prog_we;
    reg  [15:0] prog_addr;
    reg  [7:0]  prog_data;

    wire        halted;
    wire        ret_valid;
    wire [31:0] ret_value;
    wire [15:0] pc_debug;
    wire [1:0]  state_debug;
    wire [7:0]  pred_tag_debug;

    lisa_bytecode_core uut (
        .clk(clk),
        .rst(rst),
        .prog_we(prog_we),
        .prog_addr(prog_addr),
        .prog_data(prog_data),
        .halted(halted),
        .ret_valid(ret_valid),
        .ret_value(ret_value),
        .pc_debug(pc_debug),
        .state_debug(state_debug),
        .pred_tag_debug(pred_tag_debug)
    );

    reg [7:0] program_mem [0:88];
    reg [31:0] stored_word;
    integer i;
    integer timeout;

    always #5 clk = ~clk;

    initial begin
        clk      = 1'b0;
        rst      = 1'b1;
        prog_we  = 1'b0;
        prog_addr = 16'h0000;
        prog_data = 8'h00;

        for (i = 0; i <= 88; i = i + 1) begin
            program_mem[i] = 8'h00;
        end

        // Example LLVM-like bytecode program (addresses in comments):
        // 0x0000:  %1  = iconst 5
        // 0x0007:  %2  = iconst 7
        // 0x000E:  %3  = add %1, %2
        // 0x0013:  %4  = iconst 16
        // 0x001A:  store %3, %4
        // 0x001E:  %5  = load %4
        // 0x0022:  %6  = iconst 10
        // 0x0029:  %7  = sub %5, %6
        // 0x002E:  br %7, then=0x0037(tag1), else=0x0043(tag2)
        // 0x0037:  %8  = iconst 100
        // 0x003E:  jmp merge=0x004F, tag1
        // 0x0043:  %9  = iconst 200
        // 0x004A:  jmp merge=0x004F, tag2
        // 0x004F:  %10 = phi [%8,tag1], [%9,tag2]
        // 0x0056:  ret %10

        // %1 = iconst 5
        program_mem[0]  = 8'h01; program_mem[1]  = 8'h07; program_mem[2]  = 8'h01;
        program_mem[3]  = 8'h05; program_mem[4]  = 8'h00; program_mem[5]  = 8'h00; program_mem[6]  = 8'h00;

        // %2 = iconst 7
        program_mem[7]  = 8'h01; program_mem[8]  = 8'h07; program_mem[9]  = 8'h02;
        program_mem[10] = 8'h07; program_mem[11] = 8'h00; program_mem[12] = 8'h00; program_mem[13] = 8'h00;

        // %3 = add %1, %2
        program_mem[14] = 8'h02; program_mem[15] = 8'h05; program_mem[16] = 8'h03;
        program_mem[17] = 8'h01; program_mem[18] = 8'h02;

        // %4 = iconst 16
        program_mem[19] = 8'h01; program_mem[20] = 8'h07; program_mem[21] = 8'h04;
        program_mem[22] = 8'h10; program_mem[23] = 8'h00; program_mem[24] = 8'h00; program_mem[25] = 8'h00;

        // store %3, %4
        program_mem[26] = 8'h06; program_mem[27] = 8'h04; program_mem[28] = 8'h03; program_mem[29] = 8'h04;

        // %5 = load %4
        program_mem[30] = 8'h05; program_mem[31] = 8'h04; program_mem[32] = 8'h05; program_mem[33] = 8'h04;

        // %6 = iconst 10
        program_mem[34] = 8'h01; program_mem[35] = 8'h07; program_mem[36] = 8'h06;
        program_mem[37] = 8'h0A; program_mem[38] = 8'h00; program_mem[39] = 8'h00; program_mem[40] = 8'h00;

        // %7 = sub %5, %6
        program_mem[41] = 8'h03; program_mem[42] = 8'h05; program_mem[43] = 8'h07;
        program_mem[44] = 8'h05; program_mem[45] = 8'h06;

        // br %7, target_true=0x0037, target_false=0x0043, tags=(1,2)
        program_mem[46] = 8'h07; program_mem[47] = 8'h09; program_mem[48] = 8'h07;
        program_mem[49] = 8'h37; program_mem[50] = 8'h00;
        program_mem[51] = 8'h43; program_mem[52] = 8'h00;
        program_mem[53] = 8'h01; program_mem[54] = 8'h02;

        // %8 = iconst 100
        program_mem[55] = 8'h01; program_mem[56] = 8'h07; program_mem[57] = 8'h08;
        program_mem[58] = 8'h64; program_mem[59] = 8'h00; program_mem[60] = 8'h00; program_mem[61] = 8'h00;

        // jmp 0x004F, tag1
        program_mem[62] = 8'h08; program_mem[63] = 8'h05; program_mem[64] = 8'h4F;
        program_mem[65] = 8'h00; program_mem[66] = 8'h01;

        // %9 = iconst 200
        program_mem[67] = 8'h01; program_mem[68] = 8'h07; program_mem[69] = 8'h09;
        program_mem[70] = 8'hC8; program_mem[71] = 8'h00; program_mem[72] = 8'h00; program_mem[73] = 8'h00;

        // jmp 0x004F, tag2
        program_mem[74] = 8'h08; program_mem[75] = 8'h05; program_mem[76] = 8'h4F;
        program_mem[77] = 8'h00; program_mem[78] = 8'h02;

        // %10 = phi %8(tag1), %9(tag2)
        program_mem[79] = 8'h0A; program_mem[80] = 8'h07; program_mem[81] = 8'h0A;
        program_mem[82] = 8'h08; program_mem[83] = 8'h09; program_mem[84] = 8'h01; program_mem[85] = 8'h02;

        // ret %10
        program_mem[86] = 8'h09; program_mem[87] = 8'h03; program_mem[88] = 8'h0A;

        // Load the program while reset is asserted.
        for (i = 0; i <= 88; i = i + 1) begin
            @(negedge clk);
            prog_addr = i[15:0];
            prog_data = program_mem[i];
            prog_we   = 1'b1;
            @(posedge clk);
        end
        @(negedge clk);
        prog_we = 1'b0;

        @(posedge clk);
        @(posedge clk);
        rst = 1'b0;

        timeout = 0;
        while (!halted && (timeout < 300)) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        stored_word = {
            uut.dmem.mem[16'h0013],
            uut.dmem.mem[16'h0012],
            uut.dmem.mem[16'h0011],
            uut.dmem.mem[16'h0010]
        };

        if (!halted) begin
            $display("FAIL: core did not halt before timeout");
            $finish(1);
        end

        if (!ret_valid) begin
            $display("FAIL: ret_valid was not asserted");
            $finish(1);
        end

        if (ret_value !== 32'd100) begin
            $display("FAIL: ret_value=%0d expected 100", ret_value);
            $finish(1);
        end

        if (stored_word !== 32'd12) begin
            $display("FAIL: memory[0x10]=%0d expected 12", stored_word);
            $finish(1);
        end

        $display("PASS: ret_value=%0d memory[0x10]=%0d", ret_value, stored_word);
        $finish(0);
    end
endmodule
