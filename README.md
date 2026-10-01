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
- Encode exported weights as signed 8-bit two's-complement values using exactly two hexadecimal digits per value, and biases as signed 20-bit two's-complement values using exactly five hexadecimal digits per value. Write one scalar per line as specified in Section 7.1.5.
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
- pooling is independent for each of the four channels; values from different channels are never compared
- each complete block is ordered top-left, top-right, bottom-left, bottom-right
- blocks are processed by pooled row, pooled column, then channel, so the four channel outputs for one pooled coordinate are consecutive
- the upstream stage assembles each complete block; `pooling_layer` accepts a full block in one transfer and returns one scalar

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

### 7.1 Dataflow model: stage-sequenced streaming

The inference is controlled one stage at a time by the FSM. Image pixels enter as a row-major stream, and each active stage processes one scalar, vector, or complete local neighborhood per clock as defined below. Fixed-size buffers hold the image and intermediate feature maps between FSM stages. This simulation-only design uses those buffers instead of a concurrent pipeline with ready/backpressure logic at every boundary.

No complete tensor is transferred across a module boundary in one cycle. The controller reads or writes one defined item per cycle, while arrays are storage owned by the top-level design or the stage that builds a neighborhood. Convolution and pooling neighborhood arrays are complete payloads for one local operation, not implicit multi-cycle transfers.

### 7.1.1 Final protocol choice for the repository

The final protocol is:

- The top-level accepts `start` only in `IDLE`. The first pixel is not accepted on the same edge as `start`.
- During `LOAD_IMAGE`, `ready` is high until 784 pixels have been accepted. A pixel transfers only on a rising edge with `pixel_valid && ready`; if `pixel_valid` is low, the image counter and buffer do not advance. Accepted pixels are stored as unsigned bytes in row-major order.
- After pixel 784, `ready` goes low and the FSM processes the buffered image through `CONV1`, `RELU1`, `POOL`, `CONV2`, `RELU2`, `FLATTEN`, and `DENSE`, in that order. These stages do not operate concurrently.
- Internal module inputs transfer on a rising edge when both `valid_in` and that stage's `enable` are high. The FSM asserts `enable` only when the source item exists and the destination's fixed buffer has space. Internal interfaces have no `ready` signal and do not stall; source arrays retain unconsumed values, and the controller captures each output-valid result.
- Registered Conv1, pooling, and Conv2 outputs assert `valid_out` for one cycle with the result available. The FSM counts accepted inputs and captured outputs; it advances only after the exact stage output count is complete. ReLU is combinational and is applied to all channels of one spatial vector in parallel during its FSM state.
- Flatten consumes one eight-channel Conv2 vector per spatial location and fills the 968-entry output vector in the frozen channel-major order. It asserts `valid_out` once the complete vector is available. Dense then consumes those 968 values in sequence and asserts `dense_done` once all ten logits are final.
- Argmax evaluates the ten signed logits after `dense_done`. The top-level captures the winning digit and asserts `done` for one cycle.

This is a sequential, buffered streaming design, not a concurrent ready/valid pipeline. The full-tensor buffers and their exact capacities are specified in Section 7.4.

### 7.2 Exact stage semantics

#### ReLU stage semantics

ReLU is a per-sample scalar operation. It is applied to one activation value at a time.

```text
if x < 0 then output = 0
else output = x
```

This is a single-value operation and does not require a multi-sample neighborhood. In RTL, this is naturally implemented as a per-cycle scalar comparison and assignment.

#### Pooling stage semantics

Pooling compares the four signed Q6.14 values in one complete, same-channel 2x2 block. The block order is:

```text
pool_block[0] = top-left
pool_block[1] = top-right
pool_block[2] = bottom-left
pool_block[3] = bottom-right
```

For pooled output coordinate `(pr, pc)` and channel `ch`, where `pr` and `pc` range from 0 through 12 and `ch` ranges from 0 through 3:

```text
pool_block[0] = relu1[2*pr    ][2*pc    ][ch]
pool_block[1] = relu1[2*pr    ][2*pc + 1][ch]
pool_block[2] = relu1[2*pr + 1][2*pc    ][ch]
pool_block[3] = relu1[2*pr + 1][2*pc + 1][ch]
```

The output is:

```text
pooled_value = max(pool_block[0], pool_block[1], pool_block[2], pool_block[3])
```

The upstream producer presents one complete block per `valid_in` transfer. On a rising edge where `rst_n`, `enable`, and `valid_in` are all high, `pooling_layer` accepts the block, registers the signed maximum, and asserts `valid_out` for the following cycle. The maximum is compared as signed Q6.14 and passed through unchanged. There are 13 x 13 x 4 = 676 accepted blocks and scalar outputs per image. Process them in this order:

