# MNIST CNN Accelerator in RTL

This repository implements a compact, simulation-only convolutional neural network for MNIST digit classification. The design combines Python-based model export with SystemVerilog RTL logic and a self-checking digital simulation flow.

This document is the single authoritative project specification for the repository. It defines the architecture, layer stack, numerical conventions, module responsibilities, exported memory format, verification rules, and final repository layout. All implementation work should be aligned to this document.

> Project constraint: this project is strictly simulation-only. It is not intended for FPGA deployment, synthesis targeting, or physical hardware fabrication. The design is meant to be validated using open-source HDL simulators such as iverilog or Verilator.

---

## 1. Project Goal

The goal of this project is to implement a small but real convolutional neural network that classifies handwritten digits from the MNIST dataset. The project is intended to demonstrate:

- MNIST-based dataset processing
- convolutional feature extraction in hardware-oriented logic
- ReLU activation and pooling behavior
- fixed-point arithmetic in RTL
- dense classification and argmax output selection
- Python-to-hardware parameter export
- simulation-driven verification in a GitHub-ready repository

This project is designed to be realistic, technically credible, and achievable within a portfolio-friendly scope without requiring an ASIC or FPGA workflow.

---

## 2. Scope and Design Philosophy

This project is intentionally designed as a small CNN, not a large deep-learning accelerator. It has enough network structure to count as a real convolutional network while remaining small enough to understand, simulate, and verify in a manageable way.

### In scope

- MNIST classification using a small CNN
- Python-based model training and export of weights and biases
- SystemVerilog RTL design for convolution, activation, pooling, flatten, dense, and argmax stages
- simulation verification against known golden outputs
- GitHub-ready project layout and documentation

### Out of scope

- FPGA deployment
- board-level hardware integration
- synthesis or timing closure
- large-scale CNN optimization
- real-time hardware acceleration on physical silicon
- production ASIC design

---

## 3. CNN Architecture Overview

The network is structured as a compact convolutional pipeline suitable for simulation and verification.

```text
[ MNIST 28x28 image ]
        |
        v
[ Conv Layer 1: 3x3, 4 filters ]
        |
        v
[ ReLU ]
        |
        v
[ Max Pool 2x2 ]
        |
        v
[ Conv Layer 2: 3x3, 8 filters ]
        |
        v
[ ReLU ]
        |
        v
[ Flatten ]
        |
        v
[ Dense Layer: 10 logits ]
        |
        v
[ Argmax ]
        |
        v
[ Predicted Digit ]
```

This is a real CNN structure with multiple learned stages rather than a single window-based feature detector.

---

## 4. Dataset Specification

### 4.1 Dataset

- MNIST handwritten digits dataset
- input shape: 28 x 28 grayscale image
- pixel range: 0 to 255
- total classes: 10 labels, 0 through 9

### 4.2 Data convention

- pixel values are flattened in row-major order for hardware streaming
- input data is represented in 8-bit format during simulation
- each image is processed individually in a one-image-at-a-time inference cycle

---

## 5. Numerical Representation

The design uses signed fixed-point integer arithmetic to remain hardware-friendly and easy to validate.

### 5.1 Bit widths and fixed-point formats

All fixed-point values are signed two's-complement integers. `Qm.n` below means `n` fractional bits; `m` counts the remaining integer bits, including the sign bit.

- raw MNIST pixel input: `logic [7:0]`, unsigned integer in 0..255
- signed input sample: `logic signed [7:0]`, Q1.7
- convolution and dense weights: `logic signed [7:0]`, Q1.7
- biases: `logic signed [19:0]`, Q6.14
- MAC accumulator: `logic signed [39:0]`, used for every convolution and dense dot product
- ReLU activation and pooled value: `logic signed [19:0]`, Q6.14
- class logit / score: `logic signed [19:0]`, Q6.14
- final output digit index: `logic [3:0]`, with legal values 0..9

The signed Q1.7 range is -1 through 127/128. The signed Q6.14 range is -32 through 524287/16384. These are the stored integer encodings; arithmetic must preserve the stated fractional-bit scale.

### 5.2 Input conversion and MAC arithmetic

The unsigned input byte is converted without signed reinterpretation:

```text
sample_q7 = pixel_in[7:1]
```

This is the unsigned integer division `floor(pixel_in / 2)`, represented as signed Q1.7. Thus raw pixel 0 maps to 0, 127 maps to 63, 128 maps to 64, and 255 maps to 127. The value is zero-extended before it is treated as signed, so every converted input sample is nonnegative.

