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

Expected parameter counts from that architecture are 36 Conv1 weights + 4 Conv1 biases, 288 Conv2 weights + 8 Conv2 biases, and 9,680 dense weights + 10 dense biases: 10,026 scalar parameters total. Stage 3.6 uses separate typed arrays loaded from the four exported files; there is no shared address bus.

## 3. Phase 0: Freeze the Implementable Contract

This phase is not optional. Keep the RTL and exporter unimplemented until every item below has a written, mutually consistent answer in `README.md`. After updating the README, review the whole document for contradictory earlier statements and update the interface examples and repository structure as needed.

### 3.1 Numerical representation and arithmetic

Status: resolved in `README.md` Section 5. The frozen convention is unsigned pixel `pixel_in[7:1]` converted to signed Q1.7; signed Q1.7 weights; signed Q6.14 biases, stored activations, pooled values, and logits; and one signed 40-bit accumulator for every convolution and dense dot product. Conv1 products and bias already share Q14 scale. Conv2 and Dense products use Q21 scale with the Q14 bias shifted left by 7; their completed sums use arithmetic right shift by 7, then signed 20-bit saturation. Conv1 sums saturate directly to signed 20 bits. Saturation clamps and never wraps. ReLU follows convolution narrowing/saturation, and pooling preserves the selected Q6.14 value.

Implementation work must follow the exact quantization and conversion rules in README Section 5, including ties-away-from-zero parameter quantization, explicit sign extension, exact signed shifts, and Python-reference equivalence. Do not reopen this design choice unless testing exposes a concrete failure to meet the project's stated requirements; if a change is necessary, update the canonical README and this plan together before implementing it.

### 3.2 Conv2 and intermediate tensor interface

Status: resolved in `README.md` Sections 6.4, 7.1.3, and 9.6. `conv_layer_2.sv` accepts `window[0:35]` of signed Q6.14 samples and `filter_weights[0:7][0:35]` of signed Q1.7 weights. For each sample, `index = ch * 9 + ky * 3 + kx`, so channel is the outer ordering, followed by kernel row and column. Each accepted window is one complete 3 x 3 neighborhood across all four channels. The module registers all eight saturated Q6.14 pre-ReLU results and asserts `valid_out` for the following cycle. The image contains 121 such windows, presented in row-major output-location order. This preserves the README's 4 input channels, 8 output filters, 36 weights per filter, and total parameter count.

Implementation must keep the explicit sample-to-weight index mapping and latency. Stage 3.3 defines the pooled-value order; Stage 3.4 defines the sequential no-backpressure controller and buffer behavior that feed the Conv2 window generator.

### 3.3 Pooling assembly and ordering

Status: resolved in `README.md` Sections 6.3, 7.2, 7.3, 7.4, and 9.7. The upstream producer supplies one complete same-channel 2 x 2 block in a single valid transfer. `pool_block[0:3]` order is top-left, top-right, bottom-left, bottom-right, mapped from input coordinate `(2*pr + dy, 2*pc + dx, ch)`. The pooling module compares the signed Q6.14 inputs, registers the unchanged maximum, and asserts `valid_out` for the following cycle. Blocks are ordered by pooled row, pooled column, then channel, yielding 676 scalar outputs per image; each consecutive group of four contains channels 0..3 at one pooled coordinate. The upstream producer assembles the four spatial values and supplies coordinates implicitly through this order. Since 26 is even and stride is 2, every input location belongs to exactly one pool block.

Implementation must preserve this block mapping, order, and latency. Stage 3.4 defines how this local `enable`/`valid_in` behavior integrates with the sequential FSM; there is no downstream stall or ready signal.

### 3.4 Streaming and control protocol

Status: resolved in `README.md` Sections 7.1, 7.1.7, 7.4, 9.2, and 9.3. The top-level accepts `start` only in `IDLE`, then accepts exactly 784 row-major unsigned pixels using `pixel_valid && ready` while in `LOAD_IMAGE`. Pixel-valid gaps pause input counting. `ready` is low during compute and after the final pixel. Reset is active-low asynchronous and aborts the current transaction; `done` is a one-cycle pulse in `DONE`, after which the FSM returns to `IDLE`.

