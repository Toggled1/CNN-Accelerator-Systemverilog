# MNIST Digit Classifier RTL Simulation Project

This repository implements a compact hardware-oriented digit-classification project based on the MNIST handwritten digit dataset. The system is designed as a simulation-only inference pipeline that combines Python-based model export with SystemVerilog RTL logic and a self-checking verification flow.

This document is the authoritative project specification. It defines the architecture, module responsibilities, data formats, numerical conventions, verification methodology, and execution plan for the project.

> Project constraint: this project is simulation-only. It is not intended for FPGA deployment, synthesis targeting, or real hardware fabrication. The design is intended to be evaluated and validated using HDL simulators such as iverilog and Verilator.

---

## 1. Project Purpose

The objective is to build a digital classifier that accepts a single MNIST image, performs fixed-point arithmetic over the image and model parameters, and produces a predicted digit from 0 to 9.

The project is intended to demonstrate:

- Python-based model preparation and export
- fixed-point arithmetic in a hardware-oriented context
- RTL design in SystemVerilog
- finite-state control and dataflow coordination
- HDL simulation and testbench verification
- a clean GitHub-ready engineering workflow

This project is a portfolio-level hardware/software integration project and is explicitly scoped to be realistic, understandable, and achievable without requiring industrial FPGA or ASIC infrastructure.

---

## 2. Project Scope and Non-Goals

### In scope

- MNIST classification using a compact fixed-point inference model
- Python export of trained or pre-trained weights into hardware-readable memory files
- SystemVerilog modules implementing the digital inference flow
- simulation-based verification against known golden outputs
- self-checking automated testbench behavior
- repository documentation and project structure suitable for GitHub

### Out of scope

- FPGA deployment
- board bring-up or pin mapping
- gate-level synthesis flows
- FPGA timing closure or physical design
- large-scale CNN accelerator design
- production-ready ASIC implementation
- real-time hardware acceleration on physical silicon

The design is intentionally limited to simulation and algorithmic validation.

---

## 3. System Overview

The project operates as a one-image-at-a-time inference pipeline.

```text
[ MNIST 28x28 image ]
        |
        v
[ input stream / loader ]
        |
        v
[ 3x3 window feature extraction ]
        |
        v
[ ReLU / activation ]
        |
        v
[ dense score generation ]
        |
        v
[ argmax class selection ]
        |
        v
[ predicted digit ]
```

### Design intent

The hardware architecture is intentionally small and readable. Its purpose is not to be the most optimized accelerator, but to demonstrate the core flow of a neural inference design in hardware-style logic:

- streaming pixel input
- multiply-accumulate arithmetic
- fixed-point data representation
- activation logic
- class score reduction
- final argmax classification

---

## 4. Dataset Specification

The project uses the MNIST handwritten digit dataset.

### 4.1 Data dimensions

- image width: 28 pixels
- image height: 28 pixels
- total pixels per image: 784
- grayscale range: 0 to 255
- output classes: 10 digits (0 through 9)

### 4.2 Data conventions

- image data is flattened in row-major order
- each image is treated as a sequence of 784 pixel values
- each pixel is represented as an 8-bit value in simulation
- classification target is the integer label 0 through 9

### 4.3 Expected model input

The input vector for a single inference cycle is a flattened MNIST image represented as:

```text
pixel[0], pixel[1], pixel[2], ..., pixel[783]
```

where each element is a byte in the range 0 to 255.

---

## 5. Numerical Representation

The design uses fixed-point signed integer arithmetic to keep the implementation straightforward and hardware-friendly.

### 5.1 Bit widths

- pixel / input sample: `logic signed [7:0]`
- weight value: `logic signed [7:0]`
- bias value: `logic signed [19:0]`
- accumulation result: `logic signed [19:0]`
- class logit / score: `logic signed [19:0]`
- final digit index: `logic [3:0]`

### 5.2 Signed interpretation