Weights use Q1.7. Biases, stored activations, pooled values, and logits use Q6.14. Products and sums follow these rules:

- Conv1 multiplies Q1.7 samples by Q1.7 weights, producing Q2.14 products. Sum the products and the Q6.14 bias in the 40-bit accumulator; both have 14 fractional bits, so no shift is needed before narrowing.
- Conv2 and Dense multiply Q6.14 activations/features by Q1.7 weights, producing Q7.21 products. Add the Q6.14 bias shifted left by 7 to align it to Q7.21, and accumulate in 40 bits.
- For Conv2 and Dense, arithmetic-right-shift the completed Q7.21 sum by 7. This is floor rounding for signed values and yields a Q6.14 integer encoding. Do not add a separate rounding constant.
- After the scale conversion, saturate each convolution result to the signed 20-bit range before the ReLU stage. Saturation clamps to -524288 or 524287; it never wraps. Conv1 saturation uses its Q6.14 sum directly. Conv2 saturation follows the arithmetic right shift.
- ReLU then maps a negative saturated convolution result to zero and passes a nonnegative value unchanged. Max-pooling compares these signed Q6.14 encodings and passes the selected value unchanged.
- Dense uses the same Q7.21 product, bias alignment, 40-bit accumulation, arithmetic right shift, and signed 20-bit saturation. Dense logits are not passed through ReLU.

The 40-bit accumulator is deliberately wider than the stored activation and logit values. With signed 20-bit features, signed 8-bit weights, at most 968 dense terms, and the aligned 20-bit bias, the worst-case sum fits in signed 40-bit range. All operands must be explicitly sign-extended to the accumulator width; do not rely on implicit SystemVerilog expression sizing.

### 5.3 Parameter quantization and export

The Python exporter uses the same fixed-point scales and limits as the RTL:

- Convert each floating-point weight to signed Q1.7 by multiplying by 128, rounding to nearest with ties away from zero, and saturating to [-128, 127].
- Convert each floating-point bias to signed Q6.14 by multiplying by 16384, rounding to nearest with ties away from zero, and saturating to [-524288, 524287].
- Encode exported weights as signed 8-bit two's-complement values and biases as signed 20-bit two's-complement values. The text-file hex width and `$readmemh` representation must be specified consistently by the export implementation.
- The input image remains unsigned 8-bit raw pixel data in its memory file; apply the Q1.7 conversion in the RTL datapath and in the integer reference, not in the input-file serializer.
- The Python integer reference must reproduce each RTL product width, bias alignment, 40-bit accumulation, arithmetic shift, saturation, ReLU, and pooling operation exactly. Model quantization and inference must not depend on host-language overflow behavior.

Parameter saturation is explicit: values outside the representable range clamp to the nearest endpoint. Activation/logit saturation is also explicit and never wraps. These rules are part of the Python-to-RTL numerical contract.

---

## 6. CNN Layer Specification

### 6.1 Convolutional layer 1

Purpose: extract low-level visual features from the MNIST input image.

Recommended configuration:

- input size: 28 x 28 x 1
- kernel size: 3 x 3
- number of filters: 4
- stride: 1
- padding: valid
- output size: 26 x 26 x 4

Behavior:

- each output pixel is computed by sliding a 3x3 window over the input
- each filter applies a unique set of 9 weights and one bias
- output activations are accumulated in the 40-bit signed MAC accumulator defined in Section 5

### 6.2 ReLU layer 1

Purpose: apply non-linearity after convolution.

Behavior:

```text
if activation < 0 then output = 0
else output = activation
```

### 6.3 Max pooling layer

Purpose: reduce spatial resolution while preserving dominant activations.

Recommended configuration:

- pool size: 2 x 2
- stride: 2
- output size: 13 x 13 x 4

### 6.4 Convolutional layer 2

Purpose: extract higher-level patterns from the pooled feature maps.

Recommended configuration:

- input size: 13 x 13 x 4
- kernel size: 3 x 3
- number of filters: 8
- stride: 1
- padding: valid
- output size: 11 x 11 x 8
- input samples: 36 signed Q6.14 values for one 3 x 3 window across four channels
- weights: 8 filters x 36 signed Q1.7 values
- output: eight signed Q6.14 values, one per filter, for each accepted spatial window

