// Second convolution stage for the MNIST CNN project.
// Architecture: 13x13x4 input -> 11x11x8 output
// This stage extracts higher-level features from the pooled feature map.

module conv_layer_2 (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    input  logic valid_in,
    input  logic signed [7:0] window [0:8],
    input  logic signed [7:0] filter_weights [0:7][0:8],
    input  logic signed [19:0] filter_biases [0:7],
    output logic valid_out,
    output logic signed [19:0] feature_map [0:7]
);

    // TODO: implement the second convolution stage for 8 output channels.
    // TODO: align the data order with the flattened dense layer input.

endmodule
