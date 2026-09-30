"""TODO: Implement the Python model export flow described in Section 9.1 of README.md.

Required behavior:
- load the MNIST dataset
- define or train a compact model suitable for inference
- convert floating-point weights to signed 8-bit values
- export weights.mem, biases.mem, input_images.mem, and golden_outputs.mem
- keep export ordering consistent with the RTL memory layout
- generate validation samples and expected labels for the SystemVerilog testbench

This file is the source of truth for the numerical values used by the RTL simulation.
"""

from __future__ import annotations

# TODO: add imports for MNIST dataset handling, numpy, and any model code.
# TODO: implement model definition or training flow.
# TODO: quantize weights to signed 8-bit values.
# TODO: generate .mem files for weights, biases, and validation inputs.
# TODO: write golden outputs for expected digit labels.
# TODO: ensure the export order matches the RTL memory layout exactly.


def main() -> None:
    """TODO: implement the end-to-end export flow per the README specification."""
    pass


if __name__ == "__main__":
    main()
