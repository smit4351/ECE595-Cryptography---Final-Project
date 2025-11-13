#!/bin/bash

set -e

OUTPUT_FILE="${1:---}"
FILTER="${2:-}"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
REPORT_DIR="/tmp/attack_logs"

mkdir -p "$REPORT_DIR"

echo "=================================================="
echo "Attack Log Collection Report"
echo "Generated: $TIMESTAMP"
echo "Platform: Raspberry Pi 3"
echo "OP-TEE Version: 3.20.0"
echo "=================================================="
echo ""

# Check for root privileges (required for dmesg)
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script requires root privileges to read kernel logs."
    exit 1
fi

# Function to extract and format logs
extract_logs() {
    local module_name=$1
    local marker=$2
    
    echo ""
    echo "--- $module_name Logs ---"
    echo ""
    
    if dmesg | grep -q "\[$marker\]"; then
        dmesg | grep "\[$marker\]" | tail -100
    else
        echo "(No logs found for $module_name)"
    fi
}

# Collect all attack logs
extract_logs "DMA Attack" "DMA_ATTACK"
extract_logs "SMC Fuzzer" "SMC_FUZZER"
extract_logs "Cache Timing Attack" "CACHE_TIMING"
extract_logs "Peripheral Isolation Test" "PERIPH_TEST"

# Add system info
echo ""
echo "--- System Information ---"
echo ""
echo "Kernel Version: $(uname -r)"
echo "Platform: $(cat /proc/device-tree/model 2>/dev/null || echo 'Unknown')"
echo "CPU Cores: $(nproc)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Uptime: $(uptime -p)"

# Check for kernel panics or errors
if dmesg | grep -qi "panic\|oops\|unable to handle\|kernel crash"; then
    echo ""
    echo "--- \u26a0 KERNEL ERRORS DETECTED ---"
    echo ""
    dmesg | grep -i "panic\|oops\|unable to handle\|kernel crash" | tail -20
fi

# Output to file if specified
if [ "$OUTPUT_FILE" != "--" ]; then
    {
        echo "=================================================="
        echo "Attack Log Collection Report"
        echo "Generated: $TIMESTAMP"
        echo "Platform: Raspberry Pi 3"
        echo "OP-TEE Version: 3.20.0"
        echo "=================================================="
        echo ""
        
        extract_logs "DMA Attack" "DMA_ATTACK"
        extract_logs "SMC Fuzzer" "SMC_FUZZER"
        extract_logs "Cache Timing Attack" "CACHE_TIMING"
        extract_logs "Peripheral Isolation Test" "PERIPH_TEST"
        
        echo ""
        echo "--- System Information ---"
        echo ""
        echo "Kernel Version: $(uname -r)"
        echo "Platform: $(cat /proc/device-tree/model 2>/dev/null || echo 'Unknown')"
        echo "CPU Cores: $(nproc)"
        echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
        echo "Uptime: $(uptime -p)"
        
        if dmesg | grep -qi "panic\|oops\|unable to handle\|kernel crash"; then
            echo ""
            echo "--- \u26a0 KERNEL ERRORS DETECTED ---"
            echo ""
            dmesg | grep -i "panic\|oops\|unable to handle\|kernel crash" | tail -20
        fi
    } > "$OUTPUT_FILE"
    
    echo ""
    echo "Logs saved to: $OUTPUT_FILE"
fi
