// 2x2 max pooling stage for the MNIST CNN project.
// Architecture: 26x26x4 -> 13x13x4 after pooling

module pooling_layer (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    input  logic valid_in,
    input  logic signed [19:0] pool_block [0:3],
    output logic valid_out,
    output logic signed [19:0] pooled_value
);

    // Final repo protocol:
    // - this is a streaming CNN stage
    // - the pool_block[0:3] array is a local 2x2 neighborhood buffer, not a full-tensor input
    // - values may be filled over time as the stream advances across the feature map
    // - once the block is complete, max pooling emits one value and asserts valid_out
    // - only then is the next 2x2 region processed
    // TODO: implement 2x2 max pooling for each feature map cell.
    // TODO: keep the output ordering consistent with conv_layer_2 input expectations.

endmodule
