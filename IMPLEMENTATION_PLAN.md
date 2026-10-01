# MNIST CNN RTL Simulation: Implementation Plan

## 1. Purpose and Authority

This document is the step-by-step execution guide for completing the project. It is subordinate to `README.md`, which remains the canonical specification. This plan must not silently redefine the architecture, arithmetic, interfaces, file formats, or verification criteria in the README.

The README currently fixes the network structure and several ordering rules, but it also contains unresolved or conflicting details that make exact implementation impossible. Therefore, Phase 0 below is a required specification-freeze phase. Do not implement dependent RTL or export code until each listed decision has been resolved and the README updated. Once Phase 0 is complete, the resulting README contract is authoritative and the remaining phases proceed in order.

This is a simulation-only project. Do not add FPGA, synthesis, board, ASIC, or physical-timing deliverables.

## 2. Current Baseline

The current workspace contains the following project components:

- `model/mnist_model.py`, `model/train_and_export.py`, and `model/export_utils.py`: TODO scaffolds.
- `model/requirements.txt`: lists NumPy, PyTorch, and Torchvision, with an unfinished comment for any additional dependencies.
- `rtl/`: top-level, control FSM, line buffer, Conv1, Conv2, pooling, ReLU, flatten, dense, argmax, and parameter-memory scaffolds. These are not functioning implementations.
- `tb/tb_top.sv`: a TODO testbench that currently terminates immediately.
- `tb/test_vectors/*.mem`: placeholder text, not usable numeric model or input data.
- `sim/Makefile`: target names and source lists exist, but compile/run/wave commands are TODOs.
- `sim/run_sim.sh`: invokes the Makefile targets.
- `.github/workflows/ci.yml`: intends to install Icarus/Python dependencies, run export, compile, and simulate, but the required flows are not implemented.
- `sim/wave_config.gtkw`: placeholder only.
- `LICENSE`: TODO placeholder; public licensing remains optional per the README.

The intended architecture, as fixed by the README, is:

| Stage | Input shape | Operation | Output shape |
|---|---:|---|---:|
| Image | 28 x 28 x 1 | Unsigned 8-bit MNIST pixels, streamed row-major | 28 x 28 x 1 |
| Conv1 | 28 x 28 x 1 | 3 x 3 valid convolution, 4 filters | 26 x 26 x 4 |
| ReLU1 | 26 x 26 x 4 | Per-value signed ReLU | 26 x 26 x 4 |
| MaxPool | 26 x 26 x 4 | 2 x 2, stride 2, per channel | 13 x 13 x 4 |
| Conv2 | 13 x 13 x 4 | 3 x 3 valid convolution, 8 filters, sum across 4 channels | 11 x 11 x 8 |
| ReLU2 | 11 x 11 x 8 | Per-value signed ReLU | 11 x 11 x 8 |
| Flatten | 11 x 11 x 8 | 968 values, channel-major then row-major then column-major | 968 |
| Dense | 968 | Ten class dot products plus biases | 10 signed logits |
| Argmax | 10 logits | Select the winning class | 4-bit digit index, 0..9 |

Expected parameter counts from that architecture are 36 Conv1 weights + 4 Conv1 biases, 288 Conv2 weights + 8 Conv2 biases, and 9,680 dense weights + 10 dense biases: 10,026 scalar parameters total. A 14-bit address can address locations 0 through 10,025, but this fact alone does not specify the ROM word format or read interface.

## 3. Phase 0: Freeze the Implementable Contract

This phase is not optional. Keep the RTL and exporter unimplemented until every item below has a written, mutually consistent answer in `README.md`. After updating the README, review the whole document for contradictory earlier statements and update the interface examples and repository structure as needed.

### 3.1 Numerical representation and arithmetic

