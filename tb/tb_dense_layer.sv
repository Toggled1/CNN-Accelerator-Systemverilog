module tb_dense_layer;

    logic clk = 1'b0;
    logic rst_n = 1'b1;
    logic start_dense = 1'b0;
    logic signed [19:0] feature_pixel = 20'sd0;
    logic feature_valid = 1'b0;
    logic signed [7:0] dense_weights [0:9][0:967];
    logic signed [19:0] dense_biases [0:9];
    logic dense_done;
    wire signed [19:0] logits [0:9];

    dense_layer dut (.*);
    always #5 clk = ~clk;

    initial begin
        for (int class_index = 0; class_index < 10; class_index++) begin
            dense_biases[class_index] = class_index - 5;
            for (int feature_index = 0; feature_index < 968; feature_index++) begin
                dense_weights[class_index][feature_index] = 8'sd0;
            end
        end

        #1 rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        start_dense = 1'b1;
        feature_valid = 1'b1;
        @(posedge clk);
        #1;
        if (dense_done !== 1'b0)
            $fatal(1, "Dense completed on the initialization cycle");

        @(negedge clk);
        start_dense = 1'b0;
        for (int feature_index = 0; feature_index < 968; feature_index++) begin
            feature_pixel = feature_index;
            feature_valid = 1'b1;
            @(posedge clk);
            #1;
            if (feature_index < 967 && dense_done !== 1'b0)
                $fatal(1, "Dense completed before feature 967");
            if (feature_index == 967) begin
                if (dense_done !== 1'b1)
                    $fatal(1, "Dense did not complete after feature 967");
                for (int class_index = 0; class_index < 10; class_index++) begin
                    if (logits[class_index] !== dense_biases[class_index])
                        $fatal(1, "Dense bias-only logit mismatch for class %0d", class_index);
                end
            end
            @(negedge clk);
        end

        feature_valid = 1'b0;
        @(posedge clk);
        #1;
        if (dense_done !== 1'b0)
            $fatal(1, "Dense done was not a one-cycle pulse");

        $display("PASS: Dense start, 968 feature transfers, logits, and done timing");
        $finish;
    end

endmodule