//Compare ten signed logits combinationally -> output winning digit in logic [3:0]

module argmax (
    input  logic signed [19:0] logits [0:9],
    output logic [3:0]        winning_digit
);

    // TODO: initialize the candidate to class 0 and scan classes 1 through 9.

    always_comb begin

        winning_digit = 4'd0;
        for(int i = 1; i <= 9; i++) begin

            if(logits[i] > logits[winning_digit])
                winning_digit = i[3:0]; //take 4 lsb of 32 bit int
        end

    end
endmodule
