module tb_control_fsm;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic pixel_valid = 1'b0;
    logic conv1_valid = 1'b0;
    logic pool_valid = 1'b0;
    logic conv2_valid = 1'b0;
    logic flatten_done = 1'b0;
    logic dense_done = 1'b0;
    logic ready;
    logic done;
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

    localparam int CONV1_OUTPUTS = 26 * 26;
    localparam int POOL_OUTPUTS = 13 * 13 * 4;
    localparam int CONV2_OUTPUTS = 11 * 11;

    control_fsm dut (.*);

    always #5 clk = ~clk;

    task automatic tick;
        @(posedge clk);
        #1;
    endtask

    task automatic check(input logic condition, input string message);
        if (condition !== 1'b1) begin
            $fatal(1, "FAIL: %s", message);
        end
    endtask

    initial begin
        repeat (2) tick();
        rst_n = 1'b1;
        tick();
        check(!ready && !done, "reset returns to idle");

        start = 1'b1;
        tick();
        start = 1'b0;
        check(load_image && ready, "start enters image loading");

        // Pauses and a busy start must not advance or restart image loading.
        start = 1'b1;
        tick();
        start = 1'b0;
        check(load_image && ready, "busy start is ignored");

        pixel_valid = 1'b1;
        for (int item = 0; item < 783; item++) begin
            tick();
        end
        pixel_valid = 1'b0;
        tick();
        check(load_image && ready, "pixel-valid gap pauses the image count");

        pixel_valid = 1'b1;
        tick();
        pixel_valid = 1'b0;
        check(clear_window && !ready, "784th pixel enters Conv1 clear cycle");
        tick();
        check(!clear_window && enable_conv1, "Conv1 starts after clear pulse");

        conv1_valid = 1'b1;
        for (int item = 0; item < CONV1_OUTPUTS; item++) begin
            tick();
        end
        conv1_valid = 1'b0;
        check(enable_relu1, "676 Conv1 outputs enter ReLU1");
        for (int item = 0; item < CONV1_OUTPUTS; item++) begin
            tick();
        end
        check(enable_pool, "676 ReLU1 cycles enter pooling");

        pool_valid = 1'b1;
        for (int item = 0; item < POOL_OUTPUTS; item++) begin
            tick();
        end
        pool_valid = 1'b0;
        check(clear_window, "676 pooled outputs enter Conv2 clear cycle");
        tick();
        check(!clear_window && enable_conv2, "Conv2 starts after clear pulse");

        conv2_valid = 1'b1;
        for (int item = 0; item < CONV2_OUTPUTS; item++) begin
            tick();
        end
        conv2_valid = 1'b0;
        check(enable_relu2, "121 Conv2 outputs enter ReLU2");
        for (int item = 0; item < CONV2_OUTPUTS; item++) begin
            tick();
        end
        check(enable_flatten, "121 ReLU2 cycles enter Flatten");

        flatten_done = 1'b1;
        tick();
        flatten_done = 1'b0;
        check(start_dense && !enable_dense, "Dense initialization is a separate cycle");
        tick();
        check(!start_dense && enable_dense, "Dense features follow initialization");

        dense_done = 1'b1;
        tick();
        dense_done = 1'b0;
        check(done, "dense completion asserts done");
        tick();
        check(!done && !ready, "done is one cycle and FSM returns to idle");

        $display("PASS: control FSM protocol and transfer counts");
        $finish;
    end

endmodule
