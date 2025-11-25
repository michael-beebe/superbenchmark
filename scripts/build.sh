#!/bin/bash
# SuperBench Micro-benchmark Binaries Build Script
# This script builds all necessary micro-benchmark binaries for SuperBench
# Requires CUDA toolkit to be installed

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}===========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===========================================${NC}\n"
}

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
THIRD_PARTY_DIR="$PROJECT_ROOT/third_party"

print_section "SuperBench Micro-benchmark Build Script"
print_info "Project root: $PROJECT_ROOT"
print_info "Third-party source dir: $THIRD_PARTY_DIR"

# Check if third_party directory exists
if [ ! -d "$THIRD_PARTY_DIR" ]; then
    print_error "Third-party directory not found: $THIRD_PARTY_DIR"
    exit 1
fi

# Check for CUDA installation
print_info "Checking CUDA installation..."
if ! command -v nvcc &> /dev/null; then
    print_error "CUDA compiler (nvcc) not found. Please install CUDA toolkit."
    exit 1
fi

CUDA_VERSION=$(nvcc --version | grep 'release' | awk '{print $6}' | cut -c2- | cut -d '.' -f1-2)
print_info "CUDA version detected: $CUDA_VERSION"

# Check for git
print_info "Checking git installation..."
if ! command -v git &> /dev/null; then
    print_error "git not found. Please install git."
    exit 1
fi

# Check for cmake
print_info "Checking cmake installation..."
if ! command -v cmake &> /dev/null; then
    print_error "cmake not found. Please install cmake."
    exit 1
fi

# Determine build targets based on CUDA version
print_section "Determining Build Targets"

# For CUDA 13.0, we can build most CUDA targets
BUILD_TARGETS="common cuda_cutlass cuda_bandwidthTest cuda_nccl_tests"

print_info "Build targets for CUDA $CUDA_VERSION: $BUILD_TARGETS"

# Get number of parallel jobs
NUM_JOBS=$(nproc --ignore=2)
print_info "Using $NUM_JOBS parallel jobs for build"

# Change to third_party directory
cd "$THIRD_PARTY_DIR"

# Run make with selected targets using sudo if necessary
print_section "Building Micro-benchmarks"
print_info "This may take 30-60 minutes. Progress will be shown below...\n"

if make $BUILD_TARGETS -j${NUM_JOBS} 2>&1; then
    # Try to install as regular user first, use sudo if needed
    if sudo make $BUILD_TARGETS install -j${NUM_JOBS} 2>&1; then
        print_section "Build Completed Successfully"
    else
        print_error "Installation step failed with sudo. Check permissions."
        exit 1
    fi
else
    print_error "Build failed. Please check the error messages above."
    exit 1
fi
    print_info "Verifying built binaries..."
    BINARIES=(
        "/usr/local/bin/cutlass_profiler"
        "/usr/local/bin/bandwidthTest"
        "/usr/local/bin/all_gather_perf_mpi"
        "/usr/local/bin/all_reduce_perf_mpi"
    )

    FOUND_COUNT=0
    for BINARY in "${BINARIES[@]}"; do
        if [ -f "$BINARY" ]; then
            print_info "✓ Found: $BINARY"
            ((FOUND_COUNT++))
        else
            print_warn "✗ Not found: $BINARY"
        fi
    done

    print_info "\nBuilt $FOUND_COUNT/${#BINARIES[@]} expected binaries"

    # Show installation location
    print_section "Build Summary"
    print_info "Binaries installed to: /usr/local/bin/"
    print_info "Libraries installed to: /usr/local/lib/"

    print_info ""
    print_info "You can now run SuperBench benchmarks with:"
    print_info "  cd $PROJECT_ROOT"
    print_info "  source venv/bin/activate"
    print_info "  sb run -c scripts/misc/gb300-single-node.yaml -f scripts/misc/local.ini --no-docker"
    print_info ""

else
    print_error "Build failed. Please check the error messages above."
    exit 1
fi