Status: resolved in `README.md` Section 5. The frozen convention is unsigned pixel `pixel_in[7:1]` converted to signed Q1.7; signed Q1.7 weights; signed Q6.14 biases, stored activations, pooled values, and logits; and one signed 40-bit accumulator for every convolution and dense dot product. Conv1 products and bias already share Q14 scale. Conv2 and Dense products use Q21 scale with the Q14 bias shifted left by 7; their completed sums use arithmetic right shift by 7, then signed 20-bit saturation. Conv1 sums saturate directly to signed 20 bits. Saturation clamps and never wraps. ReLU follows convolution narrowing/saturation, and pooling preserves the selected Q6.14 value.

Implementation work must follow the exact quantization and conversion rules in README Section 5, including ties-away-from-zero parameter quantization, explicit sign extension, exact signed shifts, and Python-reference equivalence. Do not reopen this design choice unless testing exposes a concrete failure to meet the project's stated requirements; if a change is necessary, update the canonical README and this plan together before implementing it.

### 3.2 Conv2 and intermediate tensor interface

The README equation requires a 3 x 3 receptive field for each of four pooled input channels. Current `conv_layer_2.sv` exposes only `window[0:8]` of signed 8-bit values and eight 9-value filters, which cannot represent the documented equation or the documented 288 Conv2 weights.

Specify the RTL representation for all 36 samples in a Conv2 receptive field, their channel/kernel ordering, their width, and how each of eight filters obtains its 36 matching weights. Keep the documented equation and parameter count unless the README architecture is deliberately revised. The Conv2 input values must use the same width and scale as pooled Conv1 activations.

### 3.3 Pooling assembly and ordering

The README fixes 2 x 2 max-pooling with stride 2, applied independently to each of four channels, but describes both a neighborhood array and values assembled over time. Current `pooling_layer.sv` accepts four signed 20-bit values at once and returns one scalar; it has no channel or coordinate inputs.

Document the exact order of the four elements (top-left, top-right, bottom-left, bottom-right), when a block is considered complete, how odd/even row and column positions map to non-overlapping stride-2 blocks, and how the four channels are sequenced. Define whether a complete block is presented in one cycle or assembled over multiple valid cycles. The output ordering must allow Conv2 to reconstruct the pooled 13 x 13 x 4 tensor without guessing.

### 3.4 Streaming and control protocol

The README calls the design a streaming pipeline with valid/ready behavior, but only the top-level example has `ready`. Existing internal module ports are mostly `valid_in`/`valid_out` or enable signals and do not provide consistent ready/backpressure. The README also names a stage-by-stage FSM, which can imply whole-stage sequencing rather than an always-flowing pipeline.

Specify one protocol for every boundary:

1. Whether an input transfers on `valid && ready`, or whether a valid-only, fixed-rate interface is used.
2. Whether `ready` is required between every pair of stages or only at the top-level image input.
3. How the pipeline behaves when input `pixel_valid` pauses.
4. Whether internal stages may stall and how upstream values are retained during a stall.
5. How `start`, `clear`, `ready`, `done`, and reset interact; define whether `done` is a pulse or a held level and when a new image may start.
6. How each module signals completion, including the final feature-map item and the final flattened value.
7. Whether each stage operates concurrently as a pipeline or the controller processes complete stage tensors in FSM phases. If phase-based, specify where intermediate tensors are buffered and how large they are.
8. Whether each valid output corresponds to a scalar, a vector of all channels at one coordinate, or a complete neighborhood.

Do not implement handshakes based only on comments. Add every required signal to the owning interface and document transfer/hold behavior.

### 3.5 Flatten ordering and buffering

The README explicitly fixes channel-major order:

```text
for ch = 0..7:
  for row = 0..10:
    for col = 0..10:
      flat.push(conv2_out[ch][row][col])
```

The current flatten port receives eight channel values together, which naturally represents one spatial coordinate at a time. A location-major stream of those eight-value vectors is not already channel-major. To preserve the README order, either define the storage/reordering required by Flatten, or revise the data production protocol so channel-major values arrive in sequence. State precisely which option the implementation will use, how it identifies all 121 spatial positions, and when `valid_out` indicates that the flattened vector is complete or an individual value is available. The Python model/export order and dense memory order must use this same choice.

### 3.6 Parameter memory format and address map

