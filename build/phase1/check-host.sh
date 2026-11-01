#!/usr/bin/env bash
# ElvonOS V1 — Phase 1: Host Readiness Check
# Validates whether the current host can build and test Phase 1.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

pass() { echo -e "  [${GREEN}PASS${NC}] $1"; }
warn() { echo -e "  [${YELLOW}WARN${NC}] $1"; WARNINGS=$((WARNINGS + 1)); }
fail() { echo -e "  [${RED}FAIL${NC}] $1"; ERRORS=$((ERRORS + 1)); }
info() { echo -e "${BLUE}==>${NC} $1"; }

info "1. Checking Architecture"
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    pass "Architecture is x86_64 / amd64"
else
    fail "Unsupported architecture: $ARCH (expected x86_64)"
fi

info "2. Checking Operating System"
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    pass "Distribution: $PRETTY_NAME"
    if [[ "$ID" == "debian" ]]; then
        pass "Base distribution is Debian"
    else
        warn "Base distribution is $ID, not pure Debian"
    fi
else
    warn "Cannot detect distribution (/etc/os-release missing)"
fi

info "3. Checking Kernel & Runtime Environment"
KERNEL=$(uname -r)
info "Running kernel: $KERNEL"
if [[ "$KERNEL" =~ microsoft|WSL ]]; then
    warn "Running inside WSL2 ($KERNEL). WSL2 is suitable for package and rootfs building, but CANNOT validate boot, hardware, or kernel Binder devices."
else
    pass "Running on native Linux kernel ($KERNEL)"
fi

info "4. Checking Memory and Storage"
MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_GB=$((MEM_KB / 1024 / 1024))
if (( MEM_GB >= 4 )); then
    pass "RAM: ${MEM_GB} GB (>= 4 GB required)"
else
    warn "RAM: ${MEM_GB} GB (recommended: >= 8 GB)"
fi

DISK_AVAIL_KB=$(df -k . | tail -1 | awk '{print $4}')
DISK_AVAIL_GB=$((DISK_AVAIL_KB / 1024 / 1024))
if (( DISK_AVAIL_GB >= 15 )); then
    pass "Disk free: ${DISK_AVAIL_GB} GB (>= 15 GB required)"
else
    fail "Disk free: ${DISK_AVAIL_GB} GB (insufficient space, minimum 15 GB required)"
fi

info "5. Checking Root / Sudo Access"
if [[ $EUID -eq 0 ]]; then
    pass "Running directly as root"
elif sudo -n true 2>/dev/null; then
    pass "Passwordless sudo is available"
else
    warn "Passwordless sudo is not available. Root operations will require password entry."
fi

info "6. Checking Network Access"
if curl -s --head --connect-timeout 5 https://deb.debian.org >/dev/null 2>&1; then
    pass "deb.debian.org is reachable"
else
    fail "Cannot connect to https://deb.debian.org"
fi

info "7. Checking Essential Host Tools"
REQUIRED_TOOLS=("bash" "curl" "git" "tar" "xz" "jq")
BUILD_TOOLS=("build-essential" "gcc" "g++" "make" "cmake" "ninja" "mmdebstrap")

for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        pass "Tool present: $tool"
    else
        fail "Required tool missing: $tool"
    fi
done

info "8. Checking Rootfs & ISO Build Tools"
for tool in mmdebstrap debootstrap live-build squashfs-tools xorriso; do
    if command -v "$tool" >/dev/null 2>&1 || dpkg -s "$tool" >/dev/null 2>&1; then
        pass "Build tool present: $tool"
    else
        warn "Build tool missing: $tool (run install-build-deps.sh)"
    fi
done

echo ""
echo "=================================================="
if (( ERRORS > 0 )); then
    echo -e "${RED}Host check FAILED with $ERRORS error(s) and $WARNINGS warning(s).${NC}"
    exit 1
elif (( WARNINGS > 0 )); then
    echo -e "${YELLOW}Host check PASSED with $WARNINGS warning(s). Build can proceed in WSL/packaging mode.${NC}"
    exit 0
else
    echo -e "${GREEN}Host check fully PASSED without warnings.${NC}"
    exit 0
fi
