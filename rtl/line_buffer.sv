// TODO: implement the sliding 3x3 window generator from README.md Section 9.4.
// Required behavior:
// - maintain enough image history for a 3x3 receptive field
// - output nine signed Q1.7 samples in row-major order
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

    // During CONV1, accept a pixel on each rising edge with pixel_valid high.
    // After accepting a pixel that completes a window, present window[0:8] in
    // row-major Q1.7 order and assert window_valid for the following cycle.
    // TODO: implement row buffering and window extraction logic.
    // TODO: ensure window ordering matches the model export contract.

endmodule