The README requires separate files `conv1_weights.mem`, `conv2_weights.mem`, `dense_weights.mem`, and `biases.mem`, and also calls the parameter memory a single flat 10,026-entry array. Current `weights_mem.sv` exposes one address with both an 8-bit weight output and a 20-bit bias output. These statements do not define one unambiguous storage/read interface.

Choose and document one implementation:

- Separate typed arrays/files with explicit per-array addresses and read ports; or
- One unified array with a defined common word width/encoding, exact region base addresses and lengths, signed decoding rules, and an interface that selects a parameter type; or
- Another fully specified representation that preserves the four exported files and removes the simultaneous weight/bias ambiguity.

For whichever option is selected, publish an address table showing exact index ranges, element widths, and the mapping from `(layer, filter/class, channel, kernel position/input index)` to address. State whether simulation reads are combinational or registered and their latency. Confirm the total count remains 10,026 scalar parameters.

### 3.7 Golden outputs and reproducibility

The README says the testbench compares predictions with expected digit labels, but it does not say whether `golden_outputs.mem` contains dataset labels or predictions from the quantized Python model. These validate different things. Define both clearly:

- RTL-versus-Python equivalence should compare the quantized reference's logits and/or predicted index with the RTL result for the exact same exported model and input.
- Classification accuracy should compare predictions with MNIST ground-truth labels and should have a documented validation subset and reporting rule.

Specify which file holds which values, deterministic sample selection, random seeds, model/training policy, and whether CI requires downloading MNIST or uses checked-in deterministic vectors. A classification label alone is not a substitute for bit-accurate equivalence.

### 3.8 Tie behavior and invalid cases

Define argmax tie behavior (recommended: retain the lowest digit index by replacing the winner only on strict `>`), behavior for unknown/uninitialized logits if relevant to simulation, and when the top-level prediction is considered valid. Define parameter-memory behavior for out-of-range addresses. Add these to the README rather than leaving behavior implicit.

### 3.9 Phase 0 exit criteria

Phase 0 is complete only when:

- Every numbered decision above has a concrete answer in `README.md`.
- All module port examples/required behaviors support those answers.
- The numerical equations, data order, widths, and memory mapping agree across README sections.
- A small interface table names each stage's input/output payload, valid/ready signals, reset behavior, and completion condition.
- A reviewer can determine the value and index presented on every transfer without asking what a signal or array element means.

## 4. Phase 1: Establish the Toolchain and Verification Skeleton

Do this before writing substantive datapath logic. Keep CI reproducible and make failure visible.

1. Confirm the intended simulator and version. The current CI targets Icarus Verilog; verify that it supports the SystemVerilog array ports and constructs the RTL will use. If it does not, update the README/CI to a supported Verilator path or adjust interfaces before building around unsupported constructs.
2. Implement the minimum `sim/Makefile` `compile`, `run`, `wave`, and `clean` targets. `compile` must compile every RTL module and the testbench with explicit SystemVerilog mode, fail on compiler errors, and produce a known output filename. `run` must execute that output and propagate a nonzero simulation failure status.
3. Make `sim/run_sim.sh` call those targets from any current working directory and fail immediately on errors.
4. Replace the testbench's immediate `$finish` with a clock/reset smoke test and a temporary top-level instance once the top interface is frozen. A test must fail if the DUT never completes within a bounded cycle count.
5. Ensure generated simulator files are ignored by `.gitignore` and removed by `make clean` without deleting source vectors.
6. Run compile and smoke simulation locally before adding model complexity. Record the exact successful commands in the README workflow section.

Exit criteria: clean checkout can compile and run the smallest test, and an intentional compile/runtime failure returns nonzero.

## 5. Phase 2: Implement the Python Model and Numerical Reference

Do not train/export weights until Phase 0 fixes arithmetic and data semantics.

