#!/usr/bin/env bash
# Run the small MNIST CNN RTL simulation workflow.
# This script is intended to mirror the workflow in README.md.

set -e

cd "$(dirname "$0")/.."

# Optional: regenerate model weights and validation data before simulation.
# python3 model/train_and_export.py

# Compile the RTL and testbench.
make -C sim compile

# Execute the simulation and validate predictions against golden outputs.
make -C sim run

echo "Simulation targets returned; functional RTL verification remains TODO."
