// TODO: implement the self-checking simulation testbench from README.md Section 9.10.
// Required behavior:
// - initialize clock and reset
// - load input_images.mem and golden_outputs.mem
// - stream one MNIST image into the design
// - wait until done is asserted
// - compare predicted_digit against the expected label
// - print pass/fail and final accuracy summary
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
    // TODO: compare output against golden_outputs.mem.
    // TODO: print final accuracy summary after all validation samples.

    initial begin
        // TODO: initialize simulation state.
        $display("TODO: implement the testbench per README.md Section 9.10.");
        $finish;
    end

endmodule
