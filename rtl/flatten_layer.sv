// Flatten stage for the MNIST CNN project.
// Converts the feature maps into a single vector for the dense classifier.

module flatten_layer (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic signed [19:0] feature_data [0:7],
    output logic valid_out,
    output logic signed [19:0] flattened_vector [0:967]
);

    // TODO: serialize the 11x11x8 output into a 968-element vector.
    // TODO: maintain a fixed flatten order matching the export script and dense layer.

endmodule
