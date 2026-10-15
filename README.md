# MNIST Convolutional Neural Network (CNN) in SystemVerilog

This is a convolutional neural network in SystemVerilog using fixed-point arithmetic and verified in simulation. Notably, this design is built for the MNIST dataset.


![MNIST CNN network diagram](assets/network_gridlines.png)
**Conv1 -> ReLU1 -> MaxPool -> Conv2 -> ReLU2 -> Flatten -> Dense -> Argmax**

## Contents

- [Project Overview](#project-overview)
- [Network Architecture](#network-architecture)
- [How Data Moves](#how-data-moves)
	- [Image Input](#image-input)
	- [Tensor Ordering](#tensor-ordering)
- [Fixed-Point Arithmetic](#fixed-point-arithmetic)
	- [Pixel Conversion](#pixel-conversion)
	- [Products and Accumulation](#products-and-accumulation)
	- [Quantization](#quantization)
	- [Exported Parameters](#exported-parameters)
- [Run the Simulation](#run-the-simulation)
- [Repository Guide](#repository-guide)
- [Next Steps](#next-steps)

## Project Overview

I started this project to explore how machine learning can be implemented in hardware. This is a SystemVerilog CNN that classifies MNIST digits using fixed-point arithmetic, checked against a bit-accurate Python reference model made with numpy. The design takes a row-major 28 x 28 grayscale image and predicts a digit from 0 to 9.

## Network Architecture

Each image passes through Conv1, ReLU, 2 x 2 max pooling, Conv2, ReLU, channel-major flattening, a dense classifier, and argmax.

| Stage | Input | Output | Role |
|---|---:|---:|---|
| Image input | 28 x 28 x 1 | 28 x 28 x 1 | Accept raw unsigned pixel bytes |
| Conv1 | 28 x 28 x 1 | 26 x 26 x 4 | Extract local image features |
| ReLU1 | 26 x 26 x 4 | 26 x 26 x 4 | Remove negative activations |
| MaxPool | 26 x 26 x 4 | 13 x 13 x 4 | Downsample each channel independently |
| Conv2 | 13 x 13 x 4 | 11 x 11 x 8 | Combine spatial and channel features |
| ReLU2 | 11 x 11 x 8 | 11 x 11 x 8 | Apply the second activation |
| Flatten | 11 x 11 x 8 | 968 values | Reorder features for classification |
| Dense | 968 values | 10 logits | Produce one score per digit |
| Argmax | 10 logits | 1 digit index | Select the highest-scoring class |

Both convolutions use stride 1 and valid padding. Pooling uses stride 2 and operates independently on each channel. The four-bit output is a class index from 0 to 9.

## How Data Moves

The top level buffers one image and processes one stage at a time; it is not a streaming pipeline. [ might be eventually in version 2 :) ]

### Image Input

The host (tb in sim) asserts `start` while the controller is in the IDLE state. The control FSM then asserts `ready` while it is collecting the 784 image bytes. A byte is accepted only on a rising clock edge where both `pixel_valid` and `ready` are high. If `pixel_valid` pauses, the input count holds.

The control FSM sequences each stage after its input map is available. Transfers are accepted on a rising edge when `enable` and the corresponding `valid` are high. Buffers hold the maps between stages... Keep in mind, I haven't given the design internal backpressure. ReLU is combinational. Dense has a separate start pulse, asserts `dense_done` after the final feature, and the top-level asserts `done` for one cycle with `predicted_digit` valid.

### Tensor Ordering

Images and spatial maps are row-major, with channels adjacent at each location. Conv2 windows and weights use channel-major kernel order:

```text
window_index = channel * 9 + kernel_row * 3 + kernel_col
```

Flatten reorders the 11 x 11 x 8 Conv2 map to channel-major order to match the dense weights:

```text
flat_index = channel * 121 + row * 11 + column
```

## Fixed-Point Arithmetic

The datapath uses signed integer encodings. In `Qm.n`, `n` is the number of fractional bits.

| Quantity | RTL representation | Scale |
|---|---|---|
| Raw input pixel | unsigned 8-bit | integer 0 to 255 |
| Converted input sample | signed 8-bit | Q1.7 |
| Convolution and Dense weights | signed 8-bit | Q1.7 |
| Biases | signed 20-bit | Q6.14 |
| Activations, pooled values, logits | signed 20-bit | Q6.14 |
| MAC accumulator | signed 40-bit | stage-dependent product scale |

### Pixel Conversion

The incoming pixel remains unsigned. The datapath converts it using:

```text
sample_q7 = pixel_in[7:1]
```

This is `floor(pixel / 2)`, zero-extended as a signed Q1.7 sample. Thus 0 maps to 0, 128 to 64, and 255 to 127.

### Products and Accumulation

- **Conv1:** Q1.7 x Q1.7 produces Q2.14; the Q6.14 bias needs no shift.
- **Conv2 and Dense:** Q6.14 x Q1.7 produces Q7.21; shift the Q6.14 bias left by 7 before accumulation, then arithmetic-shift the sum right by 7.
- **Accumulation and saturation:** MACs use 40 bits. Outputs saturate to signed 20-bit range (-524,288 to 524,287), rather than wrapping.
- **Activation:** ReLU follows each convolution; Dense logits are not rectified.

### Quantization

The Python exporter quantizes weights to signed Q1.7 and biases to signed Q6.14. It rounds to nearest with ties away from zero, then saturates to the representable range. The integer reference uses the same bias alignment, shifts, saturation, ReLU, and pooling rules as the RTL.

### Exported Parameters

The export contains 10,026 parameters:

| Parameter group | Count |
|---|---:|
| Conv1 weights and biases | 36 weights + 4 biases |
| Conv2 weights and biases | 288 weights + 8 biases |
| Dense weights and biases | 9,680 weights + 10 biases |

Weights are signed 8-bit two's-complement values (two hex digits per value); biases are signed 20-bit values (five digits). The files are `conv1_weights.mem`, `conv2_weights.mem`, `dense_weights.mem`, and `biases.mem`; biases are ordered Conv1, Conv2, then Dense.

## Run the Simulation

Prerequisites: `iverilog` and `vvp`; install `gtkwave` only if you want waveforms. Run commands from the repository root.

```sh
# Run all unit tests and the 100-image RTL regression
./sim/run_sim.sh

# Run only the module-level tests
make -C sim unit-test

# Run only the 100-image RTL regression
make -C sim run

# Run the first test image and open its waveform (requires GTKWave)
make -C sim wave

# Remove generated simulator files
make -C sim clean
```

The full regression compares RTL predictions with the committed golden outputs and reports MNIST label accuracy. Fixtures are already included. To regenerate them, install `model/requirements.txt` in your Python environment and run `python model/train_and_export.py`; it retrains for five epochs and overwrites the fixtures.

## Repository Guide

| Path | Purpose |
|---|---|
| `rtl/` | SystemVerilog datapath modules and the top-level integration |
| `model/` | Float training model, fixed-point reference model, quantization, and memory-file exporter |
| `tb/` | Module-level and top-level simulation testbenches |
| `tb/test_vectors/` | Generated/created weights, images, reference predictions, and labels |
| `sim/` | Icarus compile/run workflow and waveform configuration |
| `README.md` | Project and simulation guide |

## Next Steps

1. Extend the top-level regression to compare all ten RTL logits against the integer reference.
2. Add broader end-to-end corner cases and run the simulation suite in CI.
