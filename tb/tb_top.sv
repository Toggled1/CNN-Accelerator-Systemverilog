module tb_top;

    logic clk;
    logic rst_n;
    logic start;
    logic [7:0] pixel_in;
    logic pixel_valid;
    logic ready;
    logic done;
    logic [3:0] predicted_digit;

    localparam int IMAGE_COUNT = 100;
    localparam int IMAGE_PIXELS = 28 * 28;
    localparam int MAX_RESULT_CYCLES = 10000;

    logic [7:0] image_mem [0:IMAGE_COUNT * IMAGE_PIXELS - 1];
    logic [3:0] golden_mem [0:IMAGE_COUNT - 1];
    logic [3:0] label_mem [0:IMAGE_COUNT - 1];
    integer image_start;
    integer image_limit;
    integer correct_count;
    integer mismatch_count;
    logic [3:0] result;

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

    task automatic send_image(input integer image_index);
        integer pixel_index;
        begin
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            while (!ready) begin
                @(negedge clk);
            end

            for (pixel_index = 0; pixel_index < IMAGE_PIXELS; pixel_index = pixel_index + 1) begin
                while (!ready) begin
                    @(negedge clk);
                end
                pixel_in = image_mem[image_index * IMAGE_PIXELS + pixel_index];
                pixel_valid = 1'b1;
                @(negedge clk);
            end
            pixel_valid = 1'b0;
        end
    endtask

    task automatic wait_for_result(output logic [3:0] result_digit);
        integer cycle_count;
        begin
            cycle_count = 0;
            while (!done && cycle_count < MAX_RESULT_CYCLES) begin
                @(negedge clk);
                cycle_count = cycle_count + 1;
            end
            if (!done) begin
                $fatal(1, "FAIL: inference timed out after %0d cycles", MAX_RESULT_CYCLES);
            end
            result_digit = predicted_digit;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        pixel_in = 8'd0;
        pixel_valid = 1'b0;
        image_start = 0;
        correct_count = 0;
        mismatch_count = 0;
        image_limit = IMAGE_COUNT;

        if ($value$plusargs("start=%d", image_start)) begin
            if (image_start < 0 || image_start >= IMAGE_COUNT) begin
                $fatal(1, "start must be between 0 and %0d", IMAGE_COUNT - 1);
            end
        end

        void'($value$plusargs("images=%d", image_limit));
        if (image_limit < 1 || image_start + image_limit > IMAGE_COUNT) begin
            $fatal(1, "image range must fit within %0d fixtures", IMAGE_COUNT);
        end

        $readmemh("../tb/test_vectors/input_images.mem", image_mem);
        $readmemh("../tb/test_vectors/golden_outputs.mem", golden_mem);
        $readmemh("../tb/test_vectors/labels.mem", label_mem);

        if ((^image_mem[IMAGE_COUNT * IMAGE_PIXELS - 1] === 1'bx) ||
            (^golden_mem[IMAGE_COUNT - 1] === 1'bx) ||
            (^label_mem[IMAGE_COUNT - 1] === 1'bx)) begin
            $fatal(1, "FAIL: test-vector files are missing values or contain unknowns");
        end

        if ($test$plusargs("dump")) begin
            $dumpfile("cnn_smoke.vcd");
            $dumpvars(0, tb_top);
        end

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        for (integer image_index = image_start; image_index < image_start + image_limit; image_index = image_index + 1) begin
            send_image(image_index);
            wait_for_result(result);

            if (result !== golden_mem[image_index]) begin
                mismatch_count = mismatch_count + 1;
                $display("MISMATCH: image %0d expected reference %0d, got %0d",
                       image_index, golden_mem[image_index], result);
            end

            if (result === label_mem[image_index]) begin
                correct_count = correct_count + 1;
            end
        end

        $display("RTL reference mismatches: %0d/%0d", mismatch_count, image_limit);
        $display("MNIST accuracy: %0d/%0d", correct_count, image_limit);
        if (mismatch_count != 0) begin
            $fatal(1, "FAIL: RTL predictions differ from the integer reference");
        end
        $display("PASS: RTL matched all %0d reference predictions.", image_limit);
        if (image_start == 0 && image_limit == IMAGE_COUNT && correct_count < 90) begin
            $fatal(1, "FAIL: expected at least 90/%0d correct classifications", IMAGE_COUNT);
        end
        $finish;
    end

endmodule
