#!/bin/bash
# Run the ziobuild vs plain comparison in Docker (Linux)
set -euo pipefail

cd "$(dirname "$0")"

echo "Building comparison Docker image..."
docker build -t ziobuild-comparison .

echo ""
echo "Running comparison..."
docker run --rm ziobuild-comparison