```text
for pr = 0..12:
        for pc = 0..12:
                for ch = 0..3:
                        accept the 2x2 block for (pr, pc, ch)
```

Thus every group of four consecutive `pooled_value` transfers corresponds to channels 0..3 at one pooled `(pr, pc)` coordinate. This is the location-major, channel-contiguous order used to build Conv2's four-channel input map. Since 26 is even and the stride is 2, the 13 x 13 output uses every input position exactly once; no padding or partial block is needed.

### 7.3 Local array interpretation in RTL

The following array conventions are used in the RTL skeleton for clarity and consistency:

- `window[0:8]` means a 3x3 receptive field buffer for a convolution window
- `pool_block[0:3]` means a 2x2 local pooling block buffer
- these arrays are local working structures, not evidence that the entire tensor is passed as a single monolithic object in one cycle

For pooling, `pool_block` contains a complete same-channel neighborhood when presented to the module. The upstream producer assembles the four values; the pooling module does not gather four scalar transfers internally. It returns one pooled value for that block.

### 7.4 Interface contract for the actual implementation

#### Transaction control

- `rst_n` is an active-low asynchronous reset. It resets the FSM, counters, valid/done flags, and predicted digit. Large data arrays do not need reset; every item is overwritten before its stage reads it.
- `start` is accepted only while the FSM is in `IDLE`. A start while busy is ignored. The first pixel may be presented on the following cycle.
- `ready` is high only in `LOAD_IMAGE` while fewer than 784 pixels have been accepted. A pixel is accepted on a rising edge when `pixel_valid && ready` is true. When `pixel_valid` is low, `ready` may remain high and the input count holds. After the 784th accepted pixel, `ready` goes low and remains low until a later inference enters `LOAD_IMAGE`.
- A reset during an inference aborts it and returns the FSM to `IDLE`; a new `start` is required. No partial image or intermediate result is reused.
- `done` is asserted for exactly one cycle in `DONE`. `predicted_digit` is captured before that pulse and remains stable until reset or the next completed inference. The FSM returns to `IDLE` after the `DONE` cycle; the next `start` can be accepted in `IDLE`.

#### Internal transfers and buffering

- For a module with both `valid_in` and `enable`, an input transfer occurs on a rising edge when both are high. Modules without `enable` use their documented valid signal only while the FSM is in the owning state: `line_buffer` consumes image-buffer pixels on `pixel_valid`, `flatten_layer` consumes channel vectors on `valid_in`, and `dense_layer` consumes features on `feature_valid` after `start_dense`.
- There is no internal `ready` or backpressure. A disabled stage does not consume its input; its source buffer keeps that item available. The FSM activates a stage only when its input exists and its fixed destination buffer has capacity.
- A registered stage presents `valid_out` for one cycle with the result available during that cycle. The controller captures the result on the rising edge at the end of the valid cycle. Each stage's latency and result counts are fixed by its module contract; the FSM transitions based on captured item counts, not a guessed delay.
- All counters advance only on the stated transfer or output-valid event. Each stage completes only at the specified item count; no stage transition is based on a guessed fixed delay.
- ReLU operates combinationally on one channel vector per spatial position, with one scalar ReLU operation per channel in parallel. It does not add a separate valid cycle.
- The pooling and convolution window producers assemble complete local arrays before asserting the receiving stage's valid signal. A local array is one operation's payload, not a sequence of scalar input transfers.

#### Boundary signal map

