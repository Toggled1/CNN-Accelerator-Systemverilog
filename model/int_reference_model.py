

import numpy as np
from numpy.lib.stride_tricks import sliding_window_view

#create a predict function

#must be a bit-accurate refernce model of the rtl


def predict(image, params) -> int: 

    # image is 28x28x1

    # params is a dictionary produced by the quantize_model helper function (conv1_w, conv1_b, conv2_w, conv2_b, dense_w, dense_b)

    # write seperate stages for each main


    """

    Convert the input. Cast to int64 first, then apply the README rule pixel >> 1. uint8 arithmetic wraps at 255, so always cast before any math.
    Conv1. Build every 3×3 window, multiply by the 4 filters, sum, and add the bias. There is no shift in this layer, because Q1.7 × Q1.7 is Q2.14, the same scale as the Q6.14 bias. Then saturate to 20 bits, then ReLU.
    Max-pool 2×2. Take the maximum of each non-overlapping 2×2 block, per channel.
    Conv2. Same idea over 4 channels × 3×3 = 36 values per window. The bias is shifted left by 7 first, and after summing the result is shifted right by 7. Then saturate, then ReLU.
    Flatten. Make the 968-vector in channel-major order.
    Dense. A matrix-vector product with the bias << 7, then >> 7, then saturate. There is no ReLU here.
    Argmax. Return a plain int.

    """

    #sliding_window_view(arr, (3,3)) on a 2-D (28,28) arra7 gives shape (26,26,3,3)

    #np.einsum multiplies and sums over matching axes in one call.

    #np.clip(x, lo, hi) for saturation use limits -(1 <<19) and (1<<19) -1

    #np.maximum(x, 0) for ReLU

    #.reshape(-1) to flatten. ex. on a 8 by 11 by 11 array it gives ch*121 + r*11 + c automatically

    # use << and >> on the int64 arrays

    
    #keep verything in int64.

    return np.argmax(logit)