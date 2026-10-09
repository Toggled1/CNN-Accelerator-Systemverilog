//Performs the second convolution stage
//13x13x4 input -> 11x11x8 output

module conv_layer_2 (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    input  logic valid_in,
    input  logic signed [19:0] window [0:35],
    input  logic signed [7:0] filter_weights [0:7][0:35],
    input  logic signed [19:0] filter_biases [0:7],
    output logic valid_out,
    output logic signed [19:0] feature_map [0:7]
);

    logic signed [39:0] mac [0:7]; // intermediate MAC results for the 8 filters
    logic signed [39:0] scaled_mac [0:7]; // Q6.14 results after the Q7.21 shift
    logic signed [19:0] saturated_mac [0:7]; // saturated MAC results for the 8 filters
    logic signed [27:0] product; // Q7.21 product
    // Q6.14 activations times Q1.7 weights produce Q7.21 products.

    //ACCEPT WHEN
    //window_valid && enable_conv2
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            for (int f = 0; f < 8; f++) begin
                feature_map[f] <= 20'sd0;
            end
        end else begin
            valid_out <= 1'b0;

            if (enable && valid_in) begin
                for (int f = 0; f < 8; f++) begin
                    // Assign the saturated MAC result to the feature map
                    feature_map[f] <= saturated_mac[f];
                end
                valid_out <= 1'b1;
            end
        end
    end

    always_comb begin
        for (int f = 0; f < 8; f++) begin
            mac[f] = $signed({{13{filter_biases[f][19]}}, filter_biases[f], 7'b0});

            for (int k = 0; k < 36; k++) begin
                product = $signed({{8{window[k][19]}}, window[k]}) * $signed({{20{filter_weights[f][k][7]}}, filter_weights[f][k]}); //product bits = 20 window bits+ 8 filter bits= 28
                mac[f] = mac[f] + $signed({{12{product[27]}}, product}); //we shifted bias earlier because 14 fractional bits (Q6.14) while the product has 21 fractional bits (Q7.21)
            end

            scaled_mac[f] = mac[f] >>> 7; // shift back to Q6.14 format from Q7.21

            if (scaled_mac[f] > 40'sd524287) begin
                saturated_mac[f] = 20'sh7FFFF;
            end else if (scaled_mac[f] < -40'sd524288) begin
                saturated_mac[f] = 20'sh80000;
            end else begin
                saturated_mac[f] = $signed(scaled_mac[f][19:0]);
            end
        end
    end


endmodule
