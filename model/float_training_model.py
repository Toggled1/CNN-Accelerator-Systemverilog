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

The purpose of this file is to define the actual model in floating point used by the RTL design and the
Python export pipeline. The exported weights must match the hardware memory order.
"""

import torch
import torch.nn as nn

# Hardware parameter ranges: weights are Q1.7, biases are Q6.14.

# [-1.0, 0.9921875]
WEIGHT_MIN, WEIGHT_MAX = -(2**0), 2**0 - 2**(-7) # 0 integer bits (1 sign bit)
# [-32, 31.999...]
BIAS_MIN, BIAS_MAX = -(2**5), 2**5 - 2**(-14) # 5 integer bits (1 sign bit)

#0.0... 1.0 since transforms.ToTensor() was used on Raw MNIST in train_and_export.py
def rtl_input_scaling(img: torch.Tensor) -> torch.Tensor:

    pixels = torch.round(img * 255.0) #bring back to origional grayscale pixel values (0 to 255)
    return torch.floor(pixels / 2.0) / 128.0 # scale to Q1.7 range





#definition of float-approximate CNN model for the RTL forward
class CNN(nn.Module):
    def __init__(self):
        super().__init__()
        # Weighted layers are at indices 0 (conv1), 3 (conv2) and 6 (dense).
        self.cnn_stack = nn.Sequential(
            nn.Conv2d(1, 4, kernel_size=3),  # 28x28x1 -> 26x26x4
            nn.ReLU(),
            nn.MaxPool2d(2, 2),              # 26x26x4 -> 13x13x4
            nn.Conv2d(4, 8, kernel_size=3),  # 13x13x4 -> 11x11x8
            nn.ReLU(),
            # (N, C, H, W) flatten gives ch * 121 + r * 11 + c, the RTL channel-major order.
            nn.Flatten(),                    # 11x11x8 -> 968
            nn.Linear(8 * 11 * 11, 10),      # 968 -> 10 logits # same is "dense" in the rtl
        )

    def forward(self, x):
        logits = self.cnn_stack(x)
        return logits


    #here is the function to clamp the model parameters to the params above
    @torch.no_grad()
    def clamp_to_hardware_range(self):
        for name, p in self.named_parameters():
            if name.endswith("bias"):
                p.clamp_(BIAS_MIN, BIAS_MAX)
            else:
                p.clamp_(WEIGHT_MIN, WEIGHT_MAX)
