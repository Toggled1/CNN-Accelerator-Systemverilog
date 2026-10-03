// Temporary top-level placeholder for the Phase 1 smoke test.
// This is intentionally minimal and will be replaced by the complete CNN pipeline.

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

    
    // Simple start counter to simulate processing delay for the smoke test.
    logic [7:0] start_counter; //start_counter counts to a vlaue of 3 to simulate processing delay

    always @(posedge clk or negedge rst_n) begin

        // Upon reset, reset everything and set counter to 0
        if (!rst_n) begin
            ready <= 1'b0;
            done <= 1'b0;
            predicted_digit <= 4'd0;
            start_counter <= 8'd0;
        end else begin
            // When start goes high, set ready, start counter
            if (start) begin
                ready <= 1'b1;
                start_counter <= 8'd1;
                done <= 1'b0;
            end else if (start_counter != 8'd0) begin
                // Increment the counter until it reaches 3
                if (start_counter >= 8'd3) begin
                    ready <= 1'b0;
                    done <= 1'b1; // When counter reaches 3, mark as done
                    predicted_digit <= 4'd5; // Random digit to simulate the CNN's prediction
                end else begin
                    // Otherwise, increment the counter and keep ready high
                    start_counter <= start_counter + 8'd1;
                    ready <= 1'b1;
                end
            end
        end
    end

endmodule
