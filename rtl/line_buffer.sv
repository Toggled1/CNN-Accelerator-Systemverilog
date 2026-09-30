// TODO: implement the sliding 3x3 window generator from README.md Section 9.4.
// Required behavior:
// - maintain enough image history for a 3x3 receptive field
// - output nine pixels on valid cycles
// - keep window_valid asserted only when enough data is available

module line_buffer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        clear,
    input  logic [7:0]  pixel_in,
    input  logic        pixel_valid,
    output logic        window_valid,
    output logic signed [7:0] window [0:8]
);

    // TODO: implement row buffering and window extraction logic.
    // TODO: ensure window ordering matches the model export contract.

endmodule
