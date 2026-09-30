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
    input  logic signed [7:0] feature_pixel,
    input  logic        feature_valid,
    output logic        dense_done,
    output logic signed [19:0] logits [0:9]
);

    // TODO: implement score accumulation for digits 0 through 9.
    // TODO: match the export ordering and class mapping from Python.

endmodule