The FSM processes one stage at a time in the specified state order, using the fixed-size image/interstage buffers and capacities listed in README Section 7.4. At the external image input, a pixel transfers on rising-edge `pixel_valid && ready`. Internally, modules with `valid_in` and `enable` accept on rising-edge `valid_in && enable`; the line buffer consumes `pixel_valid` during `CONV1`, Flatten consumes `valid_in` during `FLATTEN`, and Dense consumes `feature_valid` after `start_dense` during `DENSE`. There are no internal ready signals or backpressure. Disabled stages do not consume input, and source buffers retain items until use. `clear` is asserted before a window-generation scan and has priority over pixel input. Registered modules pulse `valid_out` with each result, and the controller counts captured outputs; stage changes depend on exact item counts rather than guessed delays. ReLU is combinational across a channel vector. Flatten publishes completion only after its full channel-major 968-value vector is ready; Dense signals completion with `dense_done` after producing all logits.

Implementation must follow the README buffer capacities, payload granularity, output counts, reset/start/done lifecycle, and no-backpressure rule. Do not convert the design into a concurrent elastic pipeline without revising the canonical specification and verification plan.

### 3.5 Flatten ordering and buffering

Status: the implementation choice is resolved in `README.md` Sections 7.1.6, 7.4, and 9.9. Flatten accepts one eight-channel vector for each spatial location in row-major order. For input location `(r,c)` and channel `ch`, it writes `feature_data[ch]` to `flattened_vector[ch * 121 + r * 11 + c]`. After 121 accepted vectors, it asserts `valid_out` for one cycle with the complete 968-element channel-major array. That vector remains stable throughout Dense, which consumes it sequentially by flat index. The Python model/export order and Dense weight order must use the same formula.

Implementation work remains in Phase 4: add an index-coded tensor test that checks every location/channel mapping, channel boundaries, first and last flat values, and full-vector completion. Keep the full vector stable until Dense has consumed all 968 entries.

### 3.6 Parameter memory format and typed-array mapping

Status: resolved in `README.md` Sections 7.1.5, 9.10, and 9.12. `weights_mem` exposes six immutable typed arrays loaded from the four exported files: Conv1 weights/biases, Conv2 weights/biases, and Dense weights/biases. There is no shared address bus, clock, reset, or read latency. Layer logic indexes the arrays directly; Dense uses `dense_weights[class][feature_index]` for each of its ten class accumulators.

The files contain 36 signed 8-bit Conv1 weights, 288 signed 8-bit Conv2 weights, 9,680 signed 8-bit Dense weights, and 22 signed 20-bit biases. Bias-file indices are Conv1 0..3, Conv2 4..11, and Dense 12..21. Each file is a one-value-per-line hex list, with two digits per weight and five per bias. The total remains 10,026 parameters. Implementation must preserve the README's local file-index formulas and confirm the selected simulator loads and exposes the unpacked arrays without reordering or truncation.

### 3.7 Golden outputs and reproducibility

Status: resolved in `README.md` Sections 9.1, 9.13, 10.3, 11, and 12. `golden_outputs.mem` stores the quantized integer reference's predicted class index, while the new `labels.mem` stores MNIST ground-truth labels. The testbench compares each RTL prediction exactly to the reference prediction, then separately counts correctness against labels. It reports both reference agreement and top-1 accuracy; accuracy has no pass/fail threshold. Dense unit tests compare all ten logits exactly.

Fixtures contain 100 official MNIST test examples: the first ten examples of each class, selected in canonical test-set order and stored class-major. Regeneration trains on the official 60,000-image training split with the fixed README CPU/seed/training policy, then regenerates parameters, inputs, integer-reference predictions, and labels together. CI uses the committed fixture set and never trains or downloads MNIST. Implementation and test work remains in Phases 3, 4, 6, and 7.

### 3.8 Tie behavior and invalid cases

Status: resolved in `README.md` Sections 7.4, 9.11, 9.12, and 9.13. Argmax is combinational over ten signed logits, initializes the winner to index 0, scans 1..9, and updates only on strict `>`, so ties select the lowest index. The Python integer reference uses the same tie rule. Argmax has no valid port; `winning_digit` is meaningful only when Dense asserts `dense_done`. The top captures it on the rising edge at the end of the cycle where `dense_done` is high, then asserts `done` for one cycle to qualify `predicted_digit`.

