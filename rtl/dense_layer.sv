// TODO: implement the dense score calculation described in README.md Section 9.7.
// Required behavior:
// - consume flattened feature values in sequence
// - compute dot products for all 10 classes
// - produce logits[0:9]
// - ensure the memory ordering matches the exported model format

module dense_layer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start_dense,
    input  logic signed [19:0] feature_pixel,
    input  logic        feature_valid,
    input  logic signed [7:0] dense_weights [0:9][0:967],
    input  logic signed [19:0] dense_biases [0:9],
    output logic        dense_done,
    output logic signed [19:0] logits [0:9]
);

    // For flat index i, each class reads dense_weights[class][i].
    // TODO: implement ten accumulators using the Section 5 arithmetic rules.

endmodule
