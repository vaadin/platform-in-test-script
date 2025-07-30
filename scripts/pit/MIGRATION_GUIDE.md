# Migration Guide: Bash to TypeScript PiT

## Quick Start

The TypeScript version is a **drop-in replacement** for the original bash scripts. All existing commands work identically.

### Immediate Usage (Zero Changes Required)

```bash
# Instead of: ./run.sh --help
./run-ts.sh --help

# Instead of: ./run.sh --demos --verbose
./run-ts.sh --demos --verbose

# Instead of: ./run.sh --starters="latest-java,react"
./run-ts.sh --starters="latest-java,react"
```

## Installation

1. **Prerequisites**: Node.js 18.0.0 or higher
2. **Automatic Setup**: The `run-ts.sh` script handles everything automatically:
   - Installs dependencies on first run
   - Builds TypeScript code
   - Runs with identical interface

## Command Equivalence

| Original Bash | TypeScript | Notes |
|---------------|------------|-------|
| `./run.sh --help` | `./run-ts.sh --help` | Identical output |
| `./run.sh --list` | `./run-ts.sh --list` | Same starter list |
| `./run.sh --demos` | `./run-ts.sh --demos` | Same functionality |
| `./run.sh --test --starters="app"` | `./run-ts.sh --test --starters="app"` | Dry run mode |

**Note**: The only difference is `--version` became `--vaadin-version` to avoid conflicts with Node.js conventions.

## Validation

Run the validation script to verify everything works:

```bash
./validate-ts.sh
```

## Development Mode

For active development of the TypeScript version:

```bash
cd ts
npm install
npm run dev -- --help        # Run directly from TypeScript
npm run build:watch          # Auto-rebuild on changes
npm run lint                 # Check code quality
```

## Benefits

- **Same Interface**: Zero learning curve
- **Better Error Messages**: Detailed stack traces and context
- **Type Safety**: Compile-time error detection
- **Modern Tooling**: IDE support, debugging, testing
- **Future-Proof**: Easy to extend and maintain

## Rollback

If needed, simply use the original `./run.sh` script. Both versions can coexist.

## Support

The TypeScript implementation supports all original features:

✅ All command-line options  
✅ All starter types (presets, demos, archetypes)  
✅ Version-specific patches  
✅ Application-specific configurations  
✅ Control Center testing framework  
✅ Docker and K8s integration  
✅ Build system detection (Maven/Gradle)  
✅ Environment-specific behavior  

## Next Steps

1. **Validate**: Run `./validate-ts.sh` to ensure everything works
2. **Test**: Use `./run-ts.sh --test --demos` for a comprehensive dry run
3. **Adopt**: Replace `./run.sh` with `./run-ts.sh` in scripts/CI
4. **Enhance**: Add new features using the TypeScript codebase
