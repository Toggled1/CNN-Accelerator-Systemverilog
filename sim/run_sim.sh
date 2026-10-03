#!/usr/bin/env bash
# Run the small MNIST CNN RTL simulation workflow.
# This script mirrors the Phase 1 compile-and-run flow.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR/sim"

# Optional: regenerate model weights and validation data before simulation.
# python3 "$ROOT_DIR/model/train_and_export.py"

# Compile the RTL and testbench.
make compile

# Execute the simulation and validate predictions against golden outputs.
make run

echo "Simulation completed successfully."
