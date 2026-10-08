module tb_flatten_layer;

    logic clk = 1'b0;
    logic rst_n = 1'b1;
    logic valid_in = 1'b0;
    logic signed [19:0] feature_data [0:7];
    logic valid_out;
    wire signed [19:0] flattened_vector [0:967];

    flatten_layer dut (.*);
    always #5 clk = ~clk;

    initial begin
        for (int channel = 0; channel < 8; channel++) begin
            feature_data[channel] = 20'sd0;
        end

        #1 rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        for (int spatial_index = 0; spatial_index < 121; spatial_index++) begin
            @(negedge clk);
            valid_in = 1'b1;
            for (int channel = 0; channel < 8; channel++) begin
                feature_data[channel] = spatial_index * 8 + channel;
            end
            @(posedge clk);
            #1;

            if (spatial_index < 120 && valid_out !== 1'b0)
                $fatal(1, "Flatten completed before input vector 121");
            if (spatial_index == 120 && valid_out !== 1'b1)
                $fatal(1, "Flatten did not pulse valid_out on input vector 121");

            if (spatial_index == 17) begin
                @(negedge clk);
                valid_in = 1'b0;
                @(posedge clk);
                #1;
                if (valid_out !== 1'b0)
                    $fatal(1, "Flatten valid_out asserted during an input gap");
            end
        end

        for (int channel = 0; channel < 8; channel++) begin
            for (int spatial_index = 0; spatial_index < 121; spatial_index++) begin
                if (flattened_vector[channel * 121 + spatial_index] !== spatial_index * 8 + channel)
                    $fatal(1, "Flatten ordering mismatch at channel %0d index %0d", channel, spatial_index);
            end
        end

        @(negedge clk);
        valid_in = 1'b0;
        @(posedge clk);
        #1;
        if (valid_out !== 1'b0)
            $fatal(1, "Flatten valid_out did not clear after one cycle");

        $display("PASS: Flatten 121 vectors, gap handling, and channel-major order");
        $finish;
    end

endmodule