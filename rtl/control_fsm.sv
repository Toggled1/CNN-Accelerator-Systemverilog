// TODO: implement the CNN control FSM per README.md.
// Required states:
// IDLE -> LOAD_IMAGE -> CONV1 -> RELU1 -> POOL -> CONV2 -> RELU2 -> FLATTEN -> DENSE -> DONE

module control_fsm (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic pixel_valid,
    input  logic conv1_valid,
    input  logic pool_valid,
    input  logic conv2_valid,
    input  logic dense_done,
    output logic ready,
    output logic done,
    output logic load_image,
    output logic enable_conv1,
    output logic enable_pool,
    output logic enable_conv2,
    output logic start_dense,
    output logic clear_window
);

    // TODO: define the FSM state register and next-state logic for the CNN pipeline.
    // TODO: use deterministic handshakes for image streaming and stage progression.

endmodule
