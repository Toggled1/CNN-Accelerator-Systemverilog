

import numpy as np
from numpy.lib.stride_tricks import sliding_window_view as swv

#create a predict function

#must be a bit-accurate refernce model of the rtl




def predict(image, params) -> int: 

    # image is a 2-D 28x28 array

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

    # sliding_window_view on a 2-D (28, 28) image gives (26, 26, 3, 3)

    #np.einsum multiplies and sums over matching axes in one call.

    #np.clip(x, lo, hi) for saturation use limits -(1 <<19) and (1<<19) -1

    #np.maximum(x, 0) for ReLU

    #.reshape(-1) to flatten. ex. on a 8 by 11 by 11 array it gives ch*121 + r*11 + c automatically

    # use << and >> on the int64 arrays

    
    #keep verything in int64.

    """ Window Generation and Conv1 Stage """
    img = image.astype(np.int64)

    img = img >> 1 #for converting to Q1.7 format

    conv1_windows = swv(img, (3,3))  # Shape: (26, 26, 3, 3) -> [i j, k, l]

    conv1_w = params['conv1_w'].astype(np.int64) #[m, k, l]
    conv1_b = params['conv1_b'].astype(np.int64) #[m]

    #image row: i, image column: j, kernel row: k, kernel column: l, filter number: m
    ##multiplies th ewindow and filter values for each matching k,l, then subs across those 3x3 kernel positions. It repeats that for each image position i,j, and filter m
    conv1_out = np.einsum('ijkl,mkl->ijm', conv1_windows, conv1_w) + conv1_b #produces (26, 26, 4)

    #saturation
    conv1_out = np.clip(conv1_out, -(1 << 19), (1 << 19) - 1)

    """ ReLU 1 Stage """
    conv1_out = np.maximum(conv1_out, 0)  # ReLU

    """ Max-Pool 2x2 Stage """

    pool_height, pool_width, channels = conv1_out.shape
    pooled = conv1_out.reshape (pool_height // 2, 2, pool_width //2, 2, channels) #13, 2, 13, 2, 4
    pooled = pooled.max(axis=(1,3))  # Max-pool 2x2: 13, 13, 4

    """ Window Generation and Conv2 Stage """
    # 3x3 windows over rows and columns only!!! (using axis =(0,1))
    conv2_windows = swv(pooled, (3,3), axis=(0,1))  # Shape: (11, 11, 4, 3, 3) -> [i, j, c, k, l]

    conv2_w = params['conv2_w'].astype(np.int64) #[m, k, l]
    conv2_b = params['conv2_b'].astype(np.int64) #[m]

    #image row: i, image column: j, kernel row: k, kernel column: l, filter number: m
    ##multiplies the window and filter values for each matching k,l, then sums across those 3x3 kernel positions. It repeats that for each image position i,j, and filter m
    conv2_out = np.einsum('ijckl,mkl->ijm', conv2_windows, conv2_w) + (conv2_b << 7) #produces (11, 11, 4)

    #shift right by 7
    conv2_out = conv2_out >> 7

    #saturation
    conv2_out = np.clip(conv2_out, -(1 << 19), (1 << 19) - 1)


    """ ReLU 2 Stage """
    conv2_out = np.maximum(conv2_out, 0)  # ReLU

    """ Flatten Stage """
    flat = conv2_out.reshape(-1)  #Flatten to 968-vector

    """ Dense Stage """
    dense_w = params['dense_w'].astype(np.int64) #[n, 968]
    dense_b = params['dense_b'].astype(np.int64) #[n]

    # do all mac in Q7.21
    logit = np.dot(dense_w, flat) + (dense_b << 7) 

    # bring back to Q6.14 scaling before saturation
    logit = logit >> 7

    # saturation!
    logit = np.clip(logit, -(1 << 19), (1 << 19) - 1)


    return int(np.argmax(logit))