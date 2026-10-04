
module top_classifier (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [7:0]  pixel_in,
    input  logic        pixel_valid,
    output logic        ready,
    output logic        done,
    output logic [3:0]  predicted_digit
);


// Control FSM instance


//To control FSM
logic conv1_valid;
logic pool_valid;
logic conv2_valid;
logic flatten_done;
logic dense_done;

//From control FSM
logic load_image;
logic enable_conv1;
logic enable_relu1;
logic enable_pool;
logic enable_conv2;
logic enable_relu2;
logic enable_flatten;
logic start_dense;
logic enable_dense;
logic clear_window;


control_fsm u_control_fsm (
    .clk           (clk),
    .rst_n         (rst_n),
    .start         (start),
    .pixel_valid   (pixel_valid),
    .conv1_valid   (conv1_valid),
    .pool_valid    (pool_valid),
    .conv2_valid   (conv2_valid),
    .flatten_done  (flatten_done),
    .dense_done    (dense_done),
    .ready         (ready),
    .done          (done),
    .load_image    (load_image),
    .enable_conv1  (enable_conv1),
    .enable_relu1  (enable_relu1),
    .enable_pool   (enable_pool),
    .enable_conv2  (enable_conv2),
    .enable_relu2  (enable_relu2),
    .enable_flatten(enable_flatten),
    .start_dense   (start_dense),
    .enable_dense  (enable_dense),
    .clear_window  (clear_window)
);




//weights_mem instance


logic signed [7:0] conv1_weights [0:3][0:8];
logic signed [19:0] conv1_biases [0:3];
logic signed [7:0] conv2_weights [0:7][0:35];
logic signed [19:0] conv2_biases [0:7];
logic signed [7:0] dense_weights [0:9][0:967];
logic signed [19:0] dense_biases [0:9];


weights_mem u_weights_mem(
    .conv1_weights (conv1_weights),
    .conv1_biases  (conv1_biases),
    .conv2_weights (conv2_weights),
    .conv2_biases  (conv2_biases),
    .dense_weights (dense_weights),
    .dense_biases  (dense_biases)
);







//host -> image_buffer

logic [7:0] image_buffer [27:0][27:0];

int image_buffer_row;
int image_buffer_col;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        image_buffer_row <= 0;
        image_buffer_col <= 0;
        for (int reset_row = 0; reset_row < 28; reset_row++) begin
            for (int reset_col = 0; reset_col < 28; reset_col++) begin
                image_buffer[reset_row][reset_col] <= 8'd0;
            end
        end
    end else if (!load_image) begin
        // Reset image buffer when not loading image
        image_buffer_row <= 0;
        image_buffer_col <= 0;

    end else begin
        // Load image into buffer when ready and pixel is valid
        if (ready && pixel_valid) begin
            image_buffer[image_buffer_row][image_buffer_col] <= pixel_in;

            // When we reach the end of a row, move to the next row
            if (image_buffer_col == 27) begin
                image_buffer_col <= 0;

                // If we haven't reached the last row, move to the next row
                if (image_buffer_row < 27) begin
                    image_buffer_row <= image_buffer_row + 1;
                end
            end else begin
                // Otherwise, move to the next column
                image_buffer_col <= image_buffer_col + 1;
            end
        end
    end
end







//line_buffer
logic [7:0] line_buffer_pixel_in;
logic line_buffer_pixel_valid;



// Signals for the line buffer and convolution window

logic window_conv1_valid;
logic signed [7:0] window_conv1 [0:8];
int image_read_index;




//Read index for the image buffer to feed the line buffer
always_comb begin
    line_buffer_pixel_in = image_buffer[image_read_index / 28][image_read_index % 28]; // Map 1D read index to 2D image buffer
    line_buffer_pixel_valid = enable_conv1 && (image_read_index < 784); // Valid when within image bounds and conv1 stage is enabled
end

always_ff @(posedge clk or negedge rst_n) begin

    // Update the image read index for the line buffer
    if (!rst_n) begin
        image_read_index <= 0;

    end else if (clear_window) begin
        image_read_index <= 0;

    // Increment the image read index on clock cycles when the line buffer pixel is valid
    end else if (line_buffer_pixel_valid) begin
        image_read_index <= image_read_index + 1;
    end
