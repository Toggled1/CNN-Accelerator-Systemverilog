# Minimal compile/run/wave workflow for the MNIST CNN RTL simulation.
# The design is intentionally still a smoke-test placeholder for Phase 1.

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
SIM_OUT = cnn_tb.out
VCD_OUT = cnn_smoke.vcd

.PHONY: compile run wave clean

compile: $(SIM_OUT)

$(SIM_OUT): $(RTL_SRC) $(TB_SRC)
	@echo "Compiling CNN RTL smoke test..."
	$(IVERILOG) -g2012 -Wall -Wno-timescale -s tb_top -o $(SIM_OUT) $(RTL_SRC) $(TB_SRC)

run: compile
	@echo "Running CNN RTL smoke test..."
	$(VVP) $(SIM_OUT)

wave: run
	@echo "Launching GTKWave..."
	$(GTKWAVE) $(VCD_OUT) wave_config.gtkw

clean:
	@rm -f *.vcd *.out *.log
