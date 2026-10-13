import random
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import torchvision.transforms as transforms
from torchvision import datasets

from export_utils import quantize_model, write_mem
from float_training_model import CNN, rtl_input_scaling
from int_reference_model import predict

SEED = 2026
DATA_DIR = Path(__file__).resolve().parent / "data"
OUT_DIR = Path(__file__).resolve().parent.parent / "tb" / "test_vectors"


# Custom MNIST dataset class with Q1.7 input scaling
class MNISTDataset(Dataset):

    def __init__(self, data_dir, train=True, transform=None):
        if transform is None:

            # ToTensor converts the PIL image to a [0, 1] float tensor, the Lambda applies Q1.7 scaling 
            transform = transforms.Compose([transforms.ToTensor(), transforms.Lambda(rtl_input_scaling)])
        self.data = datasets.MNIST(data_dir, train=train, download=True, transform=transform) #train = True for 60k training images :)

    def __len__(self):
        return len(self.data)

    def __getitem__(self, idx):
        return self.data[idx]  # (image tensor [1, 28, 28], int label)


def select_test_subset() -> tuple[np.ndarray, np.ndarray]:

    """First 10 test images of each digit, in digit-major order (raw uint8 pixels)."""
    test_set = datasets.MNIST(DATA_DIR, train=False, download=True)
    images, labels = test_set.data.numpy(), test_set.targets.numpy()

    # np.flatnonzero find first 10 test imgaes of digit d
    idx = np.concatenate([np.flatnonzero(labels == d)[:10] for d in range(10)])
    return images[idx], labels[idx]


def main() -> None:

    """Run the CNN parameter export and validation-file generation."""
    random.seed(SEED)
    np.random.seed(SEED)
    torch.manual_seed(SEED)
    torch.use_deterministic_algorithms(True)

    u_CNN = CNN()
    mnist_dataset = MNISTDataset(data_dir=DATA_DIR, train=True)


#5 epochs, batch size 64, Adam with learning rate 0.001, and cross-entropy loss.
    

    #the criterion
    criterion = nn.CrossEntropyLoss()

    optimizer = optim.Adam(u_CNN.parameters(), lr=0.001)#turns graidents into weight updates

    num_epoch = 5
    
    batch_size = 64
    loader = DataLoader(
        mnist_dataset,
        batch_size=batch_size,
        shuffle=True,
        num_workers=0,
        generator=torch.Generator().manual_seed(SEED),
    )



    ### BEGIN TRAIN MODE --------------------------------------------------
    u_CNN.train()

    # each epoch is 60k images at batch_size of 64
    for epoch in range(num_epoch):
        total_loss = 0.0

        #loader covers all 60,000 training images in batches of 64
        #learns once per batch (each iteration of for x,y loop)
        for x, y in loader: # x is input image tesnor with 64 images in the batch and y is the corresponding labels

            optimizer.zero_grad()
            loss = criterion(u_CNN(x), y) #loss between predicted logit and real label
            loss.backward() # runs backpropogation
            optimizer.step() # updates the weights based on the computed gradients

            u_CNN.clamp_to_hardware_range() # clams to Q1.7 and Q6.14 ranges
            total_loss += loss.item() * x.size(0) # adds up total loss over the whole epoch

        # average loss per image for the epoch
        print(f"EPOCH: {epoch + 1}/{num_epoch} with average loss: {total_loss/len(mnist_dataset):.4f}")

    ### BEGIN EVAL MODE --------------------------------------------------
    u_CNN.eval()

    params = quantize_model(u_CNN) #converts training float weights and biases to integers
    images, labels = select_test_subset() #First 10 test images of each digit, in digit-major order (raw uint8 pixels).

    # golden = np.array([predict(img, params) for img in images]) #predict from int refernce model
    # correct = int((golden == labels).sum())


    # exports
    OUT_DIR.mkdir(parents=True, exist_ok=True)



    write_mem(OUT_DIR / "conv1_weights.mem", params["conv1_w"], 2, 36)

    write_mem(OUT_DIR / "conv2_weights.mem", params["conv2_w"], 2, 288)

    write_mem(OUT_DIR / "dense_weights.mem", params["dense_w"], 2, 9680)

    biases = np.concatenate([params["conv1_b"], params["conv2_b"], params["dense_b"]])

    write_mem(OUT_DIR / "biases.mem", biases, 5, 22)

    write_mem(OUT_DIR / "input_images.mem", images, 2, 100 * 784)

    # write_mem(OUT_DIR / "golden_outputs.mem", golden, 1, 100)
    write_mem(OUT_DIR / "labels.mem", labels, 1, 100)

    # print(f"The integer-reference accuracy on 100-image subset is: {correct}/100")
    # if correct < 90:
    #     print("Not GOOD!!!: below the 90/100 project goal")





if __name__ == "__main__":
    main()
