// TODO: implement the top-level CNN classifier described in README.md.
// Required flow:
// - stream MNIST pixels into the first convolution stage
// - apply ReLU and pooling
// - process second convolution stage
// - flatten feature maps
// - compute dense logits
// - return the winning digit via argmax

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

    // TODO: instantiate the CNN pipeline.
    // TODO: connect conv_layer_1, pooling_layer, conv_layer_2, flatten_layer, dense_layer, argmax.
    // TODO: keep valid/ready and done semantics aligned with the CNN FSM in control_fsm.sv.

endmodule
