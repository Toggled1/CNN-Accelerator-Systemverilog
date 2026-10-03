// Phase 1 smoke-test bench for the MNIST CNN simulation flow.
// This keeps the repository buildable and runnable before the full CNN datapath
// and end-to-end validation logic are implemented.

module tb_top;

    logic clk;
    logic rst_n;
    logic start;
    logic [7:0] pixel_in;
    logic pixel_valid;
    logic ready;
    logic done;
    logic [3:0] predicted_digit;

    localparam int MAX_CYCLES = 200;

    top_classifier dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .pixel_in(pixel_in),
        .pixel_valid(pixel_valid),
        .ready(ready),
        .done(done),
        .predicted_digit(predicted_digit)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("cnn_smoke.vcd");
        $dumpvars(0, tb_top);

        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        pixel_in = 8'd0;
        pixel_valid = 1'b0;

        // Apply reset for a few clock cycles
        repeat (3) @(posedge clk);
        rst_n = 1'b1;


        // Start the CNN process
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;


        // The sim should hopefully be done by this point!
        for (int i = 0; i < MAX_CYCLES; i++) begin
            @(posedge clk);
            if (done) begin
                $display("PASS: smoke simulation reached done in %0d cycles.", i + 1);
                $finish;
            end
        end

        $error("FAIL: done did not assert within %0d cycles.", MAX_CYCLES);
        $fatal(1, "Smoke-test timeout");
    end

endmodule
