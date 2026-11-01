#!/usr/bin/env bash
# ElvonOS V1 — Phase 2: Build Hyprland 0.50.1 Stack for Debian 13
# Compiles pinned Hyprland ecosystem and packages as Debian packages.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$REPO_ROOT/build/cache/hyprland"
OUTPUT_DIR="$REPO_ROOT/build/out/packages"

echo "=================================================="
echo " ElvonOS V1 — Building Hyprland 0.50.1 Stack"
echo " Build directory:  $BUILD_DIR"
echo " Package output:   $OUTPUT_DIR"
echo "=================================================="

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# 1. Install build dependencies from hyprland-build.list
echo "==> Ensuring build dependencies are installed..."
sudo apt-get install -y --no-install-recommends \
    cmake ninja-build pkg-config libwayland-dev wayland-protocols \
    libxkbcommon-dev libinput-dev libdrm-dev libgbm-dev libegl-dev libgles-dev \
    libgl-dev libudev-dev libseat-dev libdisplay-info-dev hwdata libxcb1-dev \
    libxcb-composite0-dev libxcb-errors-dev libxcb-icccm4-dev libxcb-render0-dev \
    libxcb-res0-dev libxcb-xfixes0-dev libpixman-1-dev libcairo2-dev \
    libpango1.0-dev liblcms2-dev libcanberra-dev libglib2.0-dev libxcursor-dev \
    libtomlplusplus-dev libmuparser-dev libre2-dev uuid-dev libzip-dev \
    libmagic-dev libjpeg-dev libwebp-dev

build_cmake() {
    local name="$1"
    local repo="$2"
    local tag="$3"
    local extra_args="${4:-}"

    echo "==> Building $name ($tag)..."
    cd "$BUILD_DIR"
    if [[ ! -d "$name" ]]; then
        git clone --depth 1 --branch "$tag" "$repo" "$name"
    fi
    cd "$name"
    cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr $extra_args
    cmake --build build -j"$(nproc)"
    sudo cmake --install build
}

# 2. Build Hypr Ecosystem in strict dependency order
build_cmake "hyprland-protocols" "https://github.com/hyprwm/hyprland-protocols.git" "v0.6.4"
build_cmake "hyprwayland-scanner" "https://github.com/hyprwm/hyprwayland-scanner.git" "v0.4.4"
build_cmake "hyprutils" "https://github.com/hyprwm/hyprutils.git" "v0.8.2"
build_cmake "hyprlang" "https://github.com/hyprwm/hyprlang.git" "v0.6.0"
build_cmake "hyprcursor" "https://github.com/hyprwm/hyprcursor.git" "v0.1.11"
build_cmake "hyprgraphics" "https://github.com/hyprwm/hyprgraphics.git" "v0.1.3"
build_cmake "aquamarine" "https://github.com/hyprwm/aquamarine.git" "v0.9.3"

# 3. Build Hyprland 0.50.1 Core
echo "==> Building Hyprland 0.50.1..."
cd "$BUILD_DIR"
if [[ ! -d "hyprland" ]]; then
    git clone --depth 1 --branch "v0.50.1" "https://github.com/hyprwm/Hyprland.git" "hyprland"
fi
cd "hyprland"
cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DNO_XWAYLAND=OFF
cmake --build build -j"$(nproc)"
sudo cmake --install build

echo "=================================================="
echo " Hyprland 0.50.1 built and installed successfully!"
Hyprland --version || true
echo "=================================================="
