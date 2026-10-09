//Computes ten class scores from the flattened Q6.14 feature vector
//Products and running sums use Q7.21, final logits are saturated Q6.14

module dense_layer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start_dense,
    input  logic signed [19:0] feature_pixel, //Q6.14 (use int index to keep track of which pixel)
    input  logic        feature_valid,
    input  logic signed [7:0] dense_weights [0:9][0:967], //Q1.7
    input  logic signed [19:0] dense_biases [0:9], //Q6.14, one bias per class
    output logic        dense_done,
    output logic signed [19:0] logits [0:9] //accumulated dot prod
);

    int index; 
    logic active; //active register set by start_dense signal
    logic signed [39:0] accumulator [0:9]; //Q7.21 (accumulating sums per class)
    logic signed [39:0] product [0:9]; //Q7.21 products, sign-extended to 40 bits
    logic signed [39:0] next_mac [0:9]; //current accumulation + current product: Q7.21
    logic signed [39:0] scaled_mac [0:9]; //after mac in 7.21 converts back to Q6.14 values with >>> 7
    logic signed [19:0] saturated_mac [0:9]; // saturate to [19:0]

    // State and outputs are registers; accept the start pulse separately from feature data.
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            index <= 0;
            active <= 1'b0;
            dense_done <= 1'b0;

            for (int i = 0; i < 10; i++) begin
                accumulator[i] <= 40'sd0;
                logits[i] <= 20'sd0;
            end



        end else begin
            //default to done = 0
            dense_done <= 1'b0;

            if (start_dense) begin
                index <= 0;
                active <= 1'b1;
                for (int k = 0; k < 10; k++) begin
                    //Align the Q6.14 bias with Q7.21 prod by left shift by 7.
                    accumulator[k] <= $signed({{13{dense_biases[k][19]}}, dense_biases[k], 7'b0});
                end

            end else if (active && feature_valid) begin
                for (int k = 0; k < 10; k++) begin
                    accumulator[k] <= next_mac[k];
                end

                // when the 11x11x8 flattened feature map has been fully processed:
                if (index == 967) begin
                    for (int k = 0; k < 10; k++) begin
                        logits[k] <= saturated_mac[k]; //load logits with all 6.14 class values
                    end


                    dense_done <= 1'b1;
                    active <= 1'b0;
                    index <= 0;

                end else begin
                    index <= index + 1;
                end
            end
        end
    end

    always_comb begin
        for (int k = 0; k < 10; k++) begin

            //Q6.14 feature item x Q1.7 weight = Q7.21 product
            product[k] = $signed({{20{feature_pixel[19]}}, feature_pixel}) * $signed({{32{dense_weights[k][index][7]}}, dense_weights[k][index]});

            next_mac[k] = accumulator[k] + product[k]; //Q7.21 

            //back to Q6.14 scale before saturating to the output width
            scaled_mac[k] = next_mac[k] >>> 7;

            if (scaled_mac[k] > 40'sd524287) begin
                saturated_mac[k] = 20'sh7FFFF;
            end else if (scaled_mac[k] < -40'sd524288) begin
                saturated_mac[k] = 20'sh80000;
            end else begin
                saturated_mac[k] = $signed(scaled_mac[k][19:0]);
            end
        end
    end

endmodule
