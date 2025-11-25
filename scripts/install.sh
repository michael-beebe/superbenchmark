#!/bin/bash
# SuperBench Installation Script
# This script sets up SuperBench for a control node
# For a GB300 node with local GPU setup

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

print_info "SuperBench Installation Script"
print_info "Project root: $PROJECT_ROOT"

# Check Python version
print_info "Checking Python version..."
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
print_info "Python version: $PYTHON_VERSION"

if ! python3 -c 'import sys; exit(0 if sys.version_info >= (3, 7) else 1)'; then
    print_error "Python 3.7 or later is required"
    exit 1
fi

# Check pip version
print_info "Checking pip version..."
PIP_VERSION=$(python3 -m pip --version | awk '{print $2}')
print_info "Pip version: $PIP_VERSION"

if ! python3 -m pip --version | grep -qE 'pip ([1-9][0-9]|[0-9]{2,})'; then
    print_warn "Pip version 18.0 or later is recommended"
fi

# Create virtual environment if requested
VENV_DIR="$PROJECT_ROOT/venv"
if [ ! -d "$VENV_DIR" ]; then
    print_info "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
    print_info "Virtual environment created at: $VENV_DIR"
    print_info "To activate it, run: source $VENV_DIR/bin/activate"
fi

# Activate virtual environment if it exists
if [ -f "$VENV_DIR/bin/activate" ]; then
    print_info "Activating virtual environment..."
    source "$VENV_DIR/bin/activate"
fi

# Update pip, setuptools, and wheel
print_info "Updating pip, setuptools, and wheel..."
python3 -m pip install --upgrade pip setuptools wheel

# Install dependencies from requirements.txt
print_info "Installing dependencies from requirements.txt..."
python3 -m pip install -r "$PROJECT_ROOT/requirements.txt"

# Install SuperBench from source
print_info "Installing SuperBench from source..."
cd "$PROJECT_ROOT"
python3 -m pip install .

# Run postinstall steps
print_info "Running postinstall steps..."
make postinstall

# Verify installation
print_info "Verifying SuperBench installation..."
if sb --version 2>/dev/null; then
    print_info "SuperBench CLI verification successful"
else
    print_warn "SuperBench CLI not found in PATH, you may need to activate the virtual environment"
fi

# Create local inventory file for single-node setup
mkdir -p "$PROJECT_ROOT/scripts/misc"
LOCAL_INI="$PROJECT_ROOT/scripts/misc/local.ini"
if [ ! -f "$LOCAL_INI" ]; then
    print_info "Creating local inventory file..."
    cat > "$LOCAL_INI" << 'EOF'
# SuperBench Inventory Configuration
# Single node setup with local connection

[all]
localhost ansible_connection=local
EOF
    print_info "Created: $LOCAL_INI"
else
    print_info "Local inventory file already exists: $LOCAL_INI"
fi

# Create a sample benchmark config for quick testing
RESNET_CONFIG="$PROJECT_ROOT/scripts/misc/resnet.yaml"
if [ ! -f "$RESNET_CONFIG" ]; then
    print_info "Creating sample benchmark configuration..."
    if [ -f "$PROJECT_ROOT/superbench/config/default.yaml" ]; then
        cp "$PROJECT_ROOT/superbench/config/default.yaml" "$RESNET_CONFIG"
        print_info "Created sample config: $RESNET_CONFIG"
    else
        print_warn "Default config file not found, skipping sample config creation"
    fi
else
    print_info "Sample config already exists: $RESNET_CONFIG"
fi

print_info ""
print_info "============================================"
print_info "SuperBench installation complete!"
print_info "============================================"
print_info ""
print_info "Next steps:"
print_info "1. To activate the virtual environment, run:"
print_info "   source $VENV_DIR/bin/activate"
print_info ""
print_info "2. (Optional) To build micro-benchmark binaries, run:"
print_info "   ./scripts/build.sh"
print_info "   This builds CUDA binaries for cutlass_profiler, bandwidthTest, etc."
print_info "   Requires CUDA toolkit and cmake. Takes 30-60 minutes."
print_info ""
print_info "3. To verify the installation, run:"
print_info "   sb --help"
print_info ""
print_info "4. To deploy SuperBench to managed nodes, run:"
print_info "   sb deploy -f ./scripts/misc/local.ini"
print_info ""
print_info "5. To run benchmarks, run:"
print_info "   ./scripts/run.sh"
print_info ""
print_info "For more information, see the documentation:"
print_info "   docs/getting-started/installation.mdx"
print_info "   docs/getting-started/run-superbench.md"
print_info ""
