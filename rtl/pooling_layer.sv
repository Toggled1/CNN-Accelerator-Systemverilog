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

    // pool_block is one complete same-channel region ordered TL, TR, BL, BR.
    // Blocks arrive in pooled-row, pooled-column, channel order. On an enabled
    // valid input, register the signed maximum and assert valid_out next cycle.
    // TODO: implement 2x2 max pooling for each feature map cell.
    // TODO: preserve the location-major, channel-contiguous output order.

endmodule
