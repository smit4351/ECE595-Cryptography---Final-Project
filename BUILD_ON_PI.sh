#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Building Kernel Modules on Raspberry Pi${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running on RPi
if ! grep -q "Raspberry Pi 3" /proc/device-tree/model 2>/dev/null; then
    echo -e "${RED}[ERROR]${NC} This script must run on Raspberry Pi 3"
    exit 1
fi

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Running on Raspberry Pi"
echo -e "${GREEN}[OK]${NC} Kernel: $(uname -r)"
echo -e "${GREEN}[OK]${NC} Architecture: $(uname -m)"
echo ""

# Install build dependencies (skip if already installed in minimal environment)
echo -e "${BLUE}Checking build dependencies...${NC}"
if ! command -v gcc >/dev/null 2>&1 || ! command -v make >/dev/null 2>&1; then
    echo -e "${YELLOW}[WARN]${NC} Build tools not found, attempting to install..."
    apt-get update -qq
    apt-get install -y -qq \
        build-essential \
        linux-headers-$(uname -r) \
        device-tree-compiler \
        git \
        make
    echo -e "${GREEN}[OK]${NC} Dependencies installed"
else
    echo -e "${GREEN}[OK]${NC} Build dependencies already available"
fi
echo ""

# Build modules
echo -e "${BLUE}Building kernel modules...${NC}"
cd "$(dirname "$0")/kernel_modules"

make clean 2>&1 | tail -3
echo -e "${GREEN}[OK]${NC} Cleaned build artifacts"
echo ""

make ARCH=arm64 CROSS_COMPILE="" KERNEL_SRC=/lib/modules/$(uname -r)/build 2>&1 | tail -30

if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} Build failed"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}Kernel Modules:${NC}"
ls -lh *.ko
echo ""
echo "Next steps:"
echo "  1. Copy to Pi attack runner:"
echo "     cp kernel_modules/*.ko ~/pi_attack_runner/"
echo ""
echo "  2. Load modules:"
echo "     cd ~/pi_attack_runner"
echo "     bash run_attacks.sh --local /path/to/modules"
echo ""
