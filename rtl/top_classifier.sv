
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

/*-----------------------------------------------------------------

// Control FSM instance

-----------------------------------------------------------------*/

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



/*-----------------------------------------------------------------

//weights_mem instance

-----------------------------------------------------------------*/

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






/*-----------------------------------------------------------------

//Image Buffer Declaration and Loading

-----------------------------------------------------------------*/

logic [7:0] image_buffer [27:0][27:0];

int image_write_index;
int image_buffer_row;
int image_buffer_col;

always_comb begin
    image_buffer_row = image_write_index / 28;
    image_buffer_col = image_write_index % 28;
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        image_write_index <= 0;
        for (int reset_row = 0; reset_row < 28; reset_row++) begin
            for (int reset_col = 0; reset_col < 28; reset_col++) begin
                image_buffer[reset_row][reset_col] <= 8'd0;
            end
        end
    end else if (!load_image) begin
        // Reset image buffer when not loading image
        image_write_index <= 0;

    end else begin
        // Load image into buffer when ready and pixel is valid
        if (ready && pixel_valid && image_write_index < 28*28) begin
            image_buffer[image_buffer_row][image_buffer_col] <= pixel_in;
            image_write_index <= image_write_index + 1;
        end
    end
end



/*-----------------------------------------------------------------

//Line Buffer Loading

-----------------------------------------------------------------*/



logic [7:0] line_buffer_pixel_in;
logic line_buffer_pixel_valid;
logic window_conv1_valid;
logic signed [7:0] window_conv1 [0:8];
int image_read_index;
int image_read_row;
int image_read_col;

always_comb begin
    image_read_row = image_read_index / 28;
    image_read_col = image_read_index % 28;
end


// Assign image buffer values to the line buffer inputs
always_comb begin
    line_buffer_pixel_in = 8'd0;
    line_buffer_pixel_valid = enable_conv1 && (image_read_index < 28*28); // Valid when within image bounds and conv1 stage is enabled
    if (image_read_index >= 0 && image_read_index < 28*28) begin
        line_buffer_pixel_in = image_buffer[image_read_row][image_read_col];
    end
end

// Update the image read index for the line buffer
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
    .window_valid (window_conv1_valid), // Connect directly to the conv1 stage window valid signal
    .window       (window_conv1) // Connect the conv1 convolution window
);


/*-----------------------------------------------------------------

// Convolution Layer 1  | Feature map buffer construction | ReLU Process

-----------------------------------------------------------------*/


// Feature map signals
logic signed [19:0] feature_map_buffer [0:25] [0:25] [0:3]; //[row][col][channel]
logic signed [19:0] conv_1_feature_map_item [0:3]; // Output of the conv1 layer for each channel
int conv1_output_index;
int conv1_output_row;
int conv1_output_col;

always_comb begin
    conv1_output_row = conv1_output_index / 26;
    conv1_output_col = conv1_output_index % 26;
end


// ReLU indexing signals
int relu1_index;
int relu1_row;
int relu1_col;

always_comb begin
    relu1_row = relu1_index / 26;
    relu1_col = relu1_index % 26;
end

logic signed [19:0] relu_out [0:3];



// Combined always_ff process for Conv and ReLU
always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin
        // Reset logic for feature map buffer and ReLU index
        conv1_output_index <= 0;
        relu1_index <= 0;
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
            conv1_output_index <= 0;
            relu1_index <= 0;
    
        end else begin

            // CONV1 STAGE: Load feature_map_buffer with stream of conv1 output
            if (conv1_valid && conv1_output_index < 26*26) begin
                for (int ch = 0; ch < 4; ch++) begin
                    feature_map_buffer[conv1_output_row][conv1_output_col][ch] <= conv_1_feature_map_item[ch];
                end
                conv1_output_index <= conv1_output_index + 1;
            end

            // RELU STAGE: Apply ReLU activation to the current feature map element
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

/*-----------------------------------------------------------------

//Pooling Layer

-----------------------------------------------------------------*/

logic signed [19:0] pool_block [0:3];

int pool_index; //counts spatial positions in the pooling layer
int pool_row;
int pool_col;
int pool_channel;


logic pooling_valid_in;




always_comb begin
    pool_row = 2*(pool_index / 13);
    pool_col = 2*(pool_index % 13);
end

// Form the 2x2 pooling block for the current channel
always_comb begin
    for (int i = 0; i < 4; i++) begin
        pool_block[i] = 20'sd0;
    end

    pooling_valid_in = enable_pool && (pool_index < 13*13) && (pool_channel < 4);

    if (pooling_valid_in) begin
        pool_block[0] = feature_map_buffer[pool_row][pool_col][pool_channel];
        pool_block[1] = feature_map_buffer[pool_row][pool_col+1][pool_channel];
        pool_block[2] = feature_map_buffer[pool_row+1][pool_col][pool_channel];
        pool_block[3] = feature_map_buffer[pool_row+1][pool_col+1][pool_channel];
    end
end


always_ff @(posedge clk or negedge rst_n) begin

    // Update the image read index for the line buffer
    if (!rst_n) begin
        pool_index <= 0;
        pool_channel <= 0;

    end else if (clear_window) begin
        pool_index <= 0;
        pool_channel <= 0;

    // Increment the pool index on clock cycles when the pooling stage is enabled
    end else if (pooling_valid_in) begin
        pool_channel <= (pool_channel + 1) % 4; // Increment each clock cycle

        pool_index <= pool_index + ((pool_channel == 3) ? 1 : 0);//pooling stride = 2 every  4-cycle pool_channel cycle
    end
end



// Output to Pooled Feature Map

logic signed [19:0] pooled_value;
logic signed [19:0] pooled_feature_map_buffer [0:12] [0:12] [0:3]; //[row][col][channel]
int pooled_result_row;
int pooled_result_col;
int pooled_result_channel;


always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pooled_result_row <= 0;
        pooled_result_col <= 0;
        pooled_result_channel <= 0;
    end else begin
        if (!enable_pool) begin
            pooled_result_row <= 0;
            pooled_result_col <= 0;
            pooled_result_channel <= 0;
        end else if (pooling_valid_in) begin
            pooled_result_row <= pool_index / 13; // one cycle delayed from pool_row
            pooled_result_col <= pool_index % 13; // one cycle delayed from pool_col
            pooled_result_channel <= pool_channel; // one cycle delayed from pool_channel
        end

        if (pool_valid && enable_pool) begin
            pooled_feature_map_buffer[pooled_result_row][pooled_result_col][pooled_result_channel] <= pooled_value;
        end
    end
end


pooling_layer u_pooling_layer (
    .clk          (clk),
    .rst_n        (rst_n),
    .enable       (enable_pool),
    .valid_in     (pooling_valid_in),
    .pool_block   (pool_block),
    .valid_out    (pool_valid),
    .pooled_value (pooled_value)
);





endmodule