All arithmetic involving model parameters and activations should be interpreted as signed two's complement values.

### 5.3 Default fixed-point convention

The design uses integer arithmetic rather than fractional fixed-point scaling. This is acceptable for a simplified portfolio project, provided the model export and hardware logic follow the same numerical interpretation.

### 5.4 Accumulator and clipping behavior

The accumulator is widened to 20 bits to reduce overflow risk during multiply-accumulate operations. Outputs may then be:

- kept in 20-bit signed form for class scores
- converted to 8-bit signed form after activation if required by the chosen model pipeline
- clipped to signed 8-bit limits when conversion is needed

---

## 6. Model Architecture

The project uses a compact inference model with a structure suitable for simulation and project tractability.

### 6.1 Baseline architecture

The expected architecture is:

1. Input image: 28x28 grayscale values
2. Small feature extraction stage based on a 3x3 local window
3. ReLU activation
4. Flattening into a feature vector
5. Dense class scoring layer producing 10 logits
6. Argmax to select the winning digit

### 6.2 Model definition requirement

The implementation must define the exact model dimensions and parameter counts before coding the RTL and memory export files. This includes:

- number of feature extraction windows or filters
- number of feature values after extraction
- number of dense-layer inputs
- number of dense-layer outputs
- exact weight matrix dimensions
- exact bias vector sizes

### 6.3 Recommended simplified model

A practical and realistic portfolio model is:

- one small feature extraction stage using a 3x3 receptive field
- one ReLU activation stage
- one dense layer that maps the extracted features to 10 logits

This model keeps the project implementable while retaining the essential pattern of a digital neural inference core.

---

## 7. Fixed-Point and Dataflow Rules

The same numerical assumptions must be used by both the Python export script and the RTL design.

### 7.1 Required conventions

- model parameters must be exported in a fixed, documented bit-width format
- input pixels must be normalized or treated consistently according to the chosen export convention
- weights must be stored in signed 8-bit form
- accumulators must be wide enough to handle sum growth without immediate overflow
- ReLU behavior must be explicitly defined for negative values
- class scores must be compared with the same signed interpretation used in export

### 7.2 ReLU behavior

For a signed activation value `x`:

```text
if x < 0 then output = 0
else output = x
```

If clipping is used after the accumulation stage, the exact rule must be documented and applied consistently in both Python and RTL.

### 7.3 Output rule

The final output is the class index associated with the maximum logit value:

```text
predicted_digit = argmax(logits[0:9])
```

---

## 8. Repository Layout

```text
mnist-rtl-sim/
├── .github/
│   └── workflows/
│       └── ci.yml                 # GitHub Actions simulator workflow
├── model/
│   ├── train_and_export.py       # Python model export / parameter generation
│   ├── requirements.txt          # Python dependency list
│   ├── mnist_model.py            # optional reusable model definition
│   └── export_utils.py           # optional helper functions for serialization
├── rtl/
│   ├── top_classifier.sv         # top-level classifier module
│   ├── control_fsm.sv            # inference-state controller
│   ├── line_buffer.sv            # image-history / 3x3 window generation
│   ├── mac_unit.sv               # multiply-accumulate stage
│   ├── relu.sv                  # activation and clipping stage
│   ├── dense_layer.sv            # dense classification layer
│   ├── argmax.sv                 # winner selection logic
│   └── weights_mem.sv            # weight and bias memory initialization
├── tb/
│   ├── tb_top.sv                 # simulation testbench
│   └── test_vectors/
│       ├── weights.mem           # exported 8-bit weights
│       ├── biases.mem            # exported 20-bit biases
│       ├── input_images.mem      # MNIST images in hex
│       └── golden_outputs.mem    # expected digit labels
├── sim/
│   ├── Makefile                  # compile and run rules
│   ├── run_sim.sh                # optional shell runner
│   └── wave_config.gtkw          # GTKWave waveform layout
├── README.md                     # complete project specification
├── PROJECT_SPEC.md               # optional backup spec copy
├── LICENSE                       # optional project license
└── .gitignore                    # ignore generated artifacts
```