1. Implement `model/mnist_model.py` with the exact README topology: Conv1 1->4, 3 x 3 valid; ReLU; 2 x 2 max-pool stride 2; Conv2 4->8, 3 x 3 valid; ReLU; flatten to 968 in the frozen order; dense 968->10. Use PyTorch modules or an equivalent explicitly documented implementation consistent with current dependencies.
2. Add shape checks for a batch of 28 x 28 images at every boundary: 26 x 26 x 4, 13 x 13 x 4, 11 x 11 x 8, 968, and 10. Make layout conversions explicit so framework channel order cannot silently differ from the RTL convention.
3. Implement reproducible initialization/training in `train_and_export.py`: fixed seeds, documented training/validation split, explicit model save/load behavior, and no hidden training during RTL compilation.
4. Implement a bit-accurate integer inference reference that follows the frozen RTL arithmetic step by step, including signed operations, bias addition, intermediate narrowing, rounding, clipping/saturation, and wrap behavior if any. Keep this separate and testable from floating-point model inference.
5. Add tests for quantization boundary values and arithmetic boundaries, including negative products, maximum/minimum representable values, rounding ties, and saturation/overflow behavior selected in Phase 0.
6. Compare the integer reference against the quantized PyTorch model on a small set of samples. Any acceptable difference must be explicitly explained by the chosen quantization contract; do not conceal mismatch with a loose tolerance.

Exit criteria: shapes are exact, reruns with the same seed/persisted checkpoint are reproducible, and the Python integer reference produces deterministic intermediate tensors, logits, and class indices.

## 6. Phase 3: Implement Export Utilities and Generate Real Fixtures

1. Implement `model/export_utils.py` with dedicated, tested serializers for signed 8-bit weights, the selected bias/activation/score widths, raw unsigned image bytes, and digit values. Encode negative two's-complement values to exactly the documented number of hex digits. Reject out-of-range values instead of silently truncating unless truncation is the explicitly frozen rule.
2. Serialize each parameter array using the exact README address/order contract: Conv1 filter then kernel row/column; Conv2 output filter then input channel then kernel row/column; Dense class then input index; biases in Conv1, Conv2, Dense order. If Phase 0 chooses a different memory representation, document how these four exported files feed it.
3. Implement the exporter to produce the four parameter files plus input images and the explicitly defined golden/reference files. Never leave comments or placeholder strings in a file intended for `$readmemh`.
4. Set and document deterministic sample selection. Keep a small, bounded simulation subset suitable for CI; keep model training/download separate from ordinary RTL regression where possible. If CI is required to train, ensure dataset availability and runtime are reliable, or change the README/CI to use deterministic checked-in test artifacts.
5. Validate generated data before writing: expected element counts (36, 288, 9,680 weights; 4, 8, 10 biases), legal ranges, exact image count x 784, labels in 0..9, and alignment between images, reference outputs, and labels.
6. Write files atomically or fail without leaving partially overwritten fixtures. Print concise counts and paths so CI logs can diagnose export failures.
7. Add Python tests for serializer round trips, signed boundary encodings, ordering with index-coded arrays, counts, and malformed/range-invalid inputs.

Exit criteria: export creates valid files with exact counts and deterministic content; an independent parser or test reloads the files and reconstructs the same tensors and reference outputs.

## 7. Phase 4: Build the RTL from Small, Independent Modules Upward

Create focused testbenches under `tb/` for modules with meaningful state or arithmetic. Keep the full `tb/tb_top.sv` for integration. Each unit test must use small hand-calculated vectors and check data, valid timing, reset, and stalls according to the frozen protocol.

### 7.1 Argmax and ReLU

Implement `rtl/argmax.sv` and `rtl/relu.sv` first because their behavior is small and isolates signedness.

- Argmax compares all ten logits as signed values, returns 0..9, and obeys frozen tie behavior. Test each index as the unique maximum, all-negative logits, equal maxima, and signed boundary values.
- ReLU maps negative signed input to zero and preserves nonnegative input exactly unless Phase 0 explicitly specifies a requantization/clipping function. Test zero, negative one, minimum, positive one, and maximum.

Exit criteria: their unit tests pass without unknown outputs after reset/settling, with all comparisons explicitly signed.

### 7.2 Line buffer and Conv1

