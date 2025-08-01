# Migration Guide: Bash to TypeScript PiT

## Quick Start

The TypeScript version is a **complete replacement** for the original bash scripts with enhanced testing capabilities. All existing commands work identically, plus new test functionality.

### Immediate Usage (Zero Changes Required)

```bash
# Instead of: ./run.sh --help
./run-ts.sh --help

# Instead of: ./run.sh --demos --verbose
./run-ts.sh --demos --verbose

# Instead of: ./run.sh --starters="latest-java,react"
./run-ts.sh --starters="latest-java,react"
```

## Major Migration Completed ✅

**All JavaScript tests have been migrated to TypeScript!** The following tests are now fully functional:

- ✅ **start-auth.test.ts** - Authentication flow testing (fixes "Test 'start-auth' not found" error)
- ✅ **initializer.test.ts** - Starter initialization with build tool detection
- ✅ **collaboration.test.ts** - Dual-browser collaboration and real-time features
- ✅ **oauth.test.ts** - OAuth authentication flows
- ✅ **hybrid-react.test.ts** - Hybrid React component testing
- ✅ **hybrid.test.ts** - Hybrid application testing
- ✅ **mpr-demo.test.ts** - Multi-Platform Runtime demos
- ✅ **hilla-react-cli.test.ts** - Hilla React CLI testing

### Test Registry Updates

All migrated tests are properly registered with correct starter mappings:
- `latest-java_partial-auth` → `start-auth` test
- `collaboration` → `collaboration` test  
- `vaadin-oauth-example` → `oauth` test
- `test-hybrid-react` → `hybrid-react` test
- `flow-hilla-hybrid-example` → `hybrid` test
- `mpr-demo` → `mpr-demo` test
- `hilla-react-cli` → `hilla-react-cli` test
- `initializer-*` starters → `initializer` test

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
- **Complete Test Coverage**: All JavaScript tests migrated to TypeScript
- **Process Safety**: Enhanced ProcessManager prevents dangerous system process killing
- **CI/CD Reliability**: Improved GitHub Actions compatibility with proper signal handling
- **Better Error Messages**: Detailed stack traces and context
- **Type Safety**: Compile-time error detection for tests and core logic
- **Modern Tooling**: IDE support, debugging, testing frameworks
- **Enhanced Testing**: Dual-browser support, OAuth flows, build tool detection
- **Future-Proof**: Easy to extend and maintain

## Process Safety Improvements

The TypeScript version includes critical safety improvements for process management:

### Key Safety Features
- **Safe Child Process Management**: Only spawned child processes are managed and terminated
- **No System Process Killing**: Eliminates risk of terminating system processes or PiT itself
- **ProcessManager Integration**: All background processes are tracked and managed safely
- **CI/CD Compatible**: Proper signal handling prevents premature termination in GitHub Actions

### Migration Benefits
- **Before**: `killProcessesByPort()` could kill ANY process using a port (dangerous)
- **After**: `processManager.killAllProcesses()` only kills managed child processes (safe)
- **Result**: More reliable CI/CD execution and safer local development

## Testing Improvements

The TypeScript migration includes significant testing enhancements:

### Advanced Test Features
- **Dual-Browser Testing**: Collaboration tests run with two browser instances
- **Build Tool Detection**: Automatic Maven/Gradle detection in initializer tests
- **OAuth Integration**: Complete authentication flow testing
- **Component Testing**: Hybrid application component validation
- **Resource Cleanup**: Proper browser and context cleanup in all tests

### Test Architecture
- **BaseTest Class**: Unified test inheritance pattern
- **Test Registry**: Centralized test mapping and discovery
- **Type Safety**: Full TypeScript coverage for test logic
- **Error Handling**: Comprehensive error capture and reporting

