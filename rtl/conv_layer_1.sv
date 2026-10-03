// First convolution stage for the MNIST CNN project.
// Architecture: 28x28x1 input -> 26x26x4 pre-ReLU output

module conv_layer_1 (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    input  logic valid_in,
    input  logic signed [7:0] window [0:8],
    input  logic signed [7:0] filter_weights [0:3][0:8],
    input  logic signed [19:0] filter_biases [0:3],
    output logic valid_out,
    output logic signed [19:0] feature_map [0:3]
);

    logic signed [39:0] mac [0:3]; // intermediate MAC results for the 4 filters
    logic signed [19:0] saturated_mac [0:3]; // saturated MAC results for the 4 filters
    logic signed [15:0] product; // 16 bit product


    //ACCEPT WHEN
    //window_valid && enable_conv1    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            for (int f = 0; f < 4; f++) begin
                feature_map[f] <= 20'sd0;
            end
        end else begin
            valid_out <= 1'b0;

            if (enable && valid_in) begin
                for (int f = 0; f < 4; f++) begin
                    // Assign the saturated MAC result to the feature map
                    feature_map[f] <= saturated_mac[f];
                end
                valid_out <= 1'b1;
            end
        end
    end

    always_comb begin
        for (int f = 0; f < 4; f++) begin
            mac[f] = $signed({{20{filter_biases[f][19]}}, filter_biases[f]});


            // k is the index for the 3x3 window elements
            for (int k = 0; k < 9; k++) begin

                //product is 16 bits and sign extended from 8-bit window and filter weights
                product = $signed({{8{window[k][7]}}, window[k]}) * $signed({{8{filter_weights[f][k][7]}}, filter_weights[f][k]});

                // Add the bias and the product
                mac[f] = mac[f] + $signed({{24{product[15]}}, product});
            end

            //saturate to signed 20-bit range
            if (mac[f] > 40'sd524287) begin
                saturated_mac[f] = 20'sh7FFFF;
            end else if (mac[f] < -40'sd524288) begin
                saturated_mac[f] = 20'sh80000;
            end else begin
                saturated_mac[f] = $signed(mac[f][19:0]);
                end
            end
        end


endmodule
