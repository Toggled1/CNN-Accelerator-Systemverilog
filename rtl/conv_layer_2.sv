// Second convolution stage for the MNIST CNN project.
// Architecture: 13x13x4 input -> 11x11x8 output
// This stage extracts higher-level features from the pooled feature map.

module conv_layer_2 (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    input  logic valid_in,
    input  logic signed [19:0] window [0:35],
    input  logic signed [7:0] filter_weights [0:7][0:35],
    input  logic signed [19:0] filter_biases [0:7],
    output logic valid_out,
    output logic signed [19:0] feature_map [0:7]
);

    // For channel ch and kernel position (ky, kx), the flat index is
    // ch * 9 + ky * 3 + kx. Outputs are pre-ReLU and valid one cycle later.
    // TODO: implement eight 36-term MACs using the Section 5 arithmetic rules.

endmodule
