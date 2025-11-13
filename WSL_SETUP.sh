#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WSL Cross-Compilation Setup${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. Check if running in WSL
if ! grep -q "Microsoft" /proc/version && ! grep -q "WSL" /proc/version; then
    echo -e "${YELLOW}[WARN]${NC} It doesn't look like you are running in WSL."
fi

# 2. Update and Install Dependencies
echo -e "${BLUE}[INFO] Updating package lists...${NC}"
# sudo apt-get update -qq

echo -e "${BLUE}[INFO] Installing cross-compiler and build tools...${NC}"
PACKAGES_TO_INSTALL=""

# Check which packages are missing
for pkg in build-essential gcc-aarch64-linux-gnu bison flex libssl-dev bc git ncurses-dev; do
    if ! dpkg -l | grep -q "^ii  $pkg"; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $pkg"
    fi
done

if [ -n "$PACKAGES_TO_INSTALL" ]; then
    echo -e "${BLUE}[INFO] Installing:$PACKAGES_TO_INSTALL${NC}"
    echo -e "${YELLOW}[WARN] Skipping sudo install. If build fails, install these manually: $PACKAGES_TO_INSTALL${NC}"
    # sudo apt-get install -y -qq $PACKAGES_TO_INSTALL
else
    echo -e "${GREEN}[OK]${NC} All required packages already installed"
fi

echo -e "${GREEN}[OK]${NC} Build tools installed."

# 3. Setup Kernel Source
# The Makefile looks for KERNEL_SRC. We need a copy of the Raspberry Pi Linux kernel.

DEFAULT_KERNEL_DIR="../rpi-linux"
KERNEL_BRANCH="rpi-6.1.y" # Stable branch for Raspberry Pi 3

echo -e "${BLUE}[INFO] Checking for Kernel Source...${NC}"

if [ -z "$KERNEL_SRC" ]; then
    if [ -d "$DEFAULT_KERNEL_DIR" ]; then
        echo -e "${GREEN}[OK]${NC} Found kernel source at $DEFAULT_KERNEL_DIR"
        export KERNEL_SRC=$(realpath "$DEFAULT_KERNEL_DIR")
    else
        echo -e "${YELLOW}[WARN]${NC} Kernel source not found."
        echo ""
        echo "To cross-compile kernel modules, the Raspberry Pi Linux kernel source is required."
        echo "This will download ~400MB (with --depth=1)."
        echo ""

        read -p "Clone kernel source now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}[INFO] Cloning Raspberry Pi Linux Kernel ($KERNEL_BRANCH)...${NC}"
            git clone --depth=1 --branch "$KERNEL_BRANCH" https://github.com/raspberrypi/linux.git "$DEFAULT_KERNEL_DIR"
            
            if [ ! -d "$DEFAULT_KERNEL_DIR" ]; then
                echo -e "${RED}[ERROR]${NC} Failed to clone kernel source"
                exit 1
            fi
            
            echo -e "${BLUE}[INFO] Preparing kernel headers for ARM64...${NC}"
            cd "$DEFAULT_KERNEL_DIR"
            
            export ARCH=arm64
            export CROSS_COMPILE=aarch64-linux-gnu-
            
            make bcm2711_defconfig
            make modules_prepare
            
            cd - > /dev/null
            export KERNEL_SRC=$(realpath "$DEFAULT_KERNEL_DIR")
            echo -e "${GREEN}[OK]${NC} Kernel source prepared at $KERNEL_SRC"
        else
            echo -e "${RED}[ERROR]${NC} Cannot proceed without kernel source."
            echo "Please either:"
            echo "  1. Run this script again and select 'y' to clone"
            echo "  2. Clone manually: git clone --depth=1 --branch $KERNEL_BRANCH https://github.com/raspberrypi/linux.git $DEFAULT_KERNEL_DIR"
            echo "  3. Set KERNEL_SRC=/path/to/kernel manually"
            exit 1
        fi
    fi
fi

# 4. Verify setup
echo -e "${BLUE}[INFO] Verifying setup...${NC}"

FAILED=0

# Check cross-compiler
if ! command -v aarch64-linux-gnu-gcc &> /dev/null; then
    echo -e "${RED}[FAIL]${NC} aarch64-linux-gnu-gcc not found"
    FAILED=1
else
    echo -e "${GREEN}[OK]${NC} Cross-compiler available"
fi

# Check make
if ! command -v make &> /dev/null; then
    echo -e "${RED}[FAIL]${NC} make not found"
    FAILED=1
else
    echo -e "${GREEN}[OK]${NC} make available"
fi

# Check kernel source
if [ ! -d "$KERNEL_SRC" ]; then
    echo -e "${RED}[FAIL]${NC} KERNEL_SRC not found: $KERNEL_SRC"
    FAILED=1
else
    echo -e "${GREEN}[OK]${NC} Kernel source available at: $KERNEL_SRC"
fi

echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS]${NC} Setup complete! Run ./WSL_BUILD.sh to compile your modules."
else
    echo -e "${RED}[ERROR]${NC} Some checks failed. See above."
    exit 1
fi
