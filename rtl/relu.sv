//if value < 0, output 0
//otherwise pass through the signed Q6.14 value unchanged

module relu (
    input  logic signed [19:0] acc_in,
    output logic signed [19:0] relu_out
);

    // ReLU is a scalar per-sample operation, not a neighborhood operation.
    // It takes one activation value and applies: if < 0 then 0 else value.
    // TODO: implement the signed compare/pass-through ReLU defined in README.md.
    // TODO: keep the output in the signed 20-bit Q6.14 convolution-activation domain.

    always_comb begin
        //Relu on every acc value
        if(acc_in < 20'sd0)
            relu_out = 20'sd0;
        else
            relu_out = acc_in;
    end


endmodule