This layout is intentionally concise but complete enough to support a buildable, testable project.

---

## 9. Module Specifications

### 9.1 `model/train_and_export.py`

Purpose: generate the model parameters used by the RTL environment.

Required responsibilities:

- load MNIST data
- define or train the compact model
- convert weight values into signed 8-bit format
- optionally quantize or clip values for simulation compatibility
- export `.mem` files for the testbench
- generate expected outputs for validation samples

Expected outputs:

- weights.mem
- biases.mem
- input_images.mem
- golden_outputs.mem

This script is the source of truth for the numerical values used in the simulation environment.

---

### 9.2 `rtl/top_classifier.sv`

Purpose: system top-level module that orchestrates one inference cycle.

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

- initialize and maintain the image input flow
- sequence the state machine for one MNIST inference cycle
- coordinate all core stages of the inference pipeline
- expose `done` once a valid prediction is available
- provide the final digit prediction to the testbench

---

### 9.3 `rtl/control_fsm.sv`

Purpose: define the control flow for the inference pipeline.

Required states:

- IDLE
- LOAD_IMAGE
- WINDOW_PREPARE
- MAC_COMPUTE
- ACTIVATION
- DENSE_SCORE
- DONE

Required behaviors:

- wait for `start`
- ingest image pixels in a valid handshake sequence
- trigger the line buffer and MAC stage when enough data is available
- advance to the activation stage after the local feature stage completes
- initiate dense scoring once the feature vector is available
- assert `done` when prediction is valid

The FSM must be deterministic and must clearly separate the stages of one inference pass.

---

### 9.4 `rtl/line_buffer.sv`

Purpose: hold the required image history and generate a sliding 3x3 window.

Required behavior:

- maintain enough previous rows to construct a local neighborhood
- output a 9-element window on valid cycles
- update the window as new pixels arrive
- ensure no invalid window is emitted before enough image history exists

Example interface:

```systemverilog
module line_buffer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        clear,
    input  logic [7:0]  pixel_in,
    input  logic        pixel_valid,
    output logic        window_valid,
    output logic signed [7:0] window [0:8]
);
endmodule
```

---

### 9.5 `rtl/mac_unit.sv`

Purpose: compute the local dot product for the current receptive field.

Required equation:

$$
\text{acc} = \sum_{i=0}^{8} \text{window}[i] \times \text{weight}[i] + \text{bias}
$$

Required interface:

```systemverilog
module mac_unit (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic signed [7:0] window [0:8],
    input  logic signed [7:0] weights [0:8],
    input  logic signed [19:0] bias,
    output logic signed [19:0] acc_out,
    output logic               acc_valid
);
endmodule
```

Required behaviors:

- multiply all 9 terms in parallel or in a fixed pipeline
- accumulate them into a signed 20-bit accumulator
- maintain valid timing aligned with the control FSM

---

### 9.6 `rtl/relu.sv`

Purpose: apply the activation function to the MAC output.

Required behavior:

```text
if value < 0 then output = 0
else output = value
```

This stage should be simple and deterministic. It may also perform clipping if the model export requires it.

---

### 9.7 `rtl/dense_layer.sv`

Purpose: compute the final 10 class scores.

Required behavior:

- accept flattened feature values in sequence
- compute dot products for each class
- produce 10 class logits
- handle the fill/streaming of all feature values in a deterministic serialized order

Example interface:

```systemverilog
module dense_layer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start_dense,
    input  logic signed [7:0] feature_pixel,
    input  logic        feature_valid,
    output logic        dense_done,
    output logic signed [19:0] logits [0:9]
);
endmodule
```

---

### 9.8 `rtl/argmax.sv`

Purpose: select the highest class score.

Required behavior:

