module tb_pooling_layer;

    logic clk = 1'b0;
    logic rst_n = 1'b1;
    logic enable = 1'b0;
    logic valid_in = 1'b0;
    logic signed [19:0] pool_block [0:3];
    logic valid_out;
    logic signed [19:0] pooled_value;

    pooling_layer dut (.*);
    always #5 clk = ~clk;

    initial begin
        pool_block[0] = -20'sd9;
        pool_block[1] = -20'sd4;
        pool_block[2] = -20'sd20;
        pool_block[3] = -20'sd8;

        #1 rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        enable = 1'b1;
        valid_in = 1'b1;
        @(posedge clk);
        #1;
        if (valid_out !== 1'b1 || pooled_value !== -20'sd4)
            $fatal(1, "Pooling failed signed maximum on a valid transfer");

        @(negedge clk);
        valid_in = 1'b0;
        @(posedge clk);
        #1;
        if (valid_out !== 1'b0 || pooled_value !== -20'sd4)
            $fatal(1, "Pooling valid pulse or output hold mismatch");

        $display("PASS: pooling signed maximum and valid timing");
        $finish;
    end

endmodule