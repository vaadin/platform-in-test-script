# PiT (Platform in Test) - TypeScript Implementation

This is a TypeScript implementation of the Vaadin Platform in Test (PiT) testing suite, converted from the original bash scripts while maintaining the same behavior and functionality.

## Recent Updates

**Latest Release - All Critical Issues Resolved:**
- ✅ Fixed logger color formatting (ANSI color reset sequences)
- ✅ Resolved starter-to-test mapping for `--run-pw` mode
- ✅ Aligned TypeScript test logic with JavaScript originals
- ✅ Updated comprehensive documentation with validation commands

For detailed information, see [CHANGELOG.md](CHANGELOG.md) and [CONVERSION_SUMMARY.md](CONVERSION_SUMMARY.md).

## Features

- ✅ All original command-line options preserved
- ✅ Support for testing Vaadin starters and demos
- ✅ Generation from start.vaadin.com, archetypes, and initializer
- ✅ Demo checkout from GitHub repositories
- ✅ Application-specific patches and configurations
- ✅ Version-specific patches for different Vaadin releases
- ✅ Control Center testing support (K8s)
- ✅ Maven and Gradle project support
- ✅ Comprehensive logging with color output
- ✅ Configuration validation
- ✅ Error handling and cleanup

## Requirements

- Node.js 18.0.0 or higher
- Git
- Maven or Gradle (depending on projects being tested)
- Java 17+ (will be downgraded automatically when needed)
- curl and jq (for API calls)

## Installation

```bash
cd ts
npm install
npm run build
```

## Usage

### Development Mode
```bash
npm run dev -- --help
```

### Production Mode
```bash
npm run build
npm start -- --help
```

### Direct TypeScript Execution
```bash
npx tsx src/index.ts --help
```

## Command Line Options

All original options are supported:

```
Options:
  --version <string>     Vaadin version to test (default: "current")
  --demos               Run all demo projects
  --generated           Run all generated projects (start and archetypes)
  --port <number>       HTTP port for the servlet container (default: "8080")
  --timeout <number>    Time in secs to wait for server to start (default: "300")
  --jdk <number>        Use a specific JDK version to run the tests
  --verbose             Show server output (default: false)
  --offline             Do not remove already downloaded projects (default: false)
  --interactive         Play a bell and ask user to manually test (default: false)
  --skip-tests          Skip UI Tests (default: false)
  --skip-current        Skip running build in current version (default: false)
  --skip-prod           Skip production validations (default: false)
  --skip-dev            Skip dev-mode validations (default: false)
  --skip-clean          Do not clean maven cache (default: false)
  --skip-helm           Do not re-install control-center with helm (default: false)
  --skip-pw             Do not run playwright tests (default: false)
  --cluster <name>      Run tests in an existing k8s cluster (default: "pit")
  --vendor <name>       Use a specific cluster vendor (dd, kind, do) (default: "kind")
  --keep-cc             Keep control-center running after tests (default: false)
  --keep-apps           Keep installed apps in control-center (default: false)
  --proxy-cc            Forward port 443 from k8s cluster to localhost (default: false)
  --events-cc           Display events from control-center (default: false)
  --cc-version <string> Install this version for current (default: "current")
  --skip-build          Skip building the docker images for control-center (default: false)
  --delete-cluster      Delete the cluster/s (default: false)
  --dashboard <action>  Install kubernetes dashboard (install, uninstall) (default: "install")
  --pnpm                Use pnpm instead of npm (default: false)
  --vite                Use vite instead of webpack (default: false)
  --list                Show the list of available starters
  --hub                 Use selenium hub instead of local chrome (default: false)
  --commit              Commit changes to the base branch (default: false)
  --test                Show steps and commands but don't run them (default: false)
  --git-ssh             Use git-ssh instead of https (default: false)
  --headless            Run the browser in headless mode (default: true)
  --headed              Run the browser in headed mode (default: false)
  --function <function> Run only one function
  --starters <list>     List of demos or presets separated by comma
  -h, --help            display help for command
```

## Examples

### Test all presets (generated projects)
```bash
npm start -- --generated
```

### Test all demos (GitHub repositories)
```bash
npm start -- --demos
```

### Test specific starters
```bash
npm start -- --starters="latest-java,react,bookstore-example"
```

### Test with specific version
```bash
npm start -- --version=24.5.0 --starters="latest-java"
```

### Dry run (show commands without executing)
```bash
npm start -- --test --starters="latest-java"
```

### Run with verbose output
```bash
npm start -- --verbose --starters="latest-java"
```

## Architecture

### Core Components

- **`PitRunner`**: Main orchestrator that manages the test execution flow
- **`StarterRunner`**: Handles generation and testing of starters from start.vaadin.com or archetypes
- **`DemoRunner`**: Handles checkout and testing of demo projects from GitHub
- **`PatchManager`**: Applies version-specific and application-specific patches
- **CLI**: Command-line argument parsing and validation

### Utilities

- **Logger**: Colored console output with different log levels
- **System**: OS detection, command execution, process management
- **File**: File system operations, JSON/text file handling
- **Patches**: Automated code patching for different scenarios

### Key Features

1. **Starter Generation**: Supports multiple sources:
   - start.vaadin.com presets
   - Maven archetypes
   - Spring Initializer variants

2. **Demo Management**: 
   - GitHub repository checkout
   - Branch and tag handling
   - Subpath navigation

3. **Patch System**:
   - Version-specific patches (pre-release, snapshots, etc.)
   - Application-specific configurations
   - Java version management

4. **Build System Support**:
   - Maven and Gradle detection
   - Offline mode support
   - PNPM integration

## Migration from Bash

The TypeScript implementation maintains 100% compatibility with the original bash scripts:

- All command-line options work identically
- Same behavior for test execution
- Same output formatting and logging
- Same error handling and exit codes
- Same temporary file handling

### Key Improvements

- **Type Safety**: Full TypeScript type checking
- **Error Handling**: Comprehensive error catching and reporting
- **Modularity**: Clean separation of concerns
- **Maintainability**: Object-oriented architecture
- **Testability**: Unit test support with Jest
- **Documentation**: JSDoc comments and type definitions

## Development

### Building
```bash
npm run build
```

### Watching for Changes
```bash
npm run build:watch
```

### Linting
```bash
npm run lint
npm run lint:fix
```

### Formatting
```bash
npm run format
```

### Testing
```bash
npm test
```

## Environment Variables

The following environment variables are used by specific tests:

- `OPENAI_TOKEN`: Required for form-filler-demo
- `GHTK`: GitHub token required for releases-graph demo
- `GITHUB_ACTIONS`: Detected automatically in CI environments

## Supported Starters and Demos

See the output of `--list` for the complete list of supported starters and demos.

## Validation and Testing

After installation, validate the fixes with:

```bash
# Test logger color formatting
npm run dev -- --starters hello --dev --clean

# Test starter-to-test mapping
npm run dev -- --starters test-hybrid-react --run-pw

# Test specific implementations
npm run dev -- --starters test-start --run-pw
npm run dev -- --starters test-hybrid-react --run-pw
```

## Contributing

1. Follow the existing code style
2. Add type definitions for new functionality
3. Update tests for any changes
4. Ensure all linting passes
5. Update documentation as needed

## License

Apache 2.0 - Same as the original Vaadin PiT scripts.