### 6.5 ReLU layer 2

Purpose: apply a second non-linear activation stage.

### 6.6 Flatten layer

Purpose: convert the 2D feature maps into a 1D vector for the dense classifier.

Shape:

- 11 x 11 x 8 = 968 values

### 6.7 Dense classifier layer

Purpose: map the flattened features to 10 class logits.

Configuration:

- input size: 968
- output size: 10 logits
- output type: signed 20-bit class scores

### 6.8 Argmax output

Purpose: identify the largest class score.

Behavior:

```text
predicted_digit = argmax(logits[0:9])
```

The result is a 4-bit digit index from 0 to 9.

---

## 7. Fixed-Point and Dataflow Rules

The export script and RTL design must use the same conventions.

### Required conventions

- all model parameters are serialized in a consistent order
- weights and biases are exported in fixed-point integer format
- each convolutional stage uses a fixed kernel layout
- dense-layer ordering matches the exported weight matrix ordering
- ReLU and pooling are executed at the correct stage boundaries
- all class logits are compared using the same signed interpretation

### 7.1 Dataflow model: streaming CNN, neighborhood-based stages

This project is designed as a streaming CNN datapath. The image, feature-map values, and intermediate activations move through the pipeline over clock cycles. The stages are not implemented as a single monolithic combinational block that receives the whole network at once.

The important clarification is:

- the CNN as a whole is streaming
- however, some stages operate on a local neighborhood (for example, a 3x3 receptive field or a 2x2 pooling window)
- those neighborhoods are represented in RTL as local arrays such as `window[0:8]` or `pool_block[0:3]`
- those arrays are temporary working buffers used to accumulate the local region before producing one output activation or one pooled value
- the same protocol is used everywhere: one valid sample or one valid local neighborhood per cycle, with the result emitted only after the neighborhood is complete

This means the design is not a "full tensor passed all at once" model. Instead, it is a valid/ready streaming pipeline where a local neighborhood is assembled over time and then processed once complete.

### 7.1.1 Final protocol choice for the repository

The project chooses the following single, consistent protocol:

- the image is streamed one pixel at a time into the CNN
- `line_buffer` assembles a 3x3 receptive field from the stream and emits one `window_valid` pulse when the window is ready
- each convolution stage consumes one complete receptive field and emits one valid output activation per filter or per output location
- ReLU is applied per activation sample, one value at a time
- pooling is performed on a 2x2 local neighborhood assembled from the stream and emits one pooled value when the block is complete
- the dense stage consumes flattened values in sequence and computes the logits

This is the final protocol contract for the repository. Array-based local buffers like `window[0:8]` and `pool_block[0:3]` are storage for a local neighborhood, not evidence that the whole tensor is transferred in one cycle.

### 7.2 Exact stage semantics

#### ReLU stage semantics

ReLU is a per-sample scalar operation. It is applied to one activation value at a time.

```text
if x < 0 then output = 0
else output = x
```

This is a single-value operation and does not require a multi-sample neighborhood. In RTL, this is naturally implemented as a per-cycle scalar comparison and assignment.

#### Pooling stage semantics

Pooling is a neighborhood operation. For a 2x2 max-pool block:

```text
output = max(block[0], block[1], block[2], block[3])
```

The 2x2 block is assembled from four neighboring activations. Once all four values are present, the max is computed and one pooled output is emitted. This is the only stage in the pipeline that operates over a local 2x2 neighborhood instead of a single scalar value.

### 7.3 Local array interpretation in RTL

The following array conventions are used in the RTL skeleton for clarity and consistency:

- `window[0:8]` means a 3x3 receptive field buffer for a convolution window
- `pool_block[0:3]` means a 2x2 local pooling block buffer
- these arrays are local working structures, not evidence that the entire tensor is passed as a single monolithic object in one cycle

In other words, the stage still belongs to a streaming design, but it holds a small local neighborhood in temporary storage while computing one output value.

### 7.4 Interface contract for the actual implementation

The dataflow contract should be interpreted as follows:

FSM order: `IDLE -> LOAD_IMAGE -> CONV1 -> RELU1 -> POOL -> CONV2 -> RELU2 -> FLATTEN -> DENSE -> DONE`

