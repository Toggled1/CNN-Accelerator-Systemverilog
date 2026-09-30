// TODO: implement the activation stage from README.md Section 9.6.
// Required behavior:
// - apply ReLU to the signed input value
// - if value < 0, output 0
// - otherwise pass through the value or apply the documented clipping rule

module relu (
    input  logic signed [19:0] acc_in,
    output logic signed [7:0]  relu_out
);

    // TODO: implement the activation and clipping semantics defined in README.md.
    // TODO: ensure the output type matches the fixed-point convention used by the model export.

endmodule
