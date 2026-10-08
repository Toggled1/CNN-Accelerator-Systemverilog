module tb_conv_layer_2;

    logic clk = 1'b0;
    logic rst_n = 1'b1;
    logic enable = 1'b0;
    logic valid_in = 1'b0;
    logic signed [19:0] window [0:35];
    logic signed [7:0] filter_weights [0:7][0:35];
    logic signed [19:0] filter_biases [0:7];
    logic valid_out;
    wire signed [19:0] feature_map [0:7];

    conv_layer_2 dut (.*);
    always #5 clk = ~clk;

    initial begin
        for (int tap = 0; tap < 36; tap++) begin
            window[tap] = 20'sd0;
            for (int filter_index = 0; filter_index < 8; filter_index++) begin
                filter_weights[filter_index][tap] = 8'sd0;
            end
        end

        for (int filter_index = 0; filter_index < 8; filter_index++) begin
            filter_biases[filter_index] = filter_index - 4;
        end
        filter_biases[0] = 20'sd0;
        window[0] = 20'sd256;
        filter_weights[0][0] = 8'sd64;

        #1 rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        enable = 1'b1;
        valid_in = 1'b1;
        @(posedge clk);
        #1;
        if (valid_out !== 1'b1)
            $fatal(1, "Conv2 did not assert valid_out after accepting a window");
        if (feature_map[0] !== 20'sd128)
            $fatal(1, "Conv2 Q7.21-to-Q6.14 product scaling mismatch");
        for (int filter_index = 1; filter_index < 8; filter_index++) begin
            if (feature_map[filter_index] !== filter_biases[filter_index])
                $fatal(1, "Conv2 bias result mismatch for filter %0d", filter_index);
        end

        @(negedge clk);
        valid_in = 1'b0;
        @(posedge clk);
        #1;
        if (valid_out !== 1'b0)
            $fatal(1, "Conv2 valid_out did not clear after one cycle");

        $display("PASS: Conv2 transfer, scaled product, biases, and valid timing");
        $finish;
    end

endmodule