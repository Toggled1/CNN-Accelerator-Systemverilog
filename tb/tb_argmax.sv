module tb_argmax;

    logic signed [19:0] logits [0:9];
    logic [3:0] winning_digit;

    argmax dut (
        .logits(logits),
        .winning_digit(winning_digit)
    );

    initial begin
        for (int class_index = 0; class_index < 10; class_index++) begin
            logits[class_index] = -20'sd10;
        end
        logits[7] = -20'sd1;
        #1;
        if (winning_digit !== 4'd7)
            $fatal(1, "argmax failed signed all-negative comparison");

        logits[2] = 20'sd15;
        logits[5] = 20'sd15;
        #1;
        if (winning_digit !== 4'd2)
            $fatal(1, "argmax failed lowest-index tie break");

        $display("PASS: argmax signed comparison and tie break");
        $finish;
    end

endmodule