// TODO: implement the sliding 3x3 window generator from README.md Section 9.4.
// Required behavior:
// - maintain enough image history for a 3x3 receptive field
// - output nine signed Q1.7 samples in row-major order
// - keep window_valid asserted only when enough data is available

module line_buffer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        clear,
    input  logic [7:0]  pixel_in,
    input  logic        pixel_valid,
    output logic        window_valid,
    output logic signed [7:0] window [0:8]
);

    // During CONV1, accept a pixel on each rising edge with pixel_valid high.
    // After accepting a pixel that completes a window, present window[0:8] in
    // row-major Q1.7 order and assert window_valid for the following cycle.
    // TODO: implement row buffering and window extraction logic.
    // TODO: ensure window ordering matches the model export contract.

    logic signed [7:0] pixel_buffer [2:0][27:0];

    logic signed [7:0] static_point_pixel;

    int col_write_index = 0;
    int row_write_index = 0;
   
    //since [7:0]: 255/2 = 127, used for converting 8-bit pixel to Q1.7 format
    assign static_point_pixel = signed'({1'b0, pixel_in[7:1]}); // convert to Q1.7 format

    
    always_ff @(posedge clk or negedge rst_n) begin

        if(!rst_n) begin
            window_valid <= 1'b0;
            col_write_index <= 0;
            row_write_index <= 0;



            for(int i = 0; i < 9; i++) begin
                window[i] <= 8'sd0;
            end
            
            // clear pixel buffer
            for(int i = 0; i < 3; i++) begin
                for(int j = 0; j < 28; j++) begin
                    pixel_buffer[i][j] <= 8'sd0;
                end
            end
        end else if(clear) begin
            window_valid <= 1'b0;
            col_write_index <= 0;
            row_write_index <= 0;


            for(int i = 0; i < 9; i++) begin
                window[i] <= 8'sd0;
            end
            // clear pixel buffer
            for(int i = 0; i < 3; i++) begin
                for(int j = 0; j < 28; j++) begin
                    pixel_buffer[i][j] <= 8'sd0;
                end
            end
        end else begin
            window_valid <= 1'b0;

            if(pixel_valid && row_write_index < 28) begin
                pixel_buffer[row_write_index % 3][col_write_index] <= static_point_pixel;

                if(row_write_index >= 2 && col_write_index >= 2) begin
                    window[0] <= pixel_buffer[(row_write_index - 2) % 3][col_write_index - 2];
                    window[1] <= pixel_buffer[(row_write_index - 2) % 3][col_write_index - 1];
                    window[2] <= pixel_buffer[(row_write_index - 2) % 3][col_write_index];
                    window[3] <= pixel_buffer[(row_write_index - 1) % 3][col_write_index - 2];
                    window[4] <= pixel_buffer[(row_write_index - 1) % 3][col_write_index - 1];
                    window[5] <= pixel_buffer[(row_write_index - 1) % 3][col_write_index];
                    window[6] <= pixel_buffer[row_write_index % 3][col_write_index - 2];
                    window[7] <= pixel_buffer[row_write_index % 3][col_write_index - 1];
                    window[8] <= static_point_pixel;
                    window_valid <= 1'b1;
                end

                if(col_write_index == 27) begin
                    col_write_index <= 0;
                    row_write_index <= row_write_index + 1;
                end else begin
                    col_write_index <= col_write_index + 1;
                end
            end
        end

    end
endmodule
