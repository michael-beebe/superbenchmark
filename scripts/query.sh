#!/bin/bash
# SuperBench System Query Script
# Collects system information following docs/user-tutorial/system-config.md

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

# Default values
OUTPUT_DIR="./sysinfo"
INVENTORY_FILE="host.ini"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -f|--inventory)
            INVENTORY_FILE="$2"
            shift 2
            ;;
        -h|--help)
            cat << EOF
Usage: $0 [OPTIONS]

Collects system information for benchmark configuration.

Options:
    -o, --output-dir DIR    Output directory (default: ./sysinfo)
    -f, --inventory FILE    Ansible inventory file (default: host.ini)
    -h, --help              Display this help message

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
    print_error "Virtual environment not found at $VENV_DIR"
    exit 1
fi

source "$VENV_DIR/bin/activate"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if this is local mode (inventory file has local connection)
if [ -f "$INVENTORY_FILE" ] && grep -q "ansible_connection=local" "$INVENTORY_FILE"; then
    # Local mode: use sb node info
    print_info "Collecting system information from local node"
    sb node info --output-dir "$OUTPUT_DIR"
    print_info "System information collected in: $OUTPUT_DIR/sys-info.json"
else
    # Remote mode: use sb run --get-info
    if [ ! -f "$INVENTORY_FILE" ]; then
        print_error "Inventory file not found: $INVENTORY_FILE"
        exit 1
    fi

    print_info "Collecting system information from remote nodes using inventory: $INVENTORY_FILE"
    sb run --get-info -f "$INVENTORY_FILE" --output-dir "$OUTPUT_DIR" -C superbench.enable=none
    print_info "System information collected in: $OUTPUT_DIR/nodes/"
fi