Implement `rtl/line_buffer.sv` as the Conv1 image-window generator, then implement `rtl/conv_layer_1.sv`.

- Track the 28-pixel row boundaries; do not allow a window to bridge the end of one row to the start of the next.
- Generate 676 valid windows per image, one for each of the 26 x 26 Conv1 output positions. Define `window[0:8]` in row-major order from the frozen contract.
- Honor `pixel_valid`, reset, and `clear` exactly. A missing input pixel must not advance the accepted-pixel count or corrupt a future window.
- For each window, calculate four independent 3 x 3 dot products with the correct filter's weights and bias, using explicitly sized signed products and the frozen accumulator/narrowing rules.
- Produce four Conv1 values for each spatial coordinate in the order specified in Phase 0. Apply ReLU at the documented boundary; avoid applying it both inside Conv1 and again in the ReLU stage.
- Test first valid window timing, all corners, row wrap, invalid gaps, one full image's count, negative/positive dot products, bias inclusion, filter isolation, and reset between images.

Exit criteria: line-buffer windows and all Conv1 outputs match the Python integer reference exactly, including valid cycles and output count.

### 7.3 ReLU1 and MaxPool

Connect Conv1 to ReLU1 and implement `rtl/pooling_layer.sv` using the frozen 2 x 2/stride-2 semantics.

- Pool independently within each of four channels; never compare values from different channels.
- Confirm 26 x 26 becomes 13 x 13 per channel, for 676 pooled scalar values total (169 locations x 4 channels).
- Preserve the chosen spatial/channel order and feed timing required by Conv2.
- Test maxima at each of the four positions, equal values, negative inputs if the module can receive them, invalid cycles, block boundaries, stride advancement, and the exact 676-output count.

Exit criteria: the pooled tensor equals the Python reference and every pool block consumes exactly four corresponding same-channel values.

### 7.4 Conv2 window generation and Conv2 arithmetic

Implement the Conv2 feature-map neighborhood storage/window generation required by the frozen interface, then implement `rtl/conv_layer_2.sv`.

- Preserve all four channels for each pooled spatial coordinate and form 3 x 3 neighborhoods with 36 samples total.
- Match the exact `(output_filter, input_channel, kernel_row, kernel_column)` weight order and address calculation.
- Calculate eight output channels for each of the 11 x 11 locations, reducing across all four input channels and all nine kernel positions per channel.
- Keep Conv2's input and output widths aligned with the frozen numerical contract. Do not narrow pooled activations to 8 bits without an explicit conversion rule.
- Apply ReLU exactly once at the documented boundary.
- Test single-channel/single-tap impulses to prove channel and kernel indexing, bias, signed products, boundaries, and all 121 output positions x 8 channels.

Exit criteria: all 968 Conv2 outputs match the integer reference with exact location/channel ordering.

### 7.5 Flatten

Implement `rtl/flatten_layer.sv` after the Conv2 stream order is verified.

- Preserve the README's channel-major, row-major, column-major mapping unless Phase 0 formally revises it.
- If Conv2 supplies all eight channels for one location per transfer, use the explicitly specified storage/reorder strategy to emit channel-major order. Address all 121 locations for each of eight channels; do not simply append location vectors and call the result channel-major.
- Define the interface meaning of `valid_in` and `valid_out`, including whether the output vector is held as a complete 968-entry array or emitted one scalar per accepted cycle. Match the dense input protocol.
- Test index-coded features so every tensor coordinate can be traced to its exact flat index. Check first, last, and channel-transition indices, plus full-vector completion timing.

Exit criteria: RTL flatten output equals the Python flatten result element-for-element for an index-coded 11 x 11 x 8 tensor.

### 7.6 Dense

Implement `rtl/dense_layer.sv` after flatten order, parameter access, and numerical accumulation are locked.

