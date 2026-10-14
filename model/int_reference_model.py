
#must be a bit-accurate refernce model of the rtl

import numpy as np
from numpy.lib.stride_tricks import sliding_window_view as swv






def predict(image, params) -> int: 


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

    conv2_w = params['conv2_w'].astype(np.int64) #[m, c, k, l]
    conv2_b = params['conv2_b'].astype(np.int64) #[m]

    #image row: i, image column: j, kernel row: k, kernel column: l, filter number: m
    ## Multiplies matching channel and kernel values, summing across c, k, and l.
    conv2_out = np.einsum('ijckl,mckl->ijm', conv2_windows, conv2_w) + (conv2_b << 7) #produces (11, 11, 8)

    #shift right by 7
    conv2_out = conv2_out >> 7

    #saturation
    conv2_out = np.clip(conv2_out, -(1 << 19), (1 << 19) - 1)


    """ ReLU 2 Stage """
    conv2_out = np.maximum(conv2_out, 0)  # ReLU

    """ Flatten Stage """
    flat = conv2_out.transpose(2, 0, 1).reshape(-1)  #Flatten in channel-major order from 8,11,11

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