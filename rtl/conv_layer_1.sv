// First convolution stage for the MNIST CNN project.
// Architecture: 28x28x1 input -> 26x26x4 pre-ReLU output

module conv_layer_1 (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    input  logic valid_in,
    input  logic signed [7:0] window [0:8],
    input  logic signed [7:0] filter_weights [0:3][0:8],
    input  logic signed [19:0] filter_biases [0:3],
    output logic valid_out,
    output logic signed [19:0] feature_map [0:3]
);

    // TODO: implement 3x3 sliding-window convolution for each of the 4 filters.
    // TODO: generate one output activation per filter from the current receptive field.
    // TODO: use the 40-bit MAC accumulator and 20-bit saturated output from Section 5.

endmodule
