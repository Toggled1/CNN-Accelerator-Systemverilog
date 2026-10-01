"""Python export flow for a compact MNIST CNN.

This script is responsible for generating the exact parameter and validation files used
by the RTL simulation. The architecture follows the project specification in README.md:

- Conv1: 3x3, 4 filters
- ReLU
- 2x2 max pooling
- Conv2: 3x3, 8 filters
- ReLU
- Flatten
- Dense: 968 -> 10 logits
- Argmax for class selection

The export must remain bit-accurate with the RTL design.
"""

from __future__ import annotations

# TODO: import torchvision / MNIST utilities and numpy.
# TODO: define or train the compact CNN architecture.
# TODO: export conv1_weights.mem, conv2_weights.mem, dense_weights.mem, biases.mem.
# TODO: generate input_images.mem, reference-prediction golden_outputs.mem, and ground-truth labels.mem.
# TODO: apply the README Q1.7-matching raw-pixel transform for floating-point training/inference.
# TODO: keep ordering consistent with the RTL flatten and dense layer logic.


def main() -> None:
    """Run the CNN parameter export and validation-file generation."""
    # TODO: load MNIST data.
    # TODO: train or construct a compact CNN matching the README specification.
    # TODO: serialize weights and biases into the .mem files used by the testbench.
    # TODO: export the fixed 100-image subset, integer-reference predictions, and separate labels.
    pass


if __name__ == "__main__":
    main()
