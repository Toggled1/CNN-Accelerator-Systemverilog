# TODO: implement the CNN simulation build flow per README.md.
# Required targets:
# - compile: compile the full CNN RTL pipeline
# - run: execute the testbench and validate results
# - wave: open GTKWave for debugging the key CNN stages

IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

RTL_SRC = \
    ../rtl/top_classifier.sv \
    ../rtl/control_fsm.sv \
    ../rtl/line_buffer.sv \
    ../rtl/conv_layer_1.sv \
    ../rtl/conv_layer_2.sv \
    ../rtl/pooling_layer.sv \
    ../rtl/relu.sv \
    ../rtl/flatten_layer.sv \
    ../rtl/dense_layer.sv \
    ../rtl/argmax.sv \
    ../rtl/weights_mem.sv

TB_SRC = ../tb/tb_top.sv

.PHONY: compile run wave clean

compile:
	@echo "TODO: compile the full CNN RTL pipeline with iverilog."
	# TODO: add the final compile command including the RTL and testbench files.

run:
	@echo "TODO: run the testbench with input_images.mem and golden_outputs.mem."
	# TODO: add the final simulation command.

wave:
	@echo "TODO: launch GTKWave with the CNN waveform configuration."
	# TODO: add the GTKWave launcher command.

clean:
	@rm -f *.vcd *.out *.log