1. `start` is asserted to begin one inference pass.
2. The image is streamed in row-major order as 8-bit values.
3. The line buffer assembles a valid 3x3 neighborhood for the convolution stage.
4. Conv1 produces 4 output feature maps.
5. ReLU1 is applied to each Conv1 activation value.
6. The pool stage assembles a 2x2 region and emits one max-pooled value.
7. Conv2 consumes the pooled feature map values and produces 8 output channels.
8. ReLU2 is applied to each Conv2 activation value.
9. Flatten generates the 968-element vector.
10. Dense computes 10 logits.
11. Argmax selects the winning class.
12. `done` is asserted once the final class is valid.

This defines the intended pipeline clearly: it is a streaming CNN, while the local convolution and pooling stages operate over small neighborhoods that are temporarily buffered in arrays.

---

## 7.1 Design Freeze: Exact CNN Pipeline Contract

This section is the implementation contract for the actual design. It is intentionally explicit so that code and export files do not drift apart.

### 7.1.1 Layer geometry

The CNN is fixed to the following architecture:

- Input image: 28 x 28 x 1
- Conv1: 3 x 3 kernel, 4 filters, stride 1, valid padding, output = 26 x 26 x 4
- ReLU1
- MaxPool2: 2 x 2 window, stride 2, output = 13 x 13 x 4
- Conv2: 3 x 3 kernel, 8 filters, stride 1, valid padding, output = 11 x 11 x 8
- ReLU2
- Flatten: 11 x 11 x 8 = 968 values
- Dense: 968 -> 10 logits
- Argmax: output class index 0..9

### 7.1.2 Line buffer semantics

The `line_buffer.sv` module is not a separate CNN stage. It is a helper module that supplies sliding 3x3 receptive fields to the convolution stages. Its purpose is to hold enough previous rows to generate a 3x3 window for each valid pixel position.

This means:

- `line_buffer` is used for Conv1 input generation
- the max-pool layer operates on the Conv1 output feature map
- the same general windowing principle is used for Conv2 on the pooled feature map
- the buffer logic is only responsible for generating receptive fields; it does not replace the conv layers themselves

### 7.1.3 Equation contract

For Conv1, for each filter `f` and output location `(r, c)`: 

```text
out1[f][r][c] = ReLU( sum_{ky=0..2} sum_{kx=0..2} input[r+ky][c+kx] * W1[f][ky][kx] + b1[f] )
```

For Conv2, for each filter `f2` and output location `(r, c)`: 

```text
out2[f2][r][c] = ReLU( sum_{ch=0..3} sum_{ky=0..2} sum_{kx=0..2} pooled[r+ky][c+kx][ch] * W2[f2][ch][ky][kx] + b2[f2] )
```

In `conv_layer_2.sv`, one complete receptive field is represented by `window[0:35]`, and its weights by `filter_weights[0:7][0:35]`. The single flat position for channel `ch`, kernel row `ky`, and kernel column `kx` is `ch * 9 + ky * 3 + kx`:

```text
window[ch * 9 + ky * 3 + kx] = pooled[r + ky][c + kx][ch]
filter_weights[f2][ch * 9 + ky * 3 + kx] = W2[f2][ch][ky][kx]
```

The channel-major, row-major, column-major order matches the Conv2 weight-file order defined below. `valid_in` qualifies one complete 36-value window. On a rising edge where `rst_n`, `enable`, and `valid_in` are all high, the module accepts that window; it registers all eight saturated Q6.14 MAC results together and asserts `valid_out` for the following cycle. It can accept one window per clock when enabled. The registered results are the pre-ReLU convolution values; the separate ReLU stage produces `out2` in the equation above. The window producer must provide exactly 121 windows per image, in row-major output-location order.

For the dense output logits:

```text
logits[k] = sum_{i=0..967} flat[i] * denseW[k][i] + denseB[k]
```

with:

```text
predicted_digit = argmax(logits[0:9])
```

### 7.1.4 Exact parameter counts

The architecture implies the following parameter counts:

- Conv1 weights: 4 filters * 3 x 3 kernel = 36 values
- Conv1 biases: 4 values
- Conv2 weights: 8 filters * 4 input channels * 3 x 3 kernel = 288 values
- Conv2 biases: 8 values
- Dense weights: 10 classes * 968 inputs = 9,680 values
- Dense biases: 10 values

This is the expected total parameter footprint for the export script.

### 7.1.5 Memory ordering contract

The export script and RTL memory files must follow one fixed memory layout. The following order is required and must be used consistently in Python generation and hardware reading.