- compare all 10 logits
- return the index of the maximum value
- produce the final predicted digit as a 4-bit value

Example interface:

```systemverilog
module argmax (
    input  logic signed [19:0] logits [0:9],
    output logic [3:0]        winning_digit
);
endmodule
```

---

### 9.9 `rtl/weights_mem.sv`

Purpose: provide the exported model parameters to the hardware datapath.

Required responsibilities:

- initialize weights and biases from `.mem`-style files
- expose per-class and per-feature values to dense and MAC units
- support fixed, read-only memory contents during simulation
- preserve the exact order expected by the model export script

---

### 9.10 `tb/tb_top.sv`

Purpose: validate the circuit through automated simulation.

Required flow:

1. initialize clock and reset
2. load test vectors from `tb/test_vectors/`
3. drive one image at a time into the RTL design
4. wait for `done`
5. compare predicted result versus expected golden label
6. print pass/fail status and accuracy summary
7. finish simulation with `$finish;`

The testbench must be self-checking and should print a summary such as:

```text
Passed 97/100 test images
```

---

## 10. Memory and Export Format

The Python export script must serialize values in a format that is directly consumable by the RTL design.

### 10.1 Memory file semantics

- `.mem` files are plain text files containing hex values
- each file represents a memory array or vector used by the simulation
- each file must be aligned with the bit widths defined in the corresponding RTL module

### 10.2 Example file content

```text
weights.mem
-----------
00
FF
0A
2C
...
```

```text
biases.mem
----------
0000
001A
FFFE
...
```

### 10.3 Required ordering rules

The exported data must follow a precise ordering contract. This must be documented as part of the model export script.

For example:

- weights for each receptive field or dense element must be arranged in a fixed order
- bias values must follow the corresponding class or feature order
- inputs must be ordered in row-major flattening
- golden outputs must correspond exactly to the input image ordering in the validation set

The order must be deterministic and consistent across Python generation and RTL consumption.

---

## 11. Simulation Workflow

The project must be runnable in a standard Linux shell environment with open-source simulation tools.

### 11.1 Required tools

- iverilog
- GTKWave (optional but recommended)
- Python 3
- pip dependency installation from requirements.txt

### 11.2 Typical execution sequence

```bash
cd model
python train_and_export.py
cd ../sim
make compile
make run
make wave
```

### 11.3 Expected simulator behavior

- compile all SystemVerilog source files
- load memory files from the `tb/test_vectors` directory
- run the testbench over the selected input set
- print pass/fail output
- optionally open waveform output for debugging

---

## 12. Verification and Acceptance Criteria

The project is complete only when all of the following are true:

- all RTL modules compile without syntax errors
- the testbench runs without simulation errors
- the design produces valid output for a known set of MNIST samples
- predictions match the golden outputs for that validation set
- final pass/fail summary is printed in a readable format
- the repository remains organized and interpretable by a reviewer

### Required checks

- signed arithmetic is used correctly where expected
- no FPGA or synthesis-only scripts are added to the repository
- memory values match the import/export order
- end-to-end validation is performed against known outputs
- waveform inspection confirms the FSM and dataflow behave as expected

---

## 13. Project Risks and Design Constraints

### 13.1 Risk: mismatched Python and RTL conventions

This is the highest-risk issue because numerical differences between the Python-export script and the RTL implementation can silently produce wrong classifications.

Mitigation:

- define fixed export order before coding the hardware
- use the same naming conventions in both design and export
- verify a few known examples manually before scaling up

### 13.2 Risk: over-ambitious architecture

The project can become too large if the design attempts full CNN complexity before the basic pipeline works.

Mitigation:

- keep the model small and readable
- validate a minimal working example first
- only expand after basic correctness is confirmed

### 13.3 Risk: unclear handshake timing

The project can stall or produce invalid results if pixel valid/ready sequencing is not carefully modeled.

Mitigation:

