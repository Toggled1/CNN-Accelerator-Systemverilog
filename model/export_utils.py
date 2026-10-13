"""

helper functions for quantization and for writing the test_vector .mem files!

"""

from pathlib import Path

import numpy as np

WEIGHT_FRAC_BITS = 7 # for Q1.7
BIAS_FRAC_BITS = 14 # for Q6.14

#integer ranges
WEIGHT_MIN, WEIGHT_MAX = -(1 << 7), (1 << 7) - 1 
BIAS_MIN, BIAS_MAX = -(1 << 19), (1 << 19) - 1 


def _round_half_away(x: np.ndarray) -> np.ndarray:
    return np.sign(x) * np.floor(np.abs(x) + 0.5) #rounds to nearest whole number with exact halves goning away from zero.


def quantize_weights(w) -> np.ndarray:
    scaled = _round_half_away(np.asarray(w, dtype=np.float64) * (1 << WEIGHT_FRAC_BITS))
    return np.clip(scaled, WEIGHT_MIN, WEIGHT_MAX).astype(np.int64)


def quantize_biases(b) -> np.ndarray:
    scaled = _round_half_away(np.asarray(b, dtype=np.float64) * (1 << BIAS_FRAC_BITS))
    return np.clip(scaled, BIAS_MIN, BIAS_MAX).astype(np.int64)


def quantize_model(model) -> dict[str, np.ndarray]:
    """Quantize CNN parameters into the integer layouts the RTL arrays use."""
    conv1, conv2, dense = model.cnn_stack[0], model.cnn_stack[3], model.cnn_stack[6]

    def w(layer):
        return quantize_weights(layer.weight.detach().cpu().numpy())

    def b(layer):
        return quantize_biases(layer.bias.detach().cpu().numpy())

    return {
        "conv1_w": w(conv1).reshape(4, 3, 3),     # [filter][ky][kx]
        "conv1_b": b(conv1),
        "conv2_w": w(conv2),                      # [filter][ch][ky][kx]
        "conv2_b": b(conv2),
        "dense_w": w(dense),                      # [class][input]
        "dense_b": b(dense),
    }


def to_hex(value: int, digits: int) -> str:
    # keeps just the lowest (4*digits) bit of the sign-extended int value."""
    return format(int(value) & ((1 << (4 * digits)) - 1), f"0{digits}x") 


def write_mem(path: Path, values, digits: int, expected_count: int) -> None:

    # after converting to numpy array, flattens the array to 1-D in row major ordering
    flat = np.asarray(values).reshape(-1)

    if (flat.size != expected_count):
        raise ValueError(f"{path.name}: expected {expected_count} values, got {flat.size}")

    path.write_text("".join(to_hex(v, digits) + "\n" for v in flat))