Unknown logits have no defined prediction. The testbench must fail if any logit is X/Z when `dense_done` is asserted. It must also confirm that all entries in the six typed parameter arrays are known before the first inference; offline fixture checks enforce exact file counts, and no inference may start after a failed initialization check. The fixed-size arrays have no runtime address port; all layer indices must stay within their documented ranges.

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
2. Serialize each parameter array using the exact README per-file index/order contract: Conv1 filter then kernel row/column; Conv2 output filter then input channel then kernel row/column; Dense class then input index; biases in Conv1, Conv2, Dense order. Emit exactly one scalar per line, with two hex digits for weights and five for biases.
3. Implement the exporter to produce the four parameter files, `input_images.mem`, reference-prediction `golden_outputs.mem`, and ground-truth `labels.mem` as one fixture set. Never leave comments or placeholder strings in a file intended for `$readmemh`.
4. Select exactly the first ten examples of each class from the canonical MNIST test split, preserving their original order within each class and writing classes in digit order. Train using the CPU/seed/5-epoch policy fixed in README Section 10.3. Regeneration is explicit; routine simulation and CI never train or download MNIST.
5. Validate generated data before writing: expected parameter counts (36, 288, 9,680 weights; 4, 8, 10 biases), legal ranges, exactly 100 images of 784 pixels, exactly 100 reference predictions and labels in 0..9, and identical sample ordering across the three validation files.
6. Write files atomically or fail without leaving partially overwritten fixtures. Print concise counts and paths so CI logs can diagnose export failures.
7. Add Python tests for serializer round trips, signed boundary encodings, ordering with index-coded arrays, counts, and malformed/range-invalid inputs.

Exit criteria: export creates valid files with exact counts and deterministic content; an independent parser or test reloads the files and reconstructs the same tensors and reference outputs.

## 7. Phase 4: Build the RTL from Small, Independent Modules Upward

Create focused testbenches under `tb/` for modules with meaningful state or arithmetic. Keep the full `tb/tb_top.sv` for integration. Each unit test must use small hand-calculated vectors and check data, valid timing, reset, and stalls according to the frozen protocol.

### 7.1 Argmax and ReLU

Implement `rtl/argmax.sv` and `rtl/relu.sv` first because their behavior is small and isolates signedness.

- Argmax compares all ten logits as signed values, returns 0..9, and updates only on strict `>` so ties retain the lowest index. Test each class as the unique maximum, all-negative logits, ties at several indices, and signed boundary values. Verify the top samples the result only while `dense_done` is high, and make the integration test fail on unknown logits at that event.
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
- Match the exact `(output_filter, input_channel, kernel_row, kernel_column)` weight order and direct typed-array indexing.
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
- For each accepted feature index `i`, read `dense_weights[class][i]` and the corresponding `dense_biases[class]` from the typed arrays. There is no ROM read latency; accumulate all ten classes with the Stage 3.1 arithmetic.
- Assert `dense_done` only after input feature 967 has been accumulated and all ten final outputs have been narrowed/registered as specified. Hold logits stable according to the interface contract.
- Test zero features, one nonzero feature at each boundary/index, one nonzero weight per class, bias-only results, negative values, overflow/rounding cases, and full-vector operation. Compare every logit, not only argmax.

Exit criteria: all ten RTL logits match the integer Python reference exactly for directed and generated vectors.

### 7.7 Typed parameter arrays

Implement `rtl/weights_mem.sv` to the exact Phase 0 typed-array contract.

- Expose the six typed arrays named and dimensioned in README Section 9.12, and load the four `.mem` files from the documented `sim/` working directory.
- Preserve signed 8-bit weights and signed 20-bit biases without cross-type reinterpretation. Arrays are constant after initialization and have no clocked read latency.
- Verify file element counts (36, 288, 9,680 weights; 22 biases), each local index formula, signed encodings, and output-array dimensions against generated exporter data.
- Compile a minimal test that reads first, last, and boundary elements from every output array using the selected simulator.

Exit criteria: every typed array element equals the corresponding exported value, all dimensions/counts match, and the simulator accepts the unpacked-array connections without unintended truncation or reordering.

## 8. Phase 5: Integrate the Sequential Pipeline and Control

Only integrate modules after their unit contracts pass.