- Initialize ten independent class accumulators from their matching biases at `start_dense`.
- For each accepted flattened feature index 0..967, multiply it by the weight for each class and accumulate using the specified widths and scale conversion.
- Read each class's contiguous 968-weight vector according to the frozen memory latency/address map. Ensure synchronous ROM latency, if selected, is accounted for without pairing a feature with the wrong weight.
- Assert `dense_done` only after input feature 967 has been accumulated and all ten final outputs have been narrowed/registered as specified. Hold logits stable according to the interface contract.
- Test zero features, one nonzero feature at each boundary/index, one nonzero weight per class, bias-only results, negative values, overflow/rounding cases, and full-vector operation. Compare every logit, not only argmax.

Exit criteria: all ten RTL logits match the integer Python reference exactly for directed and generated vectors.

### 7.7 Parameter ROM

Implement `rtl/weights_mem.sv` to the exact Phase 0 storage map.

- Load all exported files using explicit paths valid from the documented simulation working directory.
- Use signed storage/extension for each type. A 14-bit address is sufficient for 10,026 entries but does not by itself distinguish 8-bit weights from 20-bit biases; implement the chosen type/region selection explicitly.
- Define reset/read behavior, registered or combinational latency, and out-of-range behavior.
- Test addresses at the first and last element of every region and around every region boundary; compare the returned signed values against the exporter.

Exit criteria: all parameter addresses map to exactly one intended exported value and no boundary address aliases another tensor.

## 8. Phase 5: Integrate the Streaming Pipeline and Control

Only integrate modules after their unit contracts pass.

1. Connect Conv1 -> ReLU1 -> Pool -> Conv2 windowing -> Conv2 -> ReLU2 -> Flatten -> Dense -> Argmax in `rtl/top_classifier.sv`.
2. Add/instantiate the required line-buffer or feature-map storage for both convolution stages. The existing line buffer comment describes Conv1, while Conv2 needs a four-channel activation line buffer or equivalent.
3. Implement `rtl/control_fsm.sv` to the frozen protocol. Do not retain state names merely for appearance if the specified stages are a concurrent valid pipeline; use states/signals that correctly describe actual sequencing and update the README accordingly.
4. Ensure there is one source of truth for state/control: avoid independently duplicating counters or completion conditions in top and FSM.
5. Count accepted image pixels, windows, pool outputs, Conv2 locations, flattened values, and dense values. Detect or assert against early/late completion in simulation.
6. Assert `ready` only when the top can accept the next input item. Ensure a stalled `pixel_valid` or downstream stall cannot drop or duplicate data.
7. Define one-image lifecycle: reset/clear internal counters and buffers at the documented point, ignore or reject `start` while busy as specified, and assert `done` once for a complete prediction. The next inference must not depend on stale state from the previous image.
8. Add simulation-only assertions where supported for legal state progression, valid/ready stability, expected counts, and parameter bounds.

Exit criteria: a directed image traverses the integrated DUT with exact transfer counts and no protocol assertion failures; top prediction and logits match the Python integer reference.

## 9. Phase 6: End-to-End Testbench and MNIST Validation

Implement `tb/tb_top.sv` after the top-level interface is stable.

1. Generate clock and active-low reset; initialize all testbench signals before releasing reset.
2. Load the generated input, model parameter, Python reference, and label files from paths that work with `make -C sim run`.
3. For each selected image, start one inference and send each of 784 unsigned pixels in row-major order according to `pixel_valid`/`ready`. Hold a pixel and valid asserted until accepted if the frozen handshake requires it.
4. Apply a configurable timeout per inference and fail if `done` is absent, early, repeated, or accompanied by an invalid prediction.
5. Compare RTL logits and/or predictions to quantized Python golden outputs as explicitly chosen in Phase 0. Separately report classification accuracy against true dataset labels; do not confuse reference equivalence with accuracy.
6. Report sample count, exact-equivalence pass/fail, number correct against labels, and accuracy. Ensure any mismatch causes `$fatal` or a nonzero simulator exit so Make and CI fail.
7. Run multiple images in one simulator session to verify reset/clear/restart behavior and prove there is no cross-image state leakage.

Exit criteria: directed arithmetic tests, exported fixture checks, and end-to-end equivalence all pass; validation accuracy is reported according to the README criterion.

## 10. Phase 7: Simulation Workflow, Waveforms, and CI