| Boundary | Transfer condition | Payload and completion |
|---|---|---|
| Host to image buffer | Rising edge with `pixel_valid && ready` in `LOAD_IMAGE`. | One unsigned pixel; 784 accepted pixels complete the image. |
| Image buffer to line buffer | In `CONV1`, pulse `clear` for one cycle before scanning; then assert the line-buffer `pixel_valid` for each buffered pixel. | One raw pixel per cycle; the line buffer emits one row-major Q1.7 3 x 3 window whenever `window_valid` is high, 676 windows total. `clear` has priority and consumes no pixel. |
| Line buffer to Conv1 | Rising edge with `window_valid && enable_conv1`. | One signed Q1.7 window of nine values. Conv1 emits 676 four-value results using `valid_out`. |
| Conv1 map to ReLU1 | One location vector per cycle during `RELU1`; no registered handshake. | Four signed Q6.14 values per location; all four are ReLU-processed in parallel and written back in place. |
| ReLU1 map to pool block / Pool | Rising edge with pooling `valid_in && enable`. | One complete same-channel four-value block; pooling emits one scalar with `valid_out`, 676 scalars total. |
| Pooled map to Conv2 | On entry to `CONV2`, reset the window-source row/column counters to zero. Assert internal `conv2_window_valid` for each complete window; Conv2 accepts on `conv2_window_valid && enable_conv2`. | One signed Q6.14 window of 36 values; Conv2 emits eight signed Q6.14 values with `valid_out`, 121 vectors total. |
| Conv2 map to ReLU2 | One location vector per cycle during `RELU2`; no registered handshake. | Eight signed Q6.14 values per location; all eight are ReLU-processed in parallel and written back in place. |
| Conv2 map to Flatten | Rising edge with Flatten `valid_in` during `FLATTEN`; spatial vectors arrive row-major. | `feature_data[ch]` for the current `(r,c)` is stored at `flattened_vector[ch * 121 + r * 11 + c]`. After 121 accepted vectors, `valid_out` pulses once for the complete 968-value array, which remains stable through `DENSE`. |
| Flatten vector to Dense | Pulse `start_dense` on the first `DENSE` cycle while `feature_valid` is low; then assert `feature_valid` once for each flat index 0..967. | One signed Q6.14 feature per valid cycle. Dense asserts `dense_done` once all ten logits are final. |
| Dense logits to Argmax/top | `dense_done` qualifies the completed logits; Argmax is combinational. | Ten signed Q6.14 logits; the top-level captures the selected 4-bit digit and asserts `done` in `DONE`. |

All `valid_out` and completion signals are cleared by reset. A one-cycle valid signal means one result is available during that cycle; adjacent high cycles represent adjacent results where a stage emits one result per cycle. The controller captures results only when valid is high. Flattened data remains stable throughout Dense processing, and logits remain stable from `dense_done` until reset or the next inference completes. Internal stages do not wait for downstream readiness.

#### Stage sequence, payloads, and exact counts

FSM order: `IDLE -> LOAD_IMAGE -> CONV1 -> RELU1 -> POOL -> CONV2 -> RELU2 -> FLATTEN -> DENSE -> DONE`.

| State | Input and processing order | Completed output |
|---|---|---|
| `LOAD_IMAGE` | Accept 784 unsigned bytes in row-major order into the image buffer. | One complete 28 x 28 image. |
| `CONV1` | Clear the line buffer, then read all 784 image bytes one per cycle through it. It converts pixels to Q1.7 and emits each complete row-major 3 x 3 window with `window_valid`; Conv1 accepts when `window_valid && enable_conv1`. | 676 valid locations, each with four pre-ReLU Q6.14 values. |
| `RELU1` | Apply ReLU to each of the four values at every Conv1 location and replace the values in the Conv1 buffer. | 676 four-channel locations, 2,704 values. |
| `POOL` | Assemble one same-channel block in TL, TR, BL, BR order; process by pooled row, pooled column, then channel. | 676 signed Q6.14 values (13 x 13 x 4), stored location-major with channels 0..3 consecutive. |
| `CONV2` | Reset the window-source row/column counters to zero, then read the pooled map and form complete 36-value windows using the mapping in Section 7.1.3. Conv2 accepts 121 windows in row-major output-location order. | 121 locations, each with eight pre-ReLU Q6.14 values. |
| `RELU2` | Apply ReLU to each of the eight values at every Conv2 location and replace the values in the Conv2 buffer. | 121 eight-channel locations, 968 values. |
| `FLATTEN` | Read the 121 eight-channel locations in row-major spatial order and store channel `ch` at `ch * 121 + r * 11 + c`. | One complete 968-value signed Q6.14 vector and one completion pulse after the 121st accepted input vector. |
| `DENSE` | Pulse `start_dense` on entry, then present flat indices 0..967 sequentially with `feature_valid`. Dense handles parameter access and accumulates all ten class scores. | Ten final signed Q6.14 logits and one `dense_done` pulse. |
| `DONE` | Evaluate/capture argmax result from the completed logits. | One-cycle `done` pulse and stable `predicted_digit`. |

#### Fixed buffer capacities

The top-level controller owns the full-image/interstage storage needed by the sequential FSM. Capacities count scalar entries unless stated otherwise:

| Buffer | Capacity | Element format |
|---|---:|---|
| Input image | 784 | Unsigned 8-bit raw pixels |
| Conv1 feature map | 2,704 (26 x 26 x 4) | Signed Q6.14; ReLU is performed in place |
| Pooled feature map | 676 (13 x 13 x 4) | Signed Q6.14 |
| Conv2 feature map | 968 (11 x 11 x 8) | Signed Q6.14; ReLU is performed in place |
| Flattened vector | 968 | Signed Q6.14, channel-major order |
| Dense accumulators | 10 | Signed 40-bit values, per Section 5 |

