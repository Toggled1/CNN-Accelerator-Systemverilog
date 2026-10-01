// TODO: implement the activation stage from README.md Section 9.6.
// Required behavior:
// - apply ReLU to the signed input value
// - if value < 0, output 0
// - otherwise pass through the value or apply the documented clipping rule

module relu (
    input  logic signed [19:0] acc_in,
    output logic signed [19:0] relu_out
);

    // ReLU is a scalar per-sample operation, not a neighborhood operation.
    // It takes one activation value and applies: if < 0 then 0 else value.
    // TODO: implement the activation and clipping semantics defined in README.md.
    // TODO: keep the ReLU output in the same 20-bit signed domain as the convolution accumulator.

endmodule
