module tb_relu;
    logic signed [19:0] acc_in;
    logic signed [19:0] relu_out;

    relu dut (
        .acc_in(acc_in),
        .relu_out(relu_out)
    );

    task automatic expect_value(
        input logic signed [19:0] value,
        input logic signed [19:0] expected
    );
        begin
            acc_in = value;
            #1;
            if (relu_out !== expected) begin
                $fatal(1, "input %0d: expected %0d, got %0d", value, expected, relu_out);
            end
        end
    endtask

    initial begin
        expect_value(-20'sd524288, 20'sd0);
        expect_value(-20'sd1, 20'sd0);
        expect_value(20'sd0, 20'sd0);
        expect_value(20'sd1, 20'sd1);
        expect_value(20'sd524287, 20'sd524287);
        $display("PASS: ReLU signed boundary checks");
        $finish;
    end
endmodule