// TODO: implement the MAC stage from README.md Section 9.5.
// Required behavior:
// - multiply the 3x3 window by the associated weight vector
// - accumulate the signed results into a 20-bit accumulator
// - maintain valid signals aligned with the FSM and downstream pipeline

module mac_unit (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic signed [7:0] window [0:8],
    input  logic signed [7:0] weights [0:8],
    input  logic signed [19:0] bias,
    output logic signed [19:0] acc_out,
    output logic               acc_valid
);

    // TODO: implement the 9-way multiply-accumulate.
    // TODO: keep arithmetic width consistent with Section 5 in README.md.

endmodule
