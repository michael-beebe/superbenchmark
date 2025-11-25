#!/bin/bash
# SuperBench Run Script
# Runs benchmarks following docs/getting-started/run-superbench.md

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Error handler
error_exit() {
    print_error "$1"
    exit 1
}

# Trap errors
trap 'error_exit "Script failed at line $LINENO"' ERR

# Default values
INVENTORY_FILE="./scripts/misc/local.ini"
CONFIG_FILE="./scripts/misc/resnet.yaml"
OUTPUT_DIR="./results"
DOCKER_IMAGE=""
SKIP_DEPLOY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--inventory)
            INVENTORY_FILE="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -i|--image)
            DOCKER_IMAGE="$2"
            shift 2
            ;;
        --skip-deploy)
            SKIP_DEPLOY=true
            shift
            ;;
        -h|--help)
            cat << EOF
Usage: $0 [OPTIONS]

Runs SuperBench benchmarks following the documentation.

Options:
    -f, --inventory FILE    Ansible inventory file (default: ./scripts/misc/local.ini)
    -c, --config FILE       Benchmark config file (default: ./scripts/misc/resnet.yaml)
    -o, --output-dir DIR    Output directory (default: ./results)
    -i, --image IMAGE       Docker image to use (e.g., superbench/superbench:v0.12.0-cuda13.0)
    --skip-deploy           Skip deployment step (for local/no-docker runs)
    -h, --help              Display this help message

Examples:
    # Run with default settings
    ./run.sh

    # Run with custom Docker image for arm64
    ./run.sh -i superbench/superbench:v0.12.0-cuda13.0

    # Run without Docker (local execution)
    ./run.sh --skip-deploy

EOF
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Get project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Activate venv
VENV_DIR="$PROJECT_ROOT/venv"
if [ ! -d "$VENV_DIR" ]; then
    error_exit "Virtual environment not found at $VENV_DIR"
fi

source "$VENV_DIR/bin/activate" || error_exit "Failed to activate virtual environment"

# Validate inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    error_exit "Inventory file not found: $INVENTORY_FILE"
fi

# Validate config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    error_exit "Config file not found: $CONFIG_FILE"
fi

print_info "SuperBench Run Script"
print_info "Inventory: $INVENTORY_FILE"
print_info "Config: $CONFIG_FILE"
print_info "Output directory: $OUTPUT_DIR"
if [ "$SKIP_DEPLOY" = true ]; then
    print_info "Deploy: SKIPPED (--skip-deploy)"
fi
print_info ""

# Create output directory
mkdir -p "$OUTPUT_DIR" || error_exit "Failed to create output directory: $OUTPUT_DIR"

# Check if sb command is available
if ! command -v sb &> /dev/null; then
    error_exit "SuperBench CLI (sb) not found. Is the virtual environment activated?"
fi

# Check for required Python packages
print_info "Checking for required dependencies..."
required_packages=("torch" "tensorflow" "onnx" "transformers")
missing_packages=()

for pkg in "${required_packages[@]}"; do
    if ! python3 -c "import $pkg" 2>/dev/null; then
        missing_packages+=("$pkg")
    fi
done

if [ ${#missing_packages[@]} -gt 0 ]; then
    print_warn "Missing Python packages: ${missing_packages[*]}"
    print_info "Some benchmarks may fail. Consider installing: pip install ${missing_packages[*]}"
fi
print_info ""

# Step 1: Deploy
if [ "$SKIP_DEPLOY" = false ]; then
    print_info "Step 1: Deploying SuperBench environment..."
    DEPLOY_CMD="sb deploy -f $INVENTORY_FILE"
    if [ -n "$DOCKER_IMAGE" ]; then
        print_info "Using Docker image: $DOCKER_IMAGE"
        DEPLOY_CMD="$DEPLOY_CMD -i $DOCKER_IMAGE"
    fi
    if ! eval "$DEPLOY_CMD"; then
        error_exit "Deployment failed. Check the output above for details."
    fi
    print_info "Deployment completed"
    print_info ""
else
    print_warn "Skipping deployment step (using --no-docker)"
    print_info ""
fi

# Step 2: Run benchmarks
print_info "Step 2: Running benchmarks..."
RUN_CMD="sb run -f $INVENTORY_FILE -c $CONFIG_FILE --output-dir $OUTPUT_DIR"
if [ "$SKIP_DEPLOY" = true ]; then
    RUN_CMD="$RUN_CMD --no-docker"
fi

# Run benchmarks and capture exit code
if ! eval "$RUN_CMD"; then
    error_exit "Benchmark run failed. Check the output above for details."
fi

# Check if results were generated
if [ ! -d "$OUTPUT_DIR" ] || [ -z "$(find "$OUTPUT_DIR" -type f -name '*.json' 2>/dev/null)" ]; then
    print_warn "No benchmark results found in $OUTPUT_DIR"
fi

print_info "Benchmarks completed"
print_info ""

print_info "============================================"
print_info "Run completed successfully!"
print_info "============================================"
print_info ""
print_info "Results available in: $OUTPUT_DIR"
print_info ""
