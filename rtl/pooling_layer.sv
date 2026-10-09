// 2x2 max pooling stage
//26x26x4 -> 13x13x4 after pooling

module pooling_layer (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    input  logic valid_in,
    input  logic signed [19:0] pool_block [0:3],
    output logic valid_out,
    output logic signed [19:0] pooled_value
);

    // pool_block is one complete same-channel region ordered TL, TR, BL, BR.
    // Blocks arrive in pooled-row, pooled-column, channel order. On an enabled
    // valid input, register the signed maximum and assert valid_out next cycle.
    // TODO: implement 2x2 max pooling for each feature map cell.
    // TODO: preserve the location-major, channel-contiguous output order.

    logic signed [19:0] max_value;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            pooled_value <= 20'sd0;

        end else begin

            valid_out <= 1'b0;

            if (enable && valid_in) begin
                max_value = pool_block[0];
                for (int i = 1; i < 4; i++) begin
                    if (pool_block[i] > max_value) begin
                        max_value = pool_block[i];
                    end
                end

                pooled_value <= max_value;
                valid_out <= 1'b1;
            end
        end
    end

endmodule
