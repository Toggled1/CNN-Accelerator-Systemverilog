// TODO: implement the finite-state machine described in README.md Section 9.3.
// Required states: IDLE, LOAD_IMAGE, WINDOW_PREPARE, MAC_COMPUTE, ACTIVATION, DENSE_SCORE, DONE.
// Required behavior:
// - wait for start
// - coordinate image loading and pixel handshaking
// - trigger feature extraction and MAC compute stages
// - move through activation and dense score generation
// - assert done when prediction is valid

module control_fsm (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic pixel_valid,
    input  logic window_valid,
    input  logic mac_valid,
    input  logic dense_done,
    output logic ready,
    output logic done,
    output logic load_image,
    output logic enable_mac,
    output logic start_dense,
    output logic clear_window
);

    // TODO: define the FSM state register and next-state logic.
    // TODO: ensure valid/ready sequencing matches the expected RTL flow in README.md.

endmodule