The parameter memory is addressed as a flat 1D read-only array. The total parameter count is 10,026 values, so the memory address width must be at least 14 bits to cover a range of 0..10,025. The RTL skeleton therefore uses a 14-bit address bus for the parameter ROM interface.

#### Conv1 weights memory layout

```text
conv1_weights.mem = [
  filter0[0][0], filter0[0][1], ..., filter0[2][2],
  filter1[0][0], filter1[0][1], ..., filter1[2][2],
  filter2[0][0], ..., filter2[2][2],
  filter3[0][0], ..., filter3[2][2]
]
```

Each kernel entry is an 8-bit signed integer.

#### Conv2 weights memory layout

```text
conv2_weights.mem = [
  filter0[ch0 kernel 9 values], filter0[ch1 kernel 9 values], filter0[ch2 kernel 9 values], filter0[ch3 kernel 9 values],
  filter1[ch0 ...], filter1[ch1 ...], ...,
  ...
  filter7[ch0 ...], filter7[ch1 ...], filter7[ch2 ...], filter7[ch3 ...]
]
```

Each kernel entry is an 8-bit signed integer.

#### Dense weights memory layout

```text
dense_weights.mem = [
  class0[input0..input967],
  class1[input0..input967],
  ...
  class9[input0..input967]
]
```

This means each output class is stored as a contiguous vector of 968 weights.

#### Bias memory layout

```text
biases.mem = [
  conv1_bias[0..3],
  conv2_bias[0..7],
  dense_bias[0..9]
]
```

This ordering must match how the RTL reads the bias parameters.

### 7.1.6 Flatten ordering contract

The flattened vector must be deterministic and match the exact export order used by the dense-layer weight matrix.

The required flatten order is:

```text
for each output channel ch in 0..7:
  for each row r in 0..10:
    for each column c in 0..10:
      flattened_vector.push(conv2_out[ch][r][c])
```

This corresponds to a channel-major, row-major, column-major layout.

### 7.1.7 Handshake and stage sequencing

The design must use a deterministic sequential pipeline with explicit valid/ready behavior:

1. `start` is asserted to begin one inference pass.
2. The image is streamed in row-major order as 8-bit values.
3. The line buffer assembles a 3x3 receptive field and asserts `window_valid` when the window is complete.
4. Conv1 consumes each valid 3x3 window and produces 4 output activations for that spatial location.
5. ReLU1 runs on each Conv1 activation value as it is produced.
6. Pooling assembles a 2x2 block and emits one valid pooled value only after all four inputs in the block have arrived.
7. Conv2 consumes pooled windows and produces 8 output channels.
8. ReLU2 runs on the Conv2 outputs.
9. Flatten generates the 968-element vector in the channel-major, row-major, column-major order defined above.
10. Dense computes 10 logits.
11. Argmax selects the winning digit.
12. `done` is asserted once the final class is valid.

The important point is that no stage should silently reorder or reinterpret the output tensor without matching the same indexing convention in Python and RTL.

---

## 8. Repository Structure

```text
mnist-cnn-rtl-sim/
├── .github/
│   └── workflows/
│       └── ci.yml                   # GitHub Actions simulation workflow
├── model/
│   ├── train_and_export.py        # Python training and export flow
│   ├── requirements.txt            # Python dependencies
│   ├── mnist_model.py              # CNN model definition
│   └── export_utils.py             # serialization and memory formatting helpers
├── rtl/
│   ├── top_classifier.sv           # top-level CNN classifier
│   ├── control_fsm.sv              # FSM for conv -> relu -> pool -> dense flow
│   ├── line_buffer.sv              # sliding window for 3x3 receptive fields
│   ├── conv_layer_1.sv             # first convolution stage
│   ├── conv_layer_2.sv             # second convolution stage
│   ├── pooling_layer.sv            # 2x2 max-pool stage
│   ├── relu.sv                    # ReLU activation stage
│   ├── flatten_layer.sv            # flattened feature vector builder
│   ├── dense_layer.sv              # 968 -> 10 class score stage
│   ├── argmax.sv                   # winning digit selection
│   └── weights_mem.sv              # model parameter memory
├── tb/
│   ├── tb_top.sv                   # self-checking RTL testbench
│   └── test_vectors/
│       ├── conv1_weights.mem       # first convolution weights
│       ├── conv2_weights.mem       # second convolution weights
│       ├── dense_weights.mem       # dense-layer weights
│       ├── biases.mem               # bias values for conv and dense stages
│       ├── input_images.mem         # MNIST image data in hex
│       └── golden_outputs.mem       # expected digit labels
├── sim/
│   ├── Makefile                    # compile and run commands
│   ├── run_sim.sh                  # simulation automation script
│   └── wave_config.gtkw            # GTKWave signal configuration
├── README.md                       # canonical project specification
├── LICENSE                         # optional project license
└── .gitignore                      # generated-file exclusions
```