1. Complete `sim/Makefile` so `compile` lists every required RTL source and the testbench, `run` executes the compiled simulation, `wave` opens the generated VCD with `sim/wave_config.gtkw`, and `clean` removes only generated outputs.
2. Make `sim/run_sim.sh` a reliable wrapper around compile and run. Verify invocation from the repository root and another directory.
3. Add `$dumpfile`/`$dumpvars` behind a documented testbench or simulator option so normal simulation does not produce unnecessary repository artifacts.
4. Populate `sim/wave_config.gtkw` only after final signal names are known. Include clock/reset, top handshake/control, each stage's valid/ready signals, coordinate/counter state, representative MAC accumulator/weight data, dense completion/logits, and final prediction.
5. Update `.github/workflows/ci.yml` so a clean checkout installs only necessary dependencies, runs Python unit/export checks, compiles the RTL, and runs deterministic simulation. Keep the CI job bounded and make each failure propagate to the workflow.
6. Avoid dependence on an interactive GTKWave session in CI. GTKWave remains a local debug target; the waveform file should be optional.
7. If CI calls training or downloads MNIST, verify the action is deterministic and reliable under GitHub-hosted runner network/runtime limits. Prefer validating checked-in or generated deterministic fixtures unless the README explicitly requires live dataset acquisition in CI.

Exit criteria: the same documented command sequence works locally; GitHub Actions performs compile and self-checking simulation on a clean checkout and fails on intentional errors.

## 11. Phase 8: Documentation, Cleanup, and Completion Review

1. Update `README.md` whenever Phase 0 decisions or implemented interfaces change. It remains the canonical source for architecture, numeric formats, orderings, ports/protocol, memory map, tools, and verification.
2. Remove stale TODO comments and placeholder instructions only when the corresponding behavior has been implemented and tested. Do not delete useful interface rationale.
3. Replace the `LICENSE` placeholder only if the project owner chooses to publish under a license; do not invent a license.
4. Confirm `.gitignore` excludes build products, Python caches, virtual environments, logs, and waveforms but does not hide required fixtures or source.
5. Review all model/export/RTL/testbench ordering side by side: filter order, channel order, kernel order, flatten order, dense class/input order, bias order, and signed hex formatting.
6. Run the full documented local workflow from a clean generated-output state. Inspect failures rather than weakening comparisons.
7. Review `git diff` and `git status` to ensure generated binaries/waveforms are not accidentally committed and only intended project files changed.

The project is complete only when the README verification requirements pass: all RTL compiles, files load correctly, Python/RTL results agree under the frozen arithmetic contract, the selected MNIST subset is checked and its accuracy reported, simulation completes within timeout, and the repository remains simulation-only and reproducible.

## 12. Suggested Working Rhythm

For every implementation slice:

1. Read the owning module and its README contract immediately before editing.
2. Implement only that module or tightly coupled boundary.
3. Compile/run its focused test immediately.
4. Fix failures in the same slice before moving on.
5. Add the behavior to the integration regression.
6. Update the README if observed behavior required a contract correction; never let code and documentation drift.

Recommended order at a glance:

1. Resolve and document Phase 0 decisions.
2. Prove the simulator can compile the selected SystemVerilog interfaces; establish a smoke regression.
3. Implement model shapes and bit-accurate Python reference.
4. Implement serializers and deterministic numeric fixtures.
5. Implement/test argmax and ReLU.
6. Implement/test line buffer and Conv1.
7. Implement/test pooling.
8. Implement/test multi-channel Conv2 windowing and Conv2.
9. Implement/test flatten reorder.
10. Implement/test parameter ROM and dense accumulation against the reference.
11. Integrate top and control FSM; verify handshakes and exact element counts.
12. Complete end-to-end testbench, Makefile/scripts, wave setup, and CI.
13. Update documentation and run the clean full regression.

No RTL or Python implementation should be considered complete merely because it compiles. Every stage must be shown to preserve its specified shape, signed arithmetic, ordering, valid timing, reset behavior, and exact outputs against a focused reference test.
