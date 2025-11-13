#!/usr/bin/env bash
# Preflight check for Raspberry Pi 3 deployment
# Run this on the Raspberry Pi before building/running attacks.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_ok(){ echo -e "${GREEN}OK${NC} $1"; }
log_warn(){ echo -e "${YELLOW}$1${NC}"; }
log_err(){ echo -e "${RED}✗${NC} $1"; }

echo "==================================="
echo "PI 3 PRE-FLIGHT CHECK"
echo "==================================="

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root"
    exit 1
fi

# 1) Model check
if [ -f /proc/device-tree/model ]; then
  MODEL=$(tr -d '\0' </proc/device-tree/model)
  if echo "$MODEL" | grep -q "Raspberry Pi 3"; then
    log_ok "Platform: $MODEL"
  else
    log_warn "Platform does not contain 'Raspberry Pi 3' — found: $MODEL"
  fi
else
  log_warn "/proc/device-tree/model not found"
fi

# 2) Architecture check
ARCH=$(uname -m)
if echo "$ARCH" | grep -q "aarch64\|armv7l"; then
  log_ok "Architecture: $ARCH"
else
  log_warn "Architecture: $ARCH — expected aarch64 or armv7l"
fi

# 3) OP-TEE device
if [ -e /dev/tee0 ]; then
  log_ok "OP-TEE device /dev/tee0 exists"
else
  log_warn "/dev/tee0 not found (OP-TEE may not be installed)"
fi

# 4) Kernel headers
if [ -d "/lib/modules/$(uname -r)/build" ]; then
  log_ok "Kernel headers available for $(uname -r)"
else
  log_warn "Kernel headers missing for $(uname -r) — run: apt install raspberrypi-kernel-headers"
fi

# 5) Tools
TOOLS=(gcc make modinfo insmod rmmod dmesg)
for t in "${TOOLS[@]}"; do
  if command -v "$t" >/dev/null 2>&1; then
    log_ok "$t present"
  else
    log_warn "$t missing"
  fi
done

# 6) Built modules check (optional)
MISSING=0
for mod in dma_attack.ko cache_timing_attack.ko peripheral_isolation_test.ko; do
  if [ -f "../kernel_modules/$mod" ]; then
    log_ok "$mod found in ../kernel_modules"
  else
    log_warn "$mod not found in ../kernel_modules — build them with bash BUILD_ON_PI.sh"
    MISSING=1
  fi
done

# 7) Check kernel log for attack tags (no modules loaded may be OK)
dmesg | grep -E "\[DMA_ATTACK\]|\[CACHE_TIMING\]|\[PERIPH_TEST\]" >/dev/null 2>&1 && log_ok "Detected previous attack logs in kernel log" || log_warn "No attack logs detected in kernel log"

if [ $MISSING -ne 0 ]; then
  echo ""
  log_warn "Some kernel modules are missing. Run BUILD_ON_PI.sh and then re-run this preflight script."
else
  echo ""
  log_ok "Preflight checks passed (or only minor warnings). You can proceed to run attacks."
fi

exit 0
