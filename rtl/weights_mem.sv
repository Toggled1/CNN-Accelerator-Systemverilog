// TODO: implement the model parameter memory described in README.md Section 9.9.
// Required behavior:
// - initialize weights and biases from exported .mem files
// - keep memory layout consistent with the Python export order
// - support read-only values for the simulation environment

module weights_mem (
    input  logic clk,
    input  logic rst_n,
    input  logic [7:0] addr,
    output logic signed [7:0] weight_out,
    output logic signed [19:0] bias_out
);

    // TODO: define the parameter arrays and initialization values.
    // TODO: ensure the storage order matches the export and dense-layer logic.

endmodule
