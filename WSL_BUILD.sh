#!/bin/bash

set -e

# Default to the location setup by WSL_SETUP.sh
DEFAULT_KERNEL_DIR="../rpi-linux"

# Set architecture and cross-compiler
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

# Determine KERNEL_SRC
if [ -z "$KERNEL_SRC" ]; then
    if [ -d "$DEFAULT_KERNEL_DIR" ]; then
        export KERNEL_SRC=$(realpath "$DEFAULT_KERNEL_DIR")
    else
        # Fallback to checking if we are in the optee structure
        if [ -d "../optee-project/linux" ]; then
            export KERNEL_SRC=$(realpath "../optee-project/linux")
        else
            echo "Error: KERNEL_SRC not set and could not find kernel source at $DEFAULT_KERNEL_DIR"
            echo "Please run ./WSL_SETUP.sh first or set KERNEL_SRC manually."
            exit 1
        fi
    fi
fi

echo "=========================================="
echo "Building for ARM64 (Raspberry Pi 3)"
echo "Kernel Source: $KERNEL_SRC"
echo "=========================================="

cd kernel_modules
make clean
make

echo ""
echo "Build complete. Run ./WSL_VERIFY.sh to check the modules."