These buffers make stage-by-stage sequencing explicit and bounded. They are simulation storage, not an FPGA/ASIC area target. No module may read beyond the valid item count for its current inference.

The row-major scalar index in the input image buffer is `r * 28 + c`. Store Conv1 output vectors as `(r * 26 + c) * 4 + ch`, pooled values as `(pr * 13 + pc) * 4 + ch`, and Conv2 output vectors as `(r * 11 + c) * 8 + f`. Flatten performs the separate channel-major reorder defined in Section 7.1.6.

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

Parameters are held in separate typed read-only arrays loaded from the four exported files. There is no shared parameter address bus: each weight array uses its own zero-based file order, and the bias arrays are sliced from the one ordered bias file. `weights_mem` exposes the complete arrays to the layers; indexing is combinational with no read latency. This matches the existing Conv1/Conv2 weight-array interfaces and lets Dense read one weight for each of its ten classes for a given feature index.

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

#### Typed array and file-index map

Each memory file contains exactly one scalar per line and no comments. Signed 8-bit weights use exactly two hexadecimal digits per value; signed 20-bit biases use exactly five hexadecimal digits per value. Hex digits encode the value's two's-complement bit pattern.

| `weights_mem` output array | File | Local file indices | Element width | Index formula |
|---|---|---:|---:|---|
| `conv1_weights[0:3][0:8]` | `conv1_weights.mem` | 0..35 | signed 8-bit | `filter * 9 + ky * 3 + kx` |
| `conv2_weights[0:7][0:35]` | `conv2_weights.mem` | 0..287 | signed 8-bit | `filter * 36 + channel * 9 + ky * 3 + kx` |
| `dense_weights[0:9][0:967]` | `dense_weights.mem` | 0..9679 | signed 8-bit | `class * 968 + input_index` |
| `conv1_biases[0:3]` | `biases.mem` | 0..3 | signed 20-bit | `filter` |
| `conv2_biases[0:7]` | `biases.mem` | 4..11 | signed 20-bit | `4 + filter` |
| `dense_biases[0:9]` | `biases.mem` | 12..21 | signed 20-bit | `12 + class` |

The three weight files contain 10,004 values total; the bias file contains 22. The combined parameter count remains 10,026. These are per-file element indices, not addresses on a shared ROM bus. `weights_mem` loads the arrays during simulation initialization, then holds them unchanged. Inference begins after initialization; there is no clocked parameter-read transaction or out-of-range address behavior.

### 7.1.6 Flatten ordering contract

The flattened vector must be deterministic and match the exact export order used by the dense-layer weight matrix.

The required flatten order is:

```text
for each output channel ch in 0..7:
  for each row r in 0..10:
    for each column c in 0..10:
      flattened_vector.push(conv2_out[ch][r][c])
```

The input to `flatten_layer` arrives as one location vector per valid transfer, in row-major spatial order. `feature_data[ch]` is the Conv2/ReLU2 value for channel `ch` at the current location `(r, c)`. The exact destination index is:

```text
spatial_index = r * 11 + c
flat_index = ch * 121 + spatial_index
                                                = ch * 121 + r * 11 + c
flattened_vector[flat_index] = feature_data[ch]
```

Thus input location vectors arrive in location-major order, while the output array is channel-major, row-major, column-major. The Flatten module stores/reorders all 121 input vectors. It accepts a vector on each rising edge with `valid_in` high during `FLATTEN`; invalid cycles do not advance its location count. After accepting the 121st vector, it asserts `valid_out` for one cycle with the complete 968-value array. The array remains stable throughout `DENSE` and is then reusable for the next inference. Boundary indices are `flat[0] = feature_data[0]` at `(r,c)=(0,0)`, `flat[120]` at channel 0 location `(10,10)`, `flat[121]` at channel 1 location `(0,0)`, and `flat[967]` at channel 7 location `(10,10)`.

### 7.1.7 Handshake and stage sequencing

Section 7.4 is the authoritative contract for top-level handshaking, internal transfers, stage order, storage, output counts, reset, completion, and the pixel-to-prediction lifecycle. Module code and tests must follow it exactly.

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

- accept `start` only in `IDLE`, then accept exactly 784 pixels using the top-level `pixel_valid && ready` handshake
- store the raw image and run each CNN stage in the order and with the buffer capacities defined in Section 7.4
- use internal `valid_in && enable` transfers; do not add internal ready/backpressure
- capture the argmax result and assert the one-cycle `done` pulse when the prediction is valid

---

