#!/usr/bin/env bash

echo "🧪 Testing PiT TypeScript Implementation"
echo "========================================"

cd "$(dirname "$0")/ts"

echo "✅ 1. Building project..."
npm run build >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✓ Build successful"
else
    echo "   ✗ Build failed"
    exit 1
fi

echo "✅ 2. Testing help command..."
node dist/index.js --help >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✓ Help command works"
else
    echo "   ✗ Help command failed"
    exit 1
fi

echo "✅ 3. Testing list command..."
node dist/index.js --list >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✓ List command works"
else
    echo "   ✗ List command failed"
    exit 1
fi

echo "✅ 4. Testing dry run..."
node dist/index.js --test --starters="latest-java" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✓ Dry run works"
else
    echo "   ✗ Dry run failed"
    exit 1
fi

echo "✅ 5. Testing argument validation..."
node dist/index.js --port=99999 >/dev/null 2>&1
if [ $? -eq 1 ]; then
    echo "   ✓ Argument validation works"
else
    echo "   ✗ Argument validation failed"
    exit 1
fi

echo ""
echo "🎉 All tests passed! PiT TypeScript implementation is working correctly."
echo ""
echo "Usage examples:"
echo "  ./run-ts.sh --help                    # Show help"
echo "  ./run-ts.sh --list                    # List all starters"
echo "  ./run-ts.sh --test --demos            # Dry run all demos"
echo "  ./run-ts.sh --starters='latest-java'  # Test specific starter"
echo "  ./run-ts.sh --generated --verbose     # Test all presets with verbose output"
