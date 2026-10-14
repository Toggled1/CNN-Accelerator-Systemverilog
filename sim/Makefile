# Compile, unit-test, and run the end-to-end MNIST CNN RTL simulation.

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
RUN_ARGS ?=
UNIT_TESTS = argmax control_fsm conv_layer_1 conv_layer_2 dense_layer flatten_layer line_buffer pooling_layer relu weights_mem

.PHONY: all test compile run wave unit-test clean

all: test

test: unit-test run

compile: $(SIM_OUT)

$(SIM_OUT): $(RTL_SRC) $(TB_SRC) Makefile
	@echo "Compiling CNN RTL integration test..."
	$(IVERILOG) -g2012 -Wall -Wno-timescale -s tb_top -o $(SIM_OUT) $(RTL_SRC) $(TB_SRC)

run: compile
	@echo "Running end-to-end CNN RTL regression..."
	$(VVP) $(SIM_OUT) $(RUN_ARGS)

wave: compile
	$(VVP) $(SIM_OUT) +images=1 +start=0 +dump
	@echo "Launching GTKWave..."
	$(GTKWAVE) $(VCD_OUT) wave_config.gtkw

unit-test:
	@set -e; \
	for test_name in $(UNIT_TESTS); do \
		echo "Running tb_$$test_name..."; \
		$(IVERILOG) -g2012 -Wall -Wno-timescale -s tb_$$test_name -o /tmp/g_cnn_tb_$$test_name.out ../rtl/$$test_name.sv ../tb/tb_$$test_name.sv; \
		$(VVP) /tmp/g_cnn_tb_$$test_name.out; \
	done

clean:
	@rm -f *.vcd *.out *.log
