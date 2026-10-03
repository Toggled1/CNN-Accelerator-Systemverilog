// TODO: implement the argmax selection logic from README.md Section 9.11.
// Required behavior:
// - compare ten signed logits combinationally
// - replace the winner only on strict greater-than so ties select the lowest index
// - treat winning_digit as meaningful only when the top-level samples it at dense_done

module argmax (
    input  logic signed [19:0] logits [0:9],
    output logic [3:0]        winning_digit
);

    // TODO: initialize the candidate to class 0 and scan classes 1 through 9.

    always_comb begin

        winning_digit = 4'd0;
        for(int i = 1; i <= 9; i++) begin

            if(logits[i] > logits[winning_digit])
                winning_digit = i;
        end

    end
endmodule
