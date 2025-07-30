#!/usr/bin/env bash

## Wrapper script to run the TypeScript version of PiT
## This script provides the same interface as the original run.sh

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS_DIR="$SCRIPT_DIR/ts"

# Check if Node.js is available
if ! command -v node >/dev/null 2>&1; then
    echo "Error: Node.js is required but not installed. Please install Node.js 18.0.0 or higher."
    exit 1
fi

# Check if the TypeScript project exists
if [ ! -d "$TS_DIR" ]; then
    echo "Error: TypeScript directory not found at $TS_DIR"
    exit 1
fi

# Change to the TypeScript directory
cd "$TS_DIR"

# Check if dependencies are installed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Check if the project is built
if [ ! -d "dist" ]; then
    echo "Building TypeScript project..."
    npm run build
fi

# Run the TypeScript version with all arguments passed through
echo "Running PiT TypeScript version..."
exec node dist/index.js "$@"
