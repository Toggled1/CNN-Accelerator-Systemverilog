module tb_weights_mem;

    wire signed [7:0] conv1_weights [0:3][0:8];
    wire signed [19:0] conv1_biases [0:3];
    wire signed [7:0] conv2_weights [0:7][0:35];
    wire signed [19:0] conv2_biases [0:7];
    wire signed [7:0] dense_weights [0:9][0:967];
    wire signed [19:0] dense_biases [0:9];

    weights_mem dut (.*);

    initial begin
        #1;
        for (int filter_index = 0; filter_index < 4; filter_index++) begin
            if ((^conv1_biases[filter_index]) === 1'bx)
                $fatal(1, "Conv1 bias %0d is unknown or uninitialized", filter_index);
            for (int weight_index = 0; weight_index < 9; weight_index++) begin
                if ((^conv1_weights[filter_index][weight_index]) === 1'bx)
                    $fatal(1, "Conv1 weight [%0d][%0d] is unknown or uninitialized", filter_index, weight_index);
            end
        end

        for (int filter_index = 0; filter_index < 8; filter_index++) begin
            if ((^conv2_biases[filter_index]) === 1'bx)
                $fatal(1, "Conv2 bias %0d is unknown or uninitialized", filter_index);
            for (int weight_index = 0; weight_index < 36; weight_index++) begin
                if ((^conv2_weights[filter_index][weight_index]) === 1'bx)
                    $fatal(1, "Conv2 weight [%0d][%0d] is unknown or uninitialized", filter_index, weight_index);
            end
        end

        for (int class_index = 0; class_index < 10; class_index++) begin
            if ((^dense_biases[class_index]) === 1'bx)
                $fatal(1, "Dense bias %0d is unknown or uninitialized", class_index);
            for (int weight_index = 0; weight_index < 968; weight_index++) begin
                if ((^dense_weights[class_index][weight_index]) === 1'bx)
                    $fatal(1, "Dense weight [%0d][%0d] is unknown or uninitialized", class_index, weight_index);
            end
        end

        $display("PASS: all typed parameter arrays contain known values");
        $finish;
    end

endmodule