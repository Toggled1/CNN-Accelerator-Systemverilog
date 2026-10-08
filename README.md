# MNIST Convolutional Neural Network (CNN) in SystemVerilog

This is a convolutional neural network in SystemVerilog using fixed-point arithmetic and verified in simulation. Notably, this design is built for the MNIST dataset.


> **Status: work in progress.** Several RTL datapath blocks have local sanity tests. The majority of rtl modules are built. Still need to make the python model for checking/verif

## Contents

- [Project Overview](#project-overview)
- [Network Architecture](#network-architecture)
- [How Data Moves](#how-data-moves)
- [Fixed-Point Arithmetic](#fixed-point-arithmetic)
- [Verification and Current Status](#verification-and-current-status)
- [Repository Guide](#repository-guide)
- [Next Milestones](#next-milestones)

## Project Overview

This CNN is used for handwritten-digit classification on MNIST. A raw 28 x 28 image enters through a byte-wide interface. I used two convolutional layers to build the spatial features; ReLU and max pooling transform them; a dense layer produces ten class scores for each digit class; and argmax selects the digit with the largest score.

I began this project because while working with AI/ML engineers at my co-op at Solidigm (SK hynix), I became intersted in the intersection of machine learning and hardware acceleration. The AI tool of my choice while developing this project is copilot, w/ Sonnet 5.5 :)


## Network Architecture

The target network is deliberately small while still containing two learned convolutional stages:

```text
28 x 28 grayscale image
	|
	v
3 x 3 Conv1, 4 filters, valid padding
	|
       ReLU
	|
2 x 2 max pool, stride 2
	|
	v
3 x 3 Conv2, 8 filters, valid padding
	|
       ReLU
	|
       Flatten
	|
Dense: 968 features -> 10 logits
	|
      Argmax
	|
  predicted digit
```

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

Both convolutions use stride 1 and valid padding, so they do not add border pixels. Pooling uses a 2 x 2 region with stride 2 and never compares values from different channels. The final digit is a four-bit index in the range 0 through 9.

## How Data Moves

The planned top-level is a buffered, stage-sequenced design. It processes one image at a time and completes each stage before enabling the next; it is not a concurrent pipeline (YET).

### Image Input

The host asserts `start` while the controller is idle. The controller then raises `ready` while it is collecting the 784 image bytes. A byte is accepted only on a rising clock edge where both `pixel_valid` and `ready` are high. If `pixel_valid` pauses, the input count holds. Accepted bytes are stored in row-major order.

### Stage Processing

After the image is stored, the target sequence is:

1. **Conv1:** read the image through a 3 x 3 window generator and produce 676 four-channel locations.
2. **ReLU1:** scan those 676 locations, applying ReLU to all four channels at each location.
3. **Pool:** process 676 complete same-channel 2 x 2 blocks, producing a 13 x 13 x 4 map.
4. **Conv2:** assemble 121 windows, each containing 3 x 3 values across four channels, and produce eight outputs per location.
5. **ReLU2:** scan 121 locations, applying ReLU to all eight channels at each location.
6. **Flatten:** accept 121 eight-channel vectors and build a 968-value channel-major vector.
7. **Dense:** consume flat indices 0 through 967 and produce ten registered logits.
8. **Argmax:** select the largest signed logit; the top-level captures the result and signals completion.

Registered layers use valid signals to identify completed transfers. A layer with both `valid_in` and `enable` accepts its input when both are high at the active clock edge. There is no internal `ready` or backpressure signal: buffers retain data until its stage is active, and the controller is responsible for enabling a stage only when its input is available.

The window source is cleared when entering Conv1 and Conv2. ReLU is combinational and adds no separate module latency; the controller advances its spatial scan one location per enabled cycle. Flatten signals completion only after the full vector is assembled. Dense receives a separate initialization pulse before its first feature, then signals `dense_done` after the final feature has been accumulated.

### Buffers and Ordering

The design uses explicit intermediate storage to keep stage boundaries easy to inspect in simulation:

- 784 unsigned bytes for the input image
- 2,704 signed values for Conv1 (`26 x 26 x 4`)
- 676 signed values for the pooled map (`13 x 13 x 4`)
- 968 signed values for Conv2 (`11 x 11 x 8`)
- 968 signed values for the flattened vector
- ten 40-bit Dense accumulators

Spatial maps are stored location-major with channels adjacent. Flatten then performs a deliberate reorder to channel-major order, matching the Dense weight matrix. This avoids depending on a framework's default tensor layout.

The intended completion protocol is also explicit: `dense_done` qualifies stable logits; the top captures argmax on the clock edge while that signal is high; `done` is then a one-cycle indication that `predicted_digit` is valid. The digit remains stable until reset or another completed inference.

## Fixed-Point Arithmetic

The datapath uses integer encodings with named scales instead of floating-point values. In `Qm.n`, `n` is the number of fractional bits; the stored bit pattern is a signed two's-complement integer.

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

This is `floor(pixel / 2)`, zero-extended before being interpreted as signed Q1.7. For example, raw pixel 0 maps to 0, 128 maps to 64, and 255 maps to 127. This prevents bright pixels from being misread as negative values.

### Products and Accumulation

- **Conv1:** Q1.7 sample times Q1.7 weight produces a Q2.14 product. The Q6.14 bias already has the same 14 fractional bits, so it is added without a scale shift.
- **Conv2 and Dense:** Q6.14 feature times Q1.7 weight produces a Q7.21 product. The Q6.14 bias is shifted left by seven places to align it before accumulation.
- **Scale conversion:** Conv2 and Dense arithmetic-shift the completed sum right by seven bits to return to the Q6.14 encoding. No separate rounding constant is added.
- **Saturation:** Convolution outputs and Dense logits clamp to the signed 20-bit range, from -524,288 through 524,287. Values do not wrap around.
- **Activation:** ReLU maps a negative convolution result to zero and passes a nonnegative value unchanged. Dense logits do not pass through ReLU.

Using a 40-bit accumulator leaves headroom for the dot products before the results are narrowed to 20 bits. Explicit sign extension is part of the design contract; arithmetic should not depend on implicit expression sizing or host-language overflow.

### Parameter Quantization

The planned Python exporter will quantize weights to signed Q1.7 and biases to signed Q6.14. Values are rounded to nearest with ties away from zero, then saturated to the representable range. The integer reference is intended to reproduce the RTL's product widths, bias alignment, accumulation, arithmetic shift, saturation, ReLU, and pooling behavior exactly.


### Feature Maps

- Input pixels are row-major: `image_index = row * 28 + col`.
- Conv1 locations are row-major, with four channels contiguous at each location.
- Pooled values are ordered by pooled row, pooled column, then channel. Each group of four outputs belongs to the same pooled coordinate.
- Conv2 locations arrive row-major, with eight filter results in each vector.

### Conv2 Windows

A Conv2 window contains 36 samples. The ordering is channel first, then kernel row, then kernel column:

```text
window_index = channel * 9 + kernel_row * 3 + kernel_col
```

This same index selects the matching Conv2 weight. The producer supplies 121 windows in row-major output-location order.

### Flattened Features

Flatten receives one eight-channel vector for each row-major spatial location. It writes channel `ch`, row `r`, column `c` to:

```text
flat_index = ch * 121 + r * 11 + c
```

As a result, entries 0 through 120 are channel 0 at every location; entries 121 through 241 are channel 1; the final entry, 967, is channel 7 at location (10, 10). Dense weights use the corresponding class-major layout: each class owns one contiguous vector of 968 weights.

### Exported Parameters

The target export contains 10,026 scalar parameters:

| Parameter group | Count |
|---|---:|
| Conv1 weights and biases | 36 weights + 4 biases |
| Conv2 weights and biases | 288 weights + 8 biases |
| Dense weights and biases | 9,680 weights + 10 biases |

Weights are stored as signed 8-bit two's-complement values using two hexadecimal digits per line. Biases are signed 20-bit values using five digits per line. The intended files are `conv1_weights.mem`, `conv2_weights.mem`, `dense_weights.mem`, and `biases.mem`; the bias file orders Conv1, Conv2, then Dense biases. `weights_mem` is intended to expose typed arrays with combinational indexing and no clocked memory latency.

## Verification and Current Status

Eventually might build a UVM environment to verify the design. Right now the tests are simple and most were created with copilot ai for faster development

### Available Sanity Tests

Icarus Verilog is used for the current isolated module checks. Run the configured set from the repository root:

```sh
make -C sim unit-test
```

The target covers:

- Argmax signed comparison and lowest-index tie handling
- Conv1 and Conv2 transfer timing, bias behavior, and a directed MAC result
- Dense start, 968 accepted features, bias-only logits, and completion pulse
- Flatten location-vector acceptance and channel-major output ordering
- Pooling signed maximum and valid timing
- Known-value checks for all `weights_mem` outputs

At this revision, the Argmax, Conv1, Conv2, Dense, Flatten, and Pooling benches pass. The `weights_mem` bench fails because the module does not yet initialize its arrays. Existing line-buffer and ReLU benches are also present, but the main top-level bench is still only a smoke-test scaffold.

### Integration Work Remaining


- `control_fsm.sv` still needs the state sequencing, transfer counters, and output control required by the protocol.
- `weights_mem.sv` needs to load and validate the typed parameter arrays.
- The Python model, quantizer/export helpers, and real parameter/input/reference files are placeholders.
- The top-level testbench does not yet stream a complete image and compare RTL outputs against an integer reference.
- End-to-end logits, prediction agreement, and dataset accuracy have not been measured.

My intended final verification will compare all ten logits and predicted digits against the bit-accurate reference, then score classification separately against MNIST labels.

## Repository Guide

| Path | Purpose |
|---|---|
| `rtl/` | SystemVerilog datapath modules and the top-level integration |
| `model/` | Planned CNN definition, quantization, and memory-file exporter |
| `tb/` | Module-level and top-level simulation testbenches |
| `tb/test_vectors/` | Planned weights, images, reference predictions, and labels |
| `sim/` | Icarus compile/run workflow and waveform configuration |
| `README.md` | What you are reading right now :) |
| `IMPLEMENTATION_PLAN.md` | Phased engineering and verification plan |

## Next Milestones

1. Implement and test parameter-memory loading, including exact file counts and known-value checks.
2. Implement the FSM with the specified reset, ready/valid, transfer-count, and one-cycle completion behavior.
3. Complete the Python model, fixed-point reference, serializer, and real deterministic fixtures.
4. Add directed tensor-order and arithmetic tests where current sanity benches are intentionally small.
5. Run an end-to-end image through every stage and compare logits and prediction against the integer reference.
6. Expand the top-level regression and CI only after the deterministic fixture flow is available.