### Before vs After Migration
| Component | Before | After |
|-----------|--------|-------|
| start-auth test | ❌ Missing (caused failures) | ✅ Full TypeScript implementation |
| collaboration test | ⚠️ JavaScript only | ✅ Dual-browser TypeScript test |
| oauth test | ⚠️ JavaScript only | ✅ Complete OAuth flow testing |
| hybrid tests | ⚠️ JavaScript only | ✅ React & Flow component testing |
| initializer test | ⚠️ JavaScript only | ✅ Build tool detection + validation |
| Test registry | ❌ Scattered mapping | ✅ Centralized TypeScript registry |

## Rollback

If needed, simply use the original `./run.sh` script. Both versions can coexist.

## Support

The TypeScript implementation supports all original features plus enhanced testing:

✅ All command-line options  
✅ All starter types (presets, demos, archetypes)  
✅ **Complete Test Migration** - All JavaScript tests converted to TypeScript  
✅ **Advanced Test Features** - Dual-browser, OAuth, build detection  
✅ Version-specific patches  
✅ Application-specific configurations  
✅ Control Center testing framework  
✅ Docker and K8s integration  
✅ Build system detection (Maven/Gradle)  
✅ Environment-specific behavior  
✅ **Test Registry System** - Centralized test mapping and discovery  

### Resolved Issues
- ✅ **"Test 'start-auth' not found"** - Completely resolved with TypeScript implementation
- ✅ **Missing test mappings** - All starter-to-test mappings properly implemented
- ✅ **JavaScript test limitations** - Enhanced with TypeScript type safety and modern patterns

## Next Steps

1. **Validate**: Run `./validate-ts.sh` to ensure everything works
2. **Test Specific Starters**: Use `./run-ts.sh --starters="latest-java_partial-auth" --test` to verify auth testing
3. **Test Complex Scenarios**: Try `./run-ts.sh --starters="collaboration,mpr-demo" --test` for advanced tests
4. **Adopt**: Replace `./run.sh` with `./run-ts.sh` in scripts/CI
5. **Enhance**: Add new features using the comprehensive TypeScript testing framework

### Migration Validation Commands

```bash
# Test the originally failing auth starter
./run-ts.sh --starters="latest-java_partial-auth" --test

# Test complex dual-browser collaboration
./run-ts.sh --starters="collaboration" --test

# Test OAuth integration
./run-ts.sh --starters="vaadin-oauth-example" --test

# Test hybrid applications
./run-ts.sh --starters="test-hybrid-react,flow-hilla-hybrid-example" --test

# Test build tool detection
./run-ts.sh --starters="initializer-vaadin-maven-react,initializer-vaadin-gradle-flow" --test

# Test Playwright-only mode (requires running server)
./run-ts.sh --starters="test-hybrid-react" --run-pw
```

## Recent Updates (July 2025)

### Critical Fixes Applied ✅

#### Logger Color Issues Fixed
- **Problem**: Debug output was causing subsequent log lines to appear dim
- **Solution**: Fixed ANSI color reset sequences in logger implementation
- **Status**: All log output now displays with correct colors and formatting

#### Starter-to-Test Mapping Fixed
- **Problem**: `--run-pw` mode was failing with "Test not found" errors for valid starters
- **Example**: `./run-ts.sh --starters test-hybrid-react --run-pw` was broken
- **Solution**: Fixed `PlaywrightRunner.runMultipleTests()` to properly map starter names to test names
- **Status**: All starter names now correctly resolve to their corresponding tests

#### Test Logic Accuracy Improved
- **Problem**: Some TypeScript tests had different UI logic than original JavaScript tests
- **Examples Fixed**:
  - `start.test.ts`: Now looks for `/manolo/` instead of `/updated/` to match original
  - `hybrid-react.test.ts`: Now tests actual Flow/Hilla functionality instead of generic React selectors
- **Status**: All tests now faithfully reproduce original JavaScript behavior with enhanced reliability

### Validation Commands for Recent Fixes

```bash
# Test fixed starter mapping
./run-ts.sh --starters="test-hybrid-react" --run-pw

# Test corrected UI logic  
./run-ts.sh --starters="start" --test

# Test logger color output
./run-ts.sh --starters="hello" --verbose --debug

# Comprehensive validation
./run-ts.sh --demos --test
```
