// TODO: implement the dense score calculation described in README.md Section 9.10.
// Required behavior:
// - consume flattened feature values in sequence
// - compute dot products for all 10 classes
// - produce logits[0:9]
// - ensure the memory ordering matches the exported model format

module dense_layer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start_dense,
    input  logic signed [19:0] feature_pixel,
    input  logic        feature_valid,
    input  logic signed [7:0] dense_weights [0:9][0:967],
    input  logic signed [19:0] dense_biases [0:9],
    output logic        dense_done,
    output logic signed [19:0] logits [0:9]
);

    // For flat index i, each class reads dense_weights[class][i].
    // TODO: implement ten accumulators using the Section 5 arithmetic rules.

    int index;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 0;
            dense_done <= 1'b0;
            for (int i = 0; i < 10; i++) begin
                logits[i] <= 20'sd0;
            end
        end else begin
            // dense layer computation here

            if (start_dense && feature_valid) begin

                //dot with each of the w10 weights (each number)

                //logit[k] = bias[k] + sum(flat[i] * weight[k][i])

                //then argmax determines which dot product aligns the most

//That is ten dot products, each with 968 terms. The README stores weights class-major: the 968 weights for class 0, then class 1, through class 9.




            end
            index <= index + 1;
        end
    end
endmodule


//    output logic signed [19:0] flattened_vector [0:967]