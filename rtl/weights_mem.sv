//Initialize weights and biases from exported .mem files
//keep memory layout consistent with the Python export order
//These are read-only values

module weights_mem (
    output logic signed [7:0] conv1_weights [0:3][0:8],
    output logic signed [19:0] conv1_biases [0:3],
    output logic signed [7:0] conv2_weights [0:7][0:35],
    output logic signed [19:0] conv2_biases [0:7],
    output logic signed [7:0] dense_weights [0:9][0:967],
    output logic signed [19:0] dense_biases [0:9]
);


    //these are the flat arrays from the .mem files
    logic signed [7:0]  conv1_w_file [0:35];
    logic signed [7:0]  conv2_w_file [0:287];
    logic signed [7:0]  dense_w_file [0:9679];
    logic signed [19:0] bias_file    [0:21];

    initial begin
        $readmemh("../tb/test_vectors/conv1_weights.mem", conv1_w_file);
        $readmemh("../tb/test_vectors/conv2_weights.mem", conv2_w_file);
        $readmemh("../tb/test_vectors/dense_weights.mem", dense_w_file);
        $readmemh("../tb/test_vectors/biases.mem", bias_file);

    /*
        put the flat arrays into proper array formats!!!
    */

        for (int f = 0; f < 4; f++) begin
            conv1_biases[f] = bias_file[f];
            for (int k = 0; k < 9; k++)
                conv1_weights[f][k] = conv1_w_file[f * 9 + k];
        end

        for (int f = 0; f < 8; f++) begin
            conv2_biases[f] = bias_file[4 + f];
            for (int k = 0; k < 36; k++)
                conv2_weights[f][k] = conv2_w_file[f * 36 + k];
        end

        for (int c = 0; c < 10; c++) begin
            dense_biases[c] = bias_file[12 + c];
            for (int i = 0; i < 968; i++)
                dense_weights[c][i] = dense_w_file[c * 968 + i];
        end
    end
endmodule