1. Connect Conv1 -> ReLU1 -> Pool -> Conv2 windowing -> Conv2 -> ReLU2 -> Flatten -> Dense -> Argmax in `rtl/top_classifier.sv`.
2. Add/instantiate the required line-buffer or feature-map storage for both convolution stages. The existing line buffer comment describes Conv1, while Conv2 needs a four-channel activation line buffer or equivalent.
3. Implement `rtl/control_fsm.sv` to the frozen stage-by-stage protocol and exact state sequence. Keep the stages sequential; do not replace the fixed-buffer design with a concurrent elastic pipeline.
4. Ensure there is one source of truth for state/control: avoid independently duplicating counters or completion conditions in top and FSM.
5. Count accepted image pixels, windows, pool outputs, Conv2 locations, flattened values, and dense values. Detect or assert against early/late completion in simulation.
6. Assert top-level `ready` only while collecting image pixels and fewer than 784 have been accepted. A low `pixel_valid` pauses the input counter. Internal stages do not stall or backpressure; their fixed buffers retain data until the owning FSM state consumes it.
7. Define one-image lifecycle: reset/clear internal counters and buffers at the documented point, ignore or reject `start` while busy as specified, and assert `done` once for a complete prediction. The next inference must not depend on stale state from the previous image.
8. Add simulation-only assertions where supported for legal state progression, top-level valid/ready behavior, internal valid/enable acceptance, expected counts, and parameter bounds.

Exit criteria: a directed image traverses each sequential FSM phase with exact transfer counts, every required intermediate buffer is populated before use, and no protocol assertion fails; top prediction and logits match the Python integer reference.

## 9. Phase 6: End-to-End Testbench and MNIST Validation

Implement `tb/tb_top.sv` after the top-level interface is stable.

1. Generate clock and active-low reset; initialize all testbench signals before releasing reset.
2. Load the committed/generated input, model-parameter, reference-prediction, and ground-truth-label files from paths that work with `make -C sim run`. Before the first inference, verify exact file counts and that all input, reference, label, weight, and bias values are known; fail immediately on a malformed, missing, or unknown entry.
3. For each selected image, start one inference and send each of 784 unsigned pixels in row-major order according to `pixel_valid`/`ready`. Hold a pixel and valid asserted until accepted if the frozen handshake requires it.
4. Apply a configurable timeout per inference and fail if `done` is absent, early, repeated, or accompanied by an invalid prediction. On internal `dense_done`, assert all ten logits are known before the top captures Argmax; when `done` is high, require `predicted_digit` in 0..9.
5. Compare every RTL predicted digit exactly against the integer-reference index in `golden_outputs.mem`. Separately score it against `labels.mem`; do not confuse reference agreement with classification accuracy. Focused Dense tests compare all ten logits against the integer reference.
6. Report sample count, reference match count, number correct against labels, and accuracy. Any mismatch against reference predictions causes `$fatal` or a nonzero simulator exit so Make and CI fail; accuracy is reported without a minimum threshold.
7. Run multiple images in one simulator session to verify reset/clear/restart behavior and prove there is no cross-image state leakage.

Exit criteria: directed arithmetic tests, exported fixture checks, and end-to-end equivalence all pass; validation accuracy is reported according to the README criterion.

## 10. Phase 7: Simulation Workflow, Waveforms, and CI

1. Complete `sim/Makefile` so `compile` lists every required RTL source and the testbench, `run` executes the compiled simulation, `wave` opens the generated VCD with `sim/wave_config.gtkw`, and `clean` removes only generated outputs.
2. Make `sim/run_sim.sh` a reliable wrapper around compile and run. Verify invocation from the repository root and another directory.
3. Add `$dumpfile`/`$dumpvars` behind a documented testbench or simulator option so normal simulation does not produce unnecessary repository artifacts.
4. Populate `sim/wave_config.gtkw` only after final signal names are known. Include clock/reset, top pixel valid/ready, FSM state and stage enables, internal valid/enable signals, coordinate/counter state, representative MAC accumulator/weight data, dense completion/logits, and final prediction.
5. Update `.github/workflows/ci.yml` so a clean checkout installs Icarus, compiles the RTL, and runs simulation against committed deterministic fixtures. It may run lightweight offline Python fixture checks, but it must not train or download MNIST. Keep the CI job bounded and make each failure propagate to the workflow.
6. Avoid dependence on an interactive GTKWave session in CI. GTKWave remains a local debug target; the waveform file should be optional.
7. Keep training and fixture regeneration out of CI. CI consumes the committed parameter, image, reference-prediction, and label files so it is deterministic and does not depend on MNIST downloads.

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
10. Implement/test typed parameter arrays and dense accumulation against the reference.
11. Integrate top and control FSM; verify handshakes and exact element counts.
12. Complete end-to-end testbench, Makefile/scripts, wave setup, and CI.
13. Update documentation and run the clean full regression.

No RTL or Python implementation should be considered complete merely because it compiles. Every stage must be shown to preserve its specified shape, signed arithmetic, ordering, valid timing, reset behavior, and exact outputs against a focused reference test.
