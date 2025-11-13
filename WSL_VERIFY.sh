#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

MODULES_DIR="kernel_modules"
MODULES=(
    "dma_attack.ko"
    "cache_timing_attack.ko"
    "peripheral_isolation_test.ko"
)

echo "Verifying build artifacts..."

ALL_OK=true

for mod in "${MODULES[@]}"; do
    FILE_PATH="$MODULES_DIR/$mod"
    if [ -f "$FILE_PATH" ]; then
        FILE_INFO=$(file "$FILE_PATH")
        if [[ "$FILE_INFO" == *"ARM aarch64"* ]]; then
            echo -e "${GREEN}[OK]${NC} $mod: Found and is ARM64"
        else
            echo -e "${RED}[FAIL]${NC} $mod: Found but incorrect architecture!"
            echo "       Info: $FILE_INFO"
            ALL_OK=false
        fi
    else
        echo -e "${RED}[FAIL]${NC} $mod: Not found. Did you run ./WSL_BUILD.sh?"
        ALL_OK=false
    fi
done

if $ALL_OK; then
    echo -e "\n${GREEN}SUCCESS: All modules verified ready for deployment.${NC}"
    exit 0
else
    echo -e "\n${RED}FAILURE: Some checks failed.${NC}"
    exit 1
fi
