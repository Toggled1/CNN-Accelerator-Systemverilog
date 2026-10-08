module tb_conv_layer_1;

    logic clk = 1'b0;
    logic rst_n = 1'b1;
    logic enable = 1'b0;
    logic valid_in = 1'b0;
    logic signed [7:0] window [0:8];
    logic signed [7:0] filter_weights [0:3][0:8];
    logic signed [19:0] filter_biases [0:3];
    logic valid_out;
    wire signed [19:0] feature_map [0:3];

    conv_layer_1 dut (.*);
    always #5 clk = ~clk;

    initial begin
        for (int tap = 0; tap < 9; tap++) begin
            window[tap] = 8'sd0;
            for (int filter_index = 0; filter_index < 4; filter_index++) begin
                filter_weights[filter_index][tap] = 8'sd0;
            end
        end

        filter_biases[0] = 20'sd0;
        filter_biases[1] = -20'sd7;
        filter_biases[2] = 20'sd12;
        filter_biases[3] = -20'sd20;
        window[0] = 8'sd64;
        filter_weights[0][0] = 8'sd64;

        #1 rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        valid_in = 1'b1;
        @(posedge clk);
        #1;
        if (valid_out !== 1'b0)
            $fatal(1, "Conv1 consumed a disabled input");

        @(negedge clk);
        enable = 1'b1;
        @(posedge clk);
        #1;
        if (valid_out !== 1'b1)
            $fatal(1, "Conv1 did not assert valid_out after accepting a window");
        if (feature_map[0] !== 20'sd4096 || feature_map[1] !== -20'sd7 ||
            feature_map[2] !== 20'sd12 || feature_map[3] !== -20'sd20)
            $fatal(1, "Conv1 mismatch: x=%0d w=%0d b=%0d mac=%0d sat=%0d out=%0d",
                window[0], filter_weights[0][0], filter_biases[0],
                dut.mac[0], dut.saturated_mac[0], feature_map[0]);

        @(negedge clk);
        valid_in = 1'b0;
        @(posedge clk);
        #1;
        if (valid_out !== 1'b0)
            $fatal(1, "Conv1 valid_out did not clear after one cycle");

        $display("PASS: Conv1 enabled transfer, MAC, bias, and valid timing");
        $finish;
    end

endmodule