### 9.3 `rtl/control_fsm.sv`

Purpose: coordinate the stage-sequenced inference transaction and fixed-size intermediate buffers.

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

- accept `start` only in `IDLE` and control top-level pixel acceptance in `LOAD_IMAGE`
- enable exactly one compute stage at a time in the order listed above
- clear per-stage counters/window state on entry to the corresponding stage
- capture each registered output when its `valid_out` is asserted and count exact expected outputs
- start Dense after the complete flattened vector is available and wait for `dense_done`
- assert `done` for one cycle in `DONE`, then return to `IDLE`

---

### 9.4 `rtl/line_buffer.sv`

Purpose: maintain enough image history to generate the 3x3 sliding window for convolution.

Required behavior:

- keep previous rows required for a local 3x3 neighborhood
- accept one input pixel whenever `pixel_valid` is high during `CONV1`; `clear` has priority and resets row/column history before the scan
- convert each raw unsigned pixel to signed Q1.7 using the Section 5 rule before placing it in a window
- output nine signed Q1.7 samples in row-major window order with `window_valid` for each complete window
- emit exactly 676 valid windows from one 28 x 28 image; no window may cross a row boundary

---

### 9.5 `rtl/conv_layer_1.sv`

Purpose: compute the first feature map using a 3x3 kernel and 4 filters.

Required behavior:

- accept a 28x28 input image window and generate 26x26x4 output activations
- apply the set of weights and biases for each filter
- accumulate intermediate sums in the 40-bit signed MAC accumulator defined in Section 5
- accept each valid window when `valid_in && enable` is true on a rising edge
- register all four pre-ReLU signed Q6.14 filter results for that location and assert `valid_out` for one cycle with the vector
- produce exactly 676 four-value vectors, in row-major output-location order

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
- accept one complete 2x2 block for one channel at a time, ordered top-left, top-right, bottom-left, bottom-right
- compare the four signed Q6.14 inputs and register their maximum without changing its value or scale
- accept a block on a rising edge when `rst_n`, `enable`, and `valid_in` are high, then assert `valid_out` with `pooled_value` in the following cycle
- process blocks in pooled-row, pooled-column, channel order; the upstream producer supplies coordinates implicitly through this order and assembles the block before asserting `valid_in`
- produce exactly 676 scalar values per image; each consecutive group of four is channels 0..3 at one pooled coordinate

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
- accept one eight-channel Conv2 vector per spatial location in row-major location order during `FLATTEN`
- write `feature_data[ch]` for location `(r,c)` to `flattened_vector[ch * 121 + r * 11 + c]`
- advance the input location count only on a rising edge with `valid_in` high; after 121 accepted vectors, assert `valid_out` for one cycle and expose the complete 968-value channel-major vector
- hold the completed vector stable throughout `DENSE`; reset clears the input count and `valid_out`

---

### 9.10 `rtl/dense_layer.sv`

Purpose: compute the final 10 class logits from the flattened features.

Required behavior:

- accept the flattened feature vector in sequence
- receive `dense_weights[0:9][0:967]` as signed 8-bit values and `dense_biases[0:9]` as signed 20-bit values from `weights_mem`
- compute the dot product for each class
- `start_dense` initializes the ten accumulators; accept flat indices 0..967 sequentially when `feature_valid` is high
- for each accepted flat index `i`, use `dense_weights[class][i]` for each class and add `dense_biases[class]` at initialization, following Section 5 arithmetic
- after the final accepted feature and all parameter operations complete, register `logits[0:9]` and assert `dense_done` for one cycle

---

### 9.11 `rtl/argmax.sv`

Purpose: select the class with the highest score.

Required behavior:

- compare all logits
- return the maximum index as the predicted digit

---

### 9.12 `rtl/weights_mem.sv`

Purpose: load the exported CNN weights and bias values for the hardware pipeline.

Required interface and behavior:

- expose signed `conv1_weights[0:3][0:8]`, `conv1_biases[0:3]`, `conv2_weights[0:7][0:35]`, `conv2_biases[0:7]`, `dense_weights[0:9][0:967]`, and `dense_biases[0:9]` arrays
- load the arrays from `conv1_weights.mem`, `conv2_weights.mem`, `dense_weights.mem`, and `biases.mem` in the documented order
- use combinational array indexing with no clock, reset, address, or read-latency interface; parameters remain constant after initialization
- load files relative to the documented simulation working directory (`sim/`)

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

The top-level pixel input uses `pixel_valid && ready`; internal stage sequencing uses the documented valid/enable signals and fixed buffers. The controller must preserve the exact transfer counts and stage transitions in Section 7.4.

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