This structure is explicit and reflective of a small but real CNN pipeline.

---

## 9. Module Specifications

### 9.1 `model/train_and_export.py`

Purpose: train or load a small CNN model and export fixed-point parameters for the hardware simulation.

Responsibilities:

- load MNIST data
- define or train a compact CNN with convolution and dense stages
- convert floating-point weights to signed 8-bit values
- export all parameter arrays into memory files
- generate validation vectors and expected outputs

Expected outputs:

- conv1_weights.mem
- conv2_weights.mem
- dense_weights.mem
- biases.mem
- input_images.mem
- golden_outputs.mem

This script is the source of truth for the numerical values used by the RTL environment.

---

### 9.2 `rtl/top_classifier.sv`

Purpose: top-level CNN inference module for MNIST classification.

Example interface:

```systemverilog
module top_classifier (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [7:0]  pixel_in,
    input  logic        pixel_valid,
    output logic        ready,
    output logic        done,
    output logic [3:0]  predicted_digit
);
endmodule
```

Responsibilities:

- initialize and control the inference cycle
- coordinate the flow through both convolution stages, pooling, flatten, dense layer, and argmax
- manage valid/ready signaling for the image stream
- provide the final digit once the network finishes processing

---

### 9.3 `rtl/control_fsm.sv`

Purpose: coordinate the full CNN inference flow.

Required states:

- IDLE
- LOAD_IMAGE
- CONV1
- RELU1
- POOL
- CONV2
- RELU2
- FLATTEN
- DENSE
- DONE

Responsibilities:

- wait for the `start` signal
- stream image pixels into the convolution pipeline
- trigger the appropriate activation and pooling stages
- hand off the flattened feature vector to the dense classifier
- assert `done` when the final prediction is valid

---

### 9.4 `rtl/line_buffer.sv`

Purpose: maintain enough image history to generate the 3x3 sliding window for convolution.

Required behavior:

- keep previous rows required for a local 3x3 neighborhood
- output nine pixels per valid convolution window
- ensure no invalid window is generated before sufficient data exists

---

### 9.5 `rtl/conv_layer_1.sv`

Purpose: compute the first feature map using a 3x3 kernel and 4 filters.

Required behavior:

- accept a 28x28 input image window and generate 26x26x4 output activations
- apply the set of weights and biases for each filter
- accumulate intermediate sums in the 40-bit signed MAC accumulator defined in Section 5
- output valid feature-map activations for the ReLU stage

### 9.6 `rtl/conv_layer_2.sv`

Purpose: compute the second learned feature map with 8 filters.

Required behavior:

- accept one complete 3 x 3 window across all four pooled channels as 36 signed Q6.14 samples in `window[0:35]`
- interpret sample index `ch * 9 + ky * 3 + kx` as channel-major then kernel row-major; use the same index for each filter's weights in `filter_weights[0:7][0:35]`
- compute eight independent 36-term dot products, each with its matching signed Q1.7 weights and signed Q6.14 bias, using the Section 5 arithmetic contract
- register eight saturated signed Q6.14 convolution values in `feature_map[0:7]`; these are pre-ReLU values
- accept a window on a rising edge when `rst_n`, `enable`, and `valid_in` are high, then assert `valid_out` with the registered results in the following cycle; accept at most one window per cycle
- process 121 valid windows per image in row-major output-location order, producing 11 x 11 x 8 values before the separate ReLU stage

### 9.7 `rtl/pooling_layer.sv`

Purpose: reduce the spatial size of the first feature map.

Required behavior:

- apply 2x2 max pooling with stride 2
- reduce 26x26x4 to 13x13x4
- preserve the strongest activation in each pooling region

### 9.8 `rtl/relu.sv`

Purpose: apply the activation function after convolution.

Required behavior:

```text
if value < 0 then output = 0
else output = value
```

This stage is required after both conv layers.

---

### 9.9 `rtl/flatten_layer.sv`

