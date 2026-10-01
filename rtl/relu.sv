// TODO: implement the activation stage from README.md Section 9.8.
// Required behavior:
// - apply ReLU to the signed input value
// - if value < 0, output 0
// - otherwise pass through the signed Q6.14 value unchanged

module relu (
    input  logic signed [19:0] acc_in,
    output logic signed [19:0] relu_out
);

    // ReLU is a scalar per-sample operation, not a neighborhood operation.
    // It takes one activation value and applies: if < 0 then 0 else value.
    // TODO: implement the signed compare/pass-through ReLU defined in README.md.
    // TODO: keep the output in the signed 20-bit Q6.14 convolution-activation domain.

endmodule
