//Initialize weights and biases from exported .mem files
//keep memory layout consistent with the Python export order
//These are read-only values

module weights_mem (
    output logic signed [7:0] conv1_weights [0:3][0:8],
    output logic signed [19:0] conv1_biases [0:3],
    output logic signed [7:0] conv2_weights [0:7][0:35],
    output logic signed [19:0] conv2_biases [0:7],
    output logic signed [7:0] dense_weights [0:9][0:967],
    output logic signed [19:0] dense_biases [0:9]
);

    // Typed arrays load the four exported files and remain constant after initialization.
    // TODO: load arrays using the per-file index and signed-hex formats in README.md.

endmodule
