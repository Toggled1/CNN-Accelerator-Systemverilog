#!/usr/bin/env bash
# Run the RTL unit tests and end-to-end MNIST CNN regression.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
make -C "$ROOT_DIR/sim" test

echo "All RTL tests completed successfully."
