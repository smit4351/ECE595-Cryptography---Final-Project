#!/bin/bash

set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WSL Build Environment Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

FAILED=0

# 1. Check if running in WSL
echo -n "Checking if running in WSL... "
if grep -q "WSL\|Microsoft" /proc/version 2>/dev/null; then
    echo -e "${GREEN}YES${NC}"
else
    echo -e "${YELLOW}NO (may not work)${NC}"
fi

# 2. Check Linux Distribution
echo -n "Checking Linux distribution... "
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "${GREEN}$NAME${NC}"
else
    echo -e "${RED}Unknown${NC}"
fi

# 3. Check Architecture
echo -n "Checking host architecture... "
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    echo -e "${GREEN}$ARCH (correct for WSL)${NC}"
else
    echo -e "${YELLOW}$ARCH (expected x86_64)${NC}"
fi

echo ""
echo -e "${BLUE}Checking Required Tools:${NC}"

# 4. Check essential tools
for tool in gcc aarch64-linux-gnu-gcc make git bison flex; do
    echo -n "  $tool... "
    if command -v "$tool" &> /dev/null; then
        VER=$(echo "$(command -v "$tool") available")
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}MISSING${NC}"
        FAILED=1
    fi
done

echo ""
echo -e "${BLUE}Checking Kernel Source:${NC}"

# 5. Check kernel source location
DEFAULT_KERNEL_DIR="../rpi-linux"
KERNEL_SRC="${KERNEL_SRC:-$DEFAULT_KERNEL_DIR}"

echo -n "  KERNEL_SRC location ($KERNEL_SRC)... "
if [ -d "$KERNEL_SRC" ]; then
    echo -e "${GREEN}FOUND${NC}"
    
    # Check for critical kernel files
    echo -n "    Checking Makefile... "
    if [ -f "$KERNEL_SRC/Makefile" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}MISSING${NC}"
        FAILED=1
    fi
    
    echo -n "    Checking for ARM64 config... "
    if [ -f "$KERNEL_SRC/.config" ]; then
        if grep -q "CONFIG_ARM64=y" "$KERNEL_SRC/.config" 2>/dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${YELLOW}Not ARM64${NC}"
        fi
    else
        echo -e "${RED}MISSING (.config not found)${NC}"
        FAILED=1
    fi
else
    echo -e "${RED}NOT FOUND${NC}"
    FAILED=1
fi

echo ""
echo -e "${BLUE}Checking Project Files:${NC}"

# 6. Check project files
for file in kernel_modules/Makefile kernel_modules/dma_attack.c; do
    echo -n "  $file... "
    if [ -f "$file" ]; then
        echo -e "${GREEN}FOUND${NC}"
    else
        echo -e "${RED}MISSING${NC}"
        FAILED=1
    fi
done

echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}All checks passed! Ready to build.${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Run: ./WSL_BUILD.sh"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}Some checks failed. See above.${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo "Run ./WSL_SETUP.sh to fix issues."
    exit 1
fi