- use a clear FSM and explicit valid/ready rules
- test with a small set of deterministic sample images first

---

## 14. Deliverables

At minimum, the final repository should include:

- Python model export script
- RTL classification pipeline
- testbench with self-checking logic
- memory files for model parameters and validation inputs
- simulation runner and waveform configuration
- clear project documentation

A successful project should be understandable by a reviewer without needing additional explanation beyond the README.

---

## 15. Final Project Statement

This repository defines a compact, simulation-only MNIST digit classifier implemented as a hardware-oriented digital inference pipeline. The design combines Python-generated model parameters, fixed-point arithmetic, RTL datapath logic, and HDL-based verification to produce a clear and portable example of a neural-network-inspired hardware project.

The project is intentionally scoped to remain technically substantial while being realistic enough for GitHub, internship evaluation, and academic-style hardware/software learning.

The accelerator reads one flattened MNIST image, performs simple digital processing, and produces the predicted class.

```text
[ MNIST 28x28 image ] --> [ input loader ] --> [ small MAC/feature stage ] --> [ ReLU ] --> [ dense classifier ] --> [ argmax ] --> [ predicted digit ]
```

### Design vision

The circuit behaves like a lightweight inference engine for a compact model trained on MNIST. It demonstrates the core principles of:

- streaming pixels
- fixed-point arithmetic
- matrix-vector multiply logic
- activation functions
- score comparison for classification

The hardware is intentionally small enough to reason about and validate in simulation.

---

## 4. Reduced Technical Scope

### 4.1 Dataset

- MNIST handwritten digits dataset
- Input image size: $28 \times 28$
- Pixel range: 0 to 255 grayscale
- Labels: 10 output classes ($0$ to $9$)

### 4.2 Data representation

The design uses signed fixed-point integers to keep the hardware simple and easy to verify.

- Pixel / weight type: `logic signed [7:0]`
- Accumulator type: `logic signed [19:0]`
- Output class score: signed 20-bit integer
- Final predicted digit: 4-bit index from 0 to 9

### 4.3 Network definition

This project does not require a full deep CNN. Instead, the model is intentionally compact and practical.

Recommended architecture:

1. Input layer: $28 \times 28$ MNIST image
2. Small convolution-like feature extraction using a $3 \times 3$ window and a small set of weights
3. ReLU activation
4. Flattened feature vector
5. Dense layer producing 10 class logits
6. Argmax selects the winning digit

This is enough to be a real ML + hardware project while keeping implementation manageable.

### 4.4 Quantization strategy

The model is trained in Python and exported as fixed-point integers.

- Input pixels are treated as 8-bit signed values in the hardware simulation
- Weights are quantized to 8-bit signed values
- Biases and accumulations are kept in a wider 20-bit signed format
- After accumulation, values are clipped and converted back to valid INT8 ranges when appropriate

This reflects the standard style of an efficient inference engine without needing a huge hardware pipeline.

---

## 5. Repository Structure

The project is organized to be easy to understand and to support automated simulation.

```text
mnist-rtl-sim/
├── .github/
│   └── workflows/
│       └── ci.yml                 # GitHub Actions to run simulation tests
├── model/
│   ├── train_and_export.py       # Python model training and .mem export
│   ├── requirements.txt          # Python dependencies
│   └── mnist_model.py            # Optional reusable model description
├── rtl/
│   ├── top_classifier.sv         # Top-level design unit
│   ├── control_fsm.sv            # Main finite-state controller
│   ├── line_buffer.sv            # Sliding 3x3 pixel window generator
│   ├── mac_unit.sv               # Multiply-accumulate for a 3x3 window
│   ├── relu.sv                  # ReLU / clipping stage
│   ├── dense_layer.sv            # Fully connected scoring layer
│   ├── argmax.sv                 # Winner selection logic
│   └── weights_mem.sv            # Weight / bias memory initialized from .mem files
├── tb/
│   ├── tb_top.sv                 # Self-checking SystemVerilog testbench
│   └── test_vectors/
│       ├── weights.mem           # Exported 8-bit signed weights
│       ├── biases.mem            # Exported 20-bit signed biases
│       ├── input_images.mem      # MNIST test images in hex
│       └── golden_outputs.mem    # Expected digit predictions
├── sim/
│   ├── Makefile                  # iverilog / waveform targets
│   └── wave_config.gtkw          # GTKWave configuration
├── README.md                     # Main project documentation and spec
└── PROJECT_SPEC.md               # Optional alias or backup copy of the same project spec
```

