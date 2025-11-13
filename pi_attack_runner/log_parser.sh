#!/bin/bash

set -e

# Check for root privileges (required for dmesg)
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script requires root privileges to read kernel logs."
    exit 1
fi

OUTPUT_DIR="${1:-$HOME/attack_results}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_FILE="$OUTPUT_DIR/attack_report_$TIMESTAMP.txt"

mkdir -p "$OUTPUT_DIR"

{
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║         RASPBERRY PI 3 ATTACK EXECUTION REPORT                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Generated: $(date)"
    echo "System: $(cat /proc/device-tree/model 2>/dev/null || echo 'Unknown')"
    echo "Kernel: $(uname -r)"
    echo ""
    
    # Parse DMA Attack logs
    if dmesg | grep -q "\[DMA_ATTACK\]"; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "DMA ATTACK RESULTS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        if dmesg | grep -q "\[DMA_ATTACK\].*✓.*Transfer completed"; then
            echo "Status: ✅ SUCCESS"
            dmesg | grep "\[DMA_ATTACK\].*Transfer completed" | head -1
        elif dmesg | grep -q "\[DMA_ATTACK\].*ERROR\|ERROR.*DMA"; then
            echo "Status: ❌ FAILED"
            dmesg | grep "\[DMA_ATTACK\].*ERROR" | head -1
        else
            echo "Status: ⏳ PENDING (Module not executed)"
        fi
        
        # Show target addresses attempted
        if dmesg | grep -q "\[DMA_ATTACK\].*Target Address"; then
            echo ""
            echo "Targets Attempted:"
            dmesg | grep "\[DMA_ATTACK\].*Target Address" | sed 's/^/  /'
        fi
        echo ""
    fi
    
    # Parse Cache Timing logs
    if dmesg | grep -q "\[CACHE_TIMING\]"; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "CACHE TIMING ATTACK RESULTS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        if dmesg | grep -q "\[CACHE_TIMING\].*Analysis complete"; then
            echo "Status: ✅ ANALYSIS COMPLETE"
            HITS=$(dmesg | grep "\[CACHE_TIMING\].*Cache Hits" | tail -1 | grep -oE '[0-9]+$')
            MISSES=$(dmesg | grep "\[CACHE_TIMING\].*Cache Misses" | tail -1 | grep -oE '[0-9]+$')
            HIT_RATE=$(dmesg | grep "\[CACHE_TIMING\].*Hit Rate" | tail -1 | grep -oE '[0-9]+%')
            
            echo "  Cache Hits: $HITS"
            echo "  Cache Misses: $MISSES"
            echo "  Hit Rate: $HIT_RATE"
        else
            echo "Status: ⏳ IN PROGRESS or NOT STARTED"
        fi
        echo ""
    fi
    
    # Parse Peripheral Isolation logs
    if dmesg | grep -q "\[PERIPH_TEST\]"; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "PERIPHERAL ISOLATION RESULTS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        VULN_COUNT=$(dmesg | grep -c "\[PERIPH_TEST\].*⚠.*VULNERABLE" || echo 0)
        OK_COUNT=$(dmesg | grep -c "\[PERIPH_TEST\].*OK" || echo 0)
        
        echo "Status: ✅ COMPLETE"
        echo "  Vulnerable Peripherals: $VULN_COUNT"
        echo "  Protected Peripherals: $OK_COUNT"
        
        if [ "$VULN_COUNT" -gt 0 ]; then
            echo ""
            echo "⚠ Vulnerable Peripherals Detected:"
            dmesg | grep "\[PERIPH_TEST\].*⚠.*VULNERABLE" | sed 's/^/  /'
        fi
        echo ""
    fi
    
    # Check for kernel errors
    if dmesg | grep -qi "panic\|oops\|unable\|crash"; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚠️  KERNEL ERRORS DETECTED"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        dmesg | grep -i "panic\|oops\|unable\|crash" | tail -5 | sed 's/^/  /'
        echo ""
    fi
    
    echo "════════════════════════════════════════════════════════════════"
    echo "Report generated: $(date)"
    echo "════════════════════════════════════════════════════════════════"
    
} | tee "$REPORT_FILE"

echo ""
echo "Full report saved to: $REPORT_FILE"
echo ""
echo "To send to your partner:"
echo "  cat $REPORT_FILE"
