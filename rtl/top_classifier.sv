// TODO: implement the top-level classifier module per README.md Section 9.2.
// Required behavior:
// - accept a start signal and pixel stream
// - manage the inference cycle for one MNIST image
// - coordinate the line buffer, MAC stage, activation, dense layer, and argmax
// - assert done when the final digit prediction is valid
// - provide the predicted_digit output to the testbench

module top_classifier (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [7:0]  pixel_in,
    input  logic        pixel_valid,
    output logic        ready,
    output logic        done,
    output logic [3:0]  predicted_digit
);

    // TODO: instantiate control_fsm, line_buffer, mac_unit, relu, dense_layer, argmax.
    // TODO: connect the model parameters and output signals per README.md.

endmodule
