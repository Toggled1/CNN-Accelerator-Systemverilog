// TODO: implement the argmax selection logic from README.md Section 9.8.
// Required behavior:
// - compare all 10 logits
// - determine the maximum value
// - output the class index as a 4-bit digit

module argmax (
    input  logic signed [19:0] logits [0:9],
    output logic [3:0]        winning_digit
);

    // TODO: implement the comparator logic that selects the maximum logit.
    // TODO: ensure the output is the digit index from 0 to 9.

endmodule
