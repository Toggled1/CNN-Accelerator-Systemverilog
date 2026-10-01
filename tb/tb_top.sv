// TODO: implement the self-checking simulation testbench from README.md Section 9.13.
// Required behavior:
// - initialize clock and reset
// - load input_images.mem, golden_outputs.mem, and labels.mem
// - stream one MNIST image into the design
// - wait until done is asserted
// - fail if any parameter is unknown before inference or any logit is unknown at dense_done
// - compare predicted_digit exactly against the integer-reference prediction
// - separately compare predicted_digit against the MNIST ground-truth label
// - report reference agreement and classification accuracy separately
// - finish simulation with $finish;

module tb_top;

    logic clk;
    logic rst_n;
    logic start;
    logic [7:0] pixel_in;
    logic pixel_valid;
    logic ready;
    logic done;
    logic [3:0] predicted_digit;

    // TODO: instantiate top_classifier.
    // TODO: generate a 100 MHz clock or the required testbench clock frequency.
    // TODO: implement reset and input vector loading logic.
    // TODO: compare output against reference predictions and labels separately.
    // TODO: report exact-reference agreement and classification accuracy.

    initial begin
        // TODO: initialize simulation state.
        $display("TODO: implement the testbench per README.md Section 9.10.");
        $finish;
    end

endmodule