Purpose: flatten the 2D feature maps into a single vector for the dense layer.

Required behavior:

- serialize the final convolution output in a defined order
- maintain deterministic ordering between software export and hardware flattening

---

### 9.10 `rtl/dense_layer.sv`

Purpose: compute the final 10 class logits from the flattened features.

Required behavior:

- accept the flattened feature vector in sequence
- compute the dot product for each class
- output logits[0:9]

---

### 9.11 `rtl/argmax.sv`

Purpose: select the class with the highest score.

Required behavior:

- compare all logits
- return the maximum index as the predicted digit

---

### 9.12 `rtl/weights_mem.sv`

Purpose: load the exported CNN weights and bias values for the hardware pipeline.

Required responsibilities:

- store conv1 parameters
- store conv2 parameters
- store dense-layer parameters
- provide fixed read-only values during simulation

---

### 9.13 `tb/tb_top.sv`

Purpose: validate the CNN against known MNIST outputs.

The testbench must:

1. initialize the clock and reset
2. load input images and golden outputs
3. stream one image at a time through the CNN
4. wait until `done` is asserted
5. compare the final predicted digit with the expected label
6. print pass/fail and final accuracy summary
7. finish with `$finish;`

---

## 10. Model Export Contract

The Python export script and RTL memory layout must be perfectly aligned.

### 10.1 Required export files

- conv1_weights.mem
- conv2_weights.mem
- dense_weights.mem
- biases.mem
- input_images.mem
- golden_outputs.mem

### 10.2 Export order

The export contract must define explicitly:

- kernel ordering for each convolution filter
- filter ordering for each feature map
- dense-layer matrix ordering
- flatten order from feature map to dense-layer input
- bias ordering matching the corresponding output channels

This ordering must be reflected exactly in the RTL memory read logic.

---

## 11. Simulation Workflow

### Required tools

- iverilog
- GTKWave
- Python 3
- pip dependencies from `model/requirements.txt`

### Typical workflow

```bash
cd model
python train_and_export.py
cd ../sim
make compile
make run
make wave
```

The expected behavior is:

- compile all RTL files for the CNN pipeline
- load model and validation data from `tb/test_vectors/`
- run the CNN over the validation set
- print pass/fail results and total accuracy
- allow waveform inspection for debugging

---

## 12. Verification Requirements

The design is considered complete only when:

- all CNN RTL modules compile
- the testbench loads the correct memory files
- the model output matches the golden labels for a validation subset
- the simulation completes without signal timing errors
- the repository remains clear and readable for future review

### Required checks

- signed arithmetic stays consistent across export and hardware logic
- all layer dimensions match the intended CNN architecture
- ReLU and pooling are performed in the correct stage order
- no FPGA or synthesis-only scripts are included
- all exported memory files match the weight ordering expected by the RTL design

---

## 13. Risks and Constraints

### 13.1 Mismatch between Python and RTL parameter ordering

This is the most critical risk. If the export order differs from the read order in the RTL design, the network will produce incorrect predictions even if the architecture is correct.

### 13.2 Architecture growth

A CNN can become too large if more layers or filters are added before the small working design is validated.

### 13.3 Timing and handshake correctness

Because this is a streaming design, valid/ready sequencing must be consistent across modules.

---

## 14. Deliverables

The final repository should include:

- Python export script for CNN weights and biases
- RTL implementation for a small CNN classifier
- testbench that loads validation data and golden outputs
- compiled simulation flow and waveform support
- project documentation that explains the network operation clearly

---

## 15. Final Project Statement

This repository defines a compact, simulation-only CNN for MNIST digit classification. The design is deliberately small enough to remain understandable and buildable, but it is real enough to demonstrate the core mechanics of convolution, ReLU, pooling, flattening, dense classification, and argmax-based decision making.

This project is intended to be a realistic, GitHub-friendly, internship-relevant hardware and ML artifact that combines digital design, fixed-point arithmetic, and neural-network-style inference in a clean and testable flow.

---

## 16. Implementation Summary

The final network is intended to be:

- one 3x3 convolutional layer with 4 filters
- ReLU
- 2x2 max-pooling
- one 3x3 convolutional layer with 8 filters
- ReLU
- flatten to 968 features
- dense 968 -> 10 logits
- argmax for final digit prediction

This is a small, real CNN with enough structure to be credible while still remaining manageable for simulation and portfolio use.
