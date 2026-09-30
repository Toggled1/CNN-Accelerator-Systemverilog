# TODO: implement the simulation build flow described in README.md Section 11.
# Required targets:
# - compile: compile the SystemVerilog RTL design
# - run: execute the self-checking testbench
# - wave: open GTKWave for debugging

IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

RTL_SRC = ../rtl/top_classifier.sv ../rtl/control_fsm.sv ../rtl/line_buffer.sv ../rtl/mac_unit.sv ../rtl/relu.sv ../rtl/dense_layer.sv ../rtl/argmax.sv ../rtl/weights_mem.sv
TB_SRC = ../tb/tb_top.sv

.PHONY: compile run wave clean

compile:
	@echo "TODO: compile the RTL and testbench with iverilog."
	# TODO: add the correct compile command for the final implementation.

run:
	@echo "TODO: run the testbench and validate predictions against golden_outputs.mem."
	# TODO: add the correct run command for the final implementation.

wave:
	@echo "TODO: launch GTKWave with the waveform configuration from wave_config.gtkw."
	# TODO: add the waveform launch command.

clean:
	@rm -f *.vcd *.out
