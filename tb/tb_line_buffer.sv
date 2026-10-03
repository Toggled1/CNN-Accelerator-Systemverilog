module tb_line_buffer;
    logic clk = 0;
    logic rst_n = 1;
    logic clear = 0;
    logic [7:0] pixel_in = 0;
    logic pixel_valid = 0;
    logic window_valid;
    wire signed [7:0] window [0:8];
    int windows_seen = 0;
    int raw_value;
    logic signed [7:0] expected_sample;

    line_buffer dut (
        .clk(clk),
        .rst_n(rst_n),
        .clear(clear),
        .pixel_in(pixel_in),
        .pixel_valid(pixel_valid),
        .window_valid(window_valid),
        .window(window)
    );
    always #5 clk = ~clk;

    initial begin
        #1 rst_n = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;

        for (int r = 0; r < 28; r++) begin
            for (int c = 0; c < 28; c++) begin
                @(negedge clk);
                pixel_valid = 1;
                raw_value = r * 28 + c;
                pixel_in = raw_value[7:0];
                @(posedge clk);
                #1;

                if ((r >= 2) && (c >= 2)) begin
                    if (window_valid !== 1'b1)
                        $fatal(1, "missing valid at input (%0d,%0d)", r, c);
                    windows_seen++;
                    for (int ky = 0; ky < 3; ky++) begin
                        for (int kx = 0; kx < 3; kx++) begin
                            raw_value = (((r - 2 + ky) * 28 + (c - 2 + kx)) & 255);
                            expected_sample = $signed({1'b0, raw_value[7:1]});
                            if (window[ky * 3 + kx] !== expected_sample)
                                $fatal(1, "bad sample at input (%0d,%0d), index %0d: got %0d expected %0d", r, c, ky * 3 + kx, window[ky * 3 + kx], expected_sample);
                        end
                    end
                end else if (window_valid !== 1'b0) begin
                    $fatal(1, "unexpected valid at input (%0d,%0d)", r, c);
                end

                if ((r == 2) && (c == 2)) begin
                    @(negedge clk);
                    pixel_valid = 0;
                    @(posedge clk);
                    #1;
                    if (window_valid !== 1'b0)
                        $fatal(1, "window_valid stayed high during input gap");
                end
            end
        end

        if (windows_seen != 676)
            $fatal(1, "saw %0d windows, expected 676", windows_seen);

        @(negedge clk);
        clear = 1;
        pixel_valid = 1;
        @(posedge clk);
        #1;
        if (window_valid !== 1'b0)
            $fatal(1, "clear did not suppress window_valid");

        @(negedge clk);
        clear = 0;
        pixel_in = 8'd255;
        @(posedge clk);
        #1;
        if (window_valid !== 1'b0)
            $fatal(1, "buffer did not restart after clear");

        $display("PASS: verified %0d row-major windows, Q1.7 samples, input gap, and clear", windows_seen);
        $finish;
    end
endmodule
