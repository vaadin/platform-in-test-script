#!/usr/bin/env bash

## Wrapper script to run the TypeScript version of PiT
## This script provides the same interface as the original run.sh
## Automatically handles dependency installation and compilation

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

# Function to check if build is needed
needs_build() {
    # If dist directory doesn't exist, we need to build
    if [ ! -d "dist" ]; then
        return 0
    fi
    
    # Check if any TypeScript source files are newer than the main dist/index.js
    if [ ! -f "dist/index.js" ]; then
        return 0
    fi
    
    if find src -name "*.ts" -newer dist/index.js 2>/dev/null | grep -q .; then
        return 0
    fi
    
    # Check if tsconfig.json is newer than dist
    if [ "tsconfig.json" -nt "dist/index.js" ]; then
        return 0
    fi
    
    return 1
}

# Function to check if dependencies need installing
needs_install() {
    # If node_modules doesn't exist, we need to install
    if [ ! -d "node_modules" ]; then
        return 0
    fi
    
    # If package.json is significantly newer than node_modules (more than 5 minutes)
    if [ "package.json" -nt "node_modules" ]; then
        # Get timestamps in seconds since epoch
        pkg_time=$(stat -f "%m" package.json 2>/dev/null || stat -c "%Y" package.json 2>/dev/null || echo 0)
        nm_time=$(stat -f "%m" node_modules 2>/dev/null || stat -c "%Y" node_modules 2>/dev/null || echo 0)
        
        # If package.json is more than 5 minutes newer, reinstall
        if [ $((pkg_time - nm_time)) -gt 300 ]; then
            return 0
        fi
    fi
    
    return 1
}

# Check if dependencies are installed or package.json has changed significantly
if needs_install; then
    echo "📦 Installing/updating dependencies..."
    npm install
fi

# Check if we need to build/rebuild
if needs_build; then
    echo "🔨 Building TypeScript project..."
    npm run build
fi

# Run the TypeScript version with all arguments passed through
echo "Running PiT TypeScript version..."
exec node dist/index.js "$@"