This structure is intentionally compact and clean. It supports the story of a small but real hardware project without bloating the repository.

---

## 6. Module Specifications

### 6.1 `model/train_and_export.py`

Purpose: train or load a compact MNIST model, then export parameters for hardware simulation.

Responsibilities:

- load MNIST training data
- train a small model suitable for fixed-point inference
- convert float weights to INT8 values
- generate `.mem` files for the RTL testbench
- export a small validation set and golden outputs

Outputs:

- `weights.mem`
- `biases.mem`
- `input_images.mem`
- `golden_outputs.mem`

This file is important because it creates the relationship between the Python model and the RTL verification environment.

---

### 6.2 `rtl/top_classifier.sv`

Purpose: top-level module connecting the image loader, feature extraction, dense classifier, and output logic.

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

- accept a new image and start processing
- drive the FSM for the pipeline
- pass pixels into the image/window logic
- accumulate dot products
- run ReLU / scaling
- send the feature vector to the dense classifier
- output the predicted digit at the end of processing

---

### 6.3 `rtl/control_fsm.sv`

Purpose: manage the state machine for one inference cycle.

States should include, at minimum:

- IDLE
- LOAD_IMAGE
- WINDOW_PROCESS
- ACCUMULATE
- ACTIVATION
- DENSE
- DONE

Responsibilities:

- wait for `start`
- coordinate pixel loading
- trigger the window generator and MAC unit
- manage the sequential progression through the model
- assert `done` when the final class is available

This is the central orchestration block and keeps the design understandable.

---

### 6.4 `rtl/line_buffer.sv`

Purpose: produce a sliding $3 \times 3$ neighborhood of pixels from the input image.

This is a simplified hardware-friendly version of a local receptive field.

Example interface:

```systemverilog
module line_buffer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        clear,
    input  logic [7:0]  pixel_in,
    input  logic        pixel_valid,
    output logic        window_valid,
    output logic signed [7:0] window [0:8]
);
endmodule
```

Responsibilities:

- keep the previous rows needed to build the $3 \times 3$ window
- output the nine pixels for the MAC operation
- produce the window only when enough pixels are available

This module is still realistic and relevant, but much smaller than a full CNN pipeline.

---

### 6.5 `rtl/mac_unit.sv`

Purpose: compute the dot product for the current feature window.

Mathematically:

$$
\text{acc} = \sum_{i=0}^{8} \text{window}[i] \times \text{weight}[i] + \text{bias}
$$

Example interface:

```systemverilog
module mac_unit (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic signed [7:0] window [0:8],
    input  logic signed [7:0] weights [0:8],
    input  logic signed [19:0] bias,
    output logic signed [19:0] acc_out,
    output logic               acc_valid
);
endmodule
```

Responsibilities:

- multiply each pixel by its corresponding weight
- sum into a 20-bit accumulator
- maintain stable output timing

---

### 6.6 `rtl/relu.sv`

Purpose: apply the nonlinearity after the MAC stage.

Simple logic:

- if value is negative, clamp to zero
- otherwise keep value or apply a small scale if required by the chosen model

This keeps the digital implementation easy to simulate and easy to explain.

---

### 6.7 `rtl/dense_layer.sv`

Purpose: compute class scores from the flattened feature vector.

This layer is simpler than a full multi-layer network but still demonstrates the core idea behind a classifier.

