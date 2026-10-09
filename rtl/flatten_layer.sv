//Converts the feature maps into a single vector for the dense classifier
// 11x11x8 input -> 968 vector

module flatten_layer (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic signed [19:0] feature_data [0:7], // one eight-channel vector per spatial location in row-major order
    output logic valid_out,
    output logic signed [19:0] flattened_vector [0:967]
);


    // Spatial index within the 11x11 feature map for each channel
    int spatial_index;


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            spatial_index <= 0;
            for (int i = 0; i < 121*8; i++) begin //11x11 for each of 8 channels
                flattened_vector[i] <= 20'sd0;
            end
        end else begin
            valid_out <= 1'b0;
        
            if (valid_in) begin
                for (int ch = 0; ch < 8; ch++) begin
                    // Layout is: ch1(0-120), ch2(121-241), ..., ch8(847-967)
                    flattened_vector[ch * 121 + spatial_index] <= feature_data[ch]; //121 = 11x11
                end

                if (spatial_index == 120) begin
                    valid_out <= 1'b1;
                    spatial_index <= 0;
                end else begin
                    spatial_index <= spatial_index + 1;
                end
            end
        end
    end

endmodule