end





line_buffer u_line_buffer(
    .clk          (clk),
    .rst_n        (rst_n),
    .clear        (clear_window),
    .pixel_in     (line_buffer_pixel_in),
    .pixel_valid  (line_buffer_pixel_valid),
    .window_valid (window_conv1_valid),
    .window       (window_conv1) // Connect the conv1 convolution window
);


//conv_layer_1
logic signed [19:0] feature_map_buffer [0:25] [0:25] [0:3]; //[row][col][channel]

logic signed [19:0] conv_1_feature_map_item [0:3];


conv_layer_1 u_conv_layer_1(
    .clk            (clk),
    .rst_n          (rst_n),
    .enable         (enable_conv1),
    .valid_in       (window_conv1_valid),
    .window         (window_conv1),
    .filter_weights (conv1_weights),
    .filter_biases  (conv1_biases),
    .valid_out      (conv1_valid),
    .feature_map    (conv_1_feature_map_item)
);


int relu1_index;
int relu1_row;
int relu1_col;

always_comb begin
    relu1_row = relu1_index / 26;
    relu1_col = relu1_index % 26;
end

logic signed [19:0] relu_out [0:3];

int conv_1_feature_map_row = 0, conv_1_feature_map_col = 0;


always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin
        conv_1_feature_map_row <= 0;
        conv_1_feature_map_col <= 0;
        relu1_index <= 0;
        // Reset logic for feature map buffer
        for (int row = 0; row < 26; row = row + 1) begin
            for (int col = 0; col < 26; col = col + 1) begin
                for (int ch = 0; ch < 4; ch = ch + 1) begin
                    feature_map_buffer[row][col][ch] <= 20'd0;
                end
            end
        end

    end else begin


        // Clear the feature map row and column indices if the window is cleared
        if (clear_window) begin
            conv_1_feature_map_row <= 0;
            conv_1_feature_map_col <= 0;
            relu1_index <= 0;
    
        end else begin

            // Load feature_map_buffer with the new convolution output
            if (conv1_valid) begin
                for (int ch = 0; ch < 4; ch++) begin
                    feature_map_buffer[conv_1_feature_map_row][conv_1_feature_map_col][ch] <= conv_1_feature_map_item[ch];
                end

                // Update the feature map column and row indices after loading the new convolution output
                if (conv_1_feature_map_col == 25) begin
                    conv_1_feature_map_col <= 0;
                    conv_1_feature_map_row <= conv_1_feature_map_row + 1;
                end else begin

                    // Move to the next column in the feature map
                    conv_1_feature_map_col <= conv_1_feature_map_col + 1;
                end
            end


            // Apply ReLU activation to the current feature map element
            if (enable_relu1) begin
                for (int ch = 0; ch < 4; ch++) begin
                    feature_map_buffer[relu1_row][relu1_col][ch] <= relu_out[ch];
                end
                if (relu1_index == 26*26-1) begin
                    relu1_index <= 0;
                end else begin
                    relu1_index <= relu1_index + 1;
                end
            end else begin
                relu1_index <= 0;
            end
        end
    end

end


//relu 1 && 2





 
relu u_relu_0 (
    .acc_in  (feature_map_buffer[relu1_row][relu1_col][0]),
    .relu_out(relu_out[0])
);
relu u_relu_1 (
    .acc_in  (feature_map_buffer[relu1_row][relu1_col][1]),
    .relu_out(relu_out[1])
);
relu u_relu_2 (
    .acc_in  (feature_map_buffer[relu1_row][relu1_col][2]),
    .relu_out(relu_out[2])
);
relu u_relu_3 (
    .acc_in  (feature_map_buffer[relu1_row][relu1_col][3]),
    .relu_out(relu_out[3])
);



















logic signed [19:0] pool_block [0:3];
logic signed [19:0] pooled_value;

always_comb begin
    for (int ch = 0; ch < 4; ch++) begin
        pool_block[ch] = 20'sd0;
    end
end

pooling_layer u_pooling_layer (
    .clk          (clk),
    .rst_n        (rst_n),
    .enable       (enable_pool),
    .valid_in     (1'b0),
    .pool_block   (pool_block),
    .valid_out    (pool_valid),
    .pooled_value (pooled_value)
);





endmodule