Example interface:

```systemverilog
module dense_layer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start_dense,
    input  logic signed [7:0] feature_pixel,
    input  logic        feature_valid,
    output logic        dense_done,
    output logic signed [19:0] logits [0:9]
);
endmodule
```

Responsibilities:

- consume the feature values in sequence
- multiply by stored weights for each class
- accumulate scores for digits 0 through 9
- output the final 10 logits

---

### 6.8 `rtl/argmax.sv`

Purpose: identify the largest score across all classes.

Example interface:

```systemverilog
module argmax (
    input  logic signed [19:0] logits [0:9],
    output logic [3:0]        winning_digit
);
endmodule
```

Responsibilities:

- compare the 10 logits
- choose the maximum value
- return the corresponding digit index

This is a straightforward and very common output stage for classification hardware.

---

### 6.9 `tb/tb_top.sv`

Purpose: validate the behavior of the design against expected results.

The testbench should:

1. initialize the clock and reset
2. load image and golden result vectors from `.mem` files
3. drive the `start` signal
4. stream pixels to the design
5. wait until `done` is asserted
6. compare the final prediction with the expected digit
7. report pass/fail and final accuracy
8. finish the simulation

This keeps verification standards high without requiring a large testing framework.

---

## 7. Implementation Roadmap

### Phase 1: Python and data export

- Prepare Python environment and install dependencies
- Download or load MNIST data
- Train a compact classifier
- Quantize weights to signed INT8 values
- Export `.mem` files for verification

### Phase 2: RTL building blocks

- implement `line_buffer.sv`
- implement `mac_unit.sv`
- implement `relu.sv`
- implement `dense_layer.sv`
- implement `argmax.sv`

### Phase 3: top-level integration

- connect the modules in `top_classifier.sv`
- implement the control FSM
- connect the weight memory and output logic

### Phase 4: simulation verification

- run `iverilog` simulations
- check outputs against `golden_outputs.mem`
- inspect waveform timing in GTKWave
- validate CI workflow execution

This is a realistic sequence for a portfolio project and keeps the work manageable.

---

## 8. Verification Standards

The project must be validated using simulation, not hardware synthesis.

Minimum checks:

- all RTL modules compile cleanly
- the testbench loads the correct data files
- the design outputs the expected digit for known test vectors
- the workflow can run in CI without requiring FPGA tools
- waveform inspection confirms the control FSM and MAC pipeline behave as expected

### Required verification rules

- use signed arithmetic where appropriate
- keep bit widths explicit and intentional
- use `$readmemh` for memory initialization only when format matches the exported data
- do not include Vivado or FPGA build scripts
- prefer simple, readable sequential logic and clean interfaces

---

## 9. Why This Is a Good Internship Project

This project is useful for internship applications because it demonstrates several valuable skills at once:

- Python machine learning fundamentals
- fixed-point digital arithmetic
- RTL design and simulation
- verification and debugging
- GitHub documentation and project structure
- end-to-end engineering workflow from training to hardware-style simulation

It is substantial enough to impress recruiters, but not so large that it becomes a major engineering project with high execution risk.

---

## 10. Success Criteria

The project is successful if it can do all of the following:

- read MNIST input data
- process a single image in a simple digital pipeline
- use fixed-point INT8 arithmetic in the core math
- output a predicted digit from 0 to 9
- pass the simulation testbench against known golden results
- be documented clearly enough for another engineer or recruiter to understand in under 10 minutes

This keeps the project focused on clarity, technical credibility, and portfolio value.

---

## 11. Final Scope Statement

This project is intentionally designed as a compact, realistic, and impressive MNIST-based RTL simulation project. It aims to show strong digital design and ML engineering skills without the overhead of a full-scale ASIC or FPGA deployment project.

The final result should feel like a serious engineering artifact: practical, testable, well-structured, and easy for employers to understand at a glance.
