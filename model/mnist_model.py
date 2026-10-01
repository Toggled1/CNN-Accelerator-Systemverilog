"""Compact CNN definition for the MNIST RTL simulation project.

Architecture:
- Input: 28x28x1 MNIST image
- Conv1: 3x3 kernel, 4 filters
- ReLU
- MaxPool: 2x2 stride 2
- Conv2: 3x3 kernel, 8 filters
- ReLU
- Flatten to 968 values
- Dense: 968 -> 10 logits
- Argmax for digit prediction

The purpose of this file is to define the actual model used by the RTL design and the
Python export pipeline. The exported weights must match the hardware memory order.
"""

# TODO: define the model class and layer shapes.
# TODO: implement weight initialization for Conv1, Conv2, and Dense.
# TODO: maintain the same ordering that the hardware flatten and dense layers expect.
# TODO: ensure dimensions match the CNN specification in README.md.
