# Platform Integration Test (PiT) Python Utilities

This directory contains a Python implementation of the bash utilities found in `lib-utils.sh`. The Python version provides the same functionality as the original bash script but with better error handling, type safety, and cross-platform compatibility.

## Overview

The original `lib-utils.sh` file contained numerous utility functions for:
- System detection and command checking
- Process management and command execution
- Maven/Gradle project handling
- Java runtime management
- Vaadin-specific operations
- Output formatting and logging

All of these functions have been recreated in Python, organized into logical modules for better maintainability.

## Module Structure

### `system_utils.py`
Core system utilities for platform detection and basic operations:
- `is_linux()`, `is_mac()`, `is_windows()` - OS detection
- `check_commands()` - Verify command availability
- `get_pids()`, `kill_process()` - Process management
- `check_port()` - Network port checking
- `download_file()` - File downloading

### `output_utils.py`
Output formatting, logging, and user interaction:
- `log()`, `bold()`, `err()`, `warn()` - Colored logging
- `cmd()`, `dim()` - Command and status output
- `report_error()` - GitHub Actions integration
- `ask()` - User input handling
- `print_time()` - Elapsed time reporting

### `process_utils.py`
Advanced process management and command execution:
- `ProcessManager` - Background process tracking
- `run_command()` - Command execution with logging
- `run_to_file()`, `run_in_background_to_file()` - Output redirection
- `wait_until_message_in_file()` - Log file monitoring
- `check_http_servlet()` - HTTP endpoint testing
- `wait_until_frontend_compiled()` - Vaadin dev-mode checking

### `maven_utils.py`
Maven and Gradle project management:
- `compute_mvn()`, `compute_gradle()` - Build tool detection
- `get_pom_files()` - Project file discovery
- `change_maven_property()`, `change_maven_block()` - POM manipulation
- `get_maven_version()`, `set_version()` - Version management
- `add_repo_to_pom()`, `add_repo_to_gradle()` - Repository configuration
- `check_no_spring_dependencies()` - Dependency validation

### `java_utils.py`
Java runtime and development tool management:
- `compute_npm()` - Node.js/npm detection
- `install_jbr_runtime()`, `install_jdk_runtime()` - Runtime installation
- `set_java_path()`, `unset_java_path()` - Environment management
- `enable_jbr_autoreload()` - HotSwap configuration
- `upgrade_gradle()` - Gradle version management
- `enable_pnpm()`, `enable_vite()` - Frontend tool configuration

### `vaadin_utils.py`
Vaadin-specific utilities and operations:
- `remove_pro_key()`, `restore_pro_key()` - License management
- `get_version_from_platform()` - Platform version resolution
- `set_flow_version()`, `set_mpr_version()` - Component versioning
- `get_latest_hilla_version()` - Hilla version computation
- `add_prereleases()`, `enable_snapshots()` - Repository configuration
- `validate_token()` - GitHub integration

## Usage

### Basic Example

```python
from python import (
    log, err, is_windows, check_commands,
    run_command, compute_mvn, add_prereleases
)

# System detection
if is_windows():
    log("Running on Windows")

# Check required tools
if not check_commands('java', 'mvn'):
    err("Missing required commands")
    exit(1)

# Build tool detection
mvn_cmd = compute_mvn()
log(f"Using Maven command: {mvn_cmd}")

# Run a command
return_code = run_command(
    "Building project",
    f"{mvn_cmd} clean compile"
)

# Configure repositories
add_prereleases()
```

### Advanced Process Management

```python
from python import (
    ProcessManager, run_in_background_to_file,
    wait_until_message_in_file, cleanup_and_exit
)

# Start a background server
process = run_in_background_to_file(
    "mvn spring-boot:run",
    "server.log",
    verbose=True
)

# Wait for server to start
result = wait_until_message_in_file(
    "server.log",
    "Started.*in.*seconds",
    timeout=120,
    command_desc="Spring Boot application"
)

if result == 0:
    log("Server started successfully")
else:
    err("Server failed to start")

# Cleanup automatically handles background processes
cleanup_and_exit()
```

### Maven Project Configuration

```python
from python import (
    get_maven_version, set_version,
    change_maven_property, add_repo_to_pom
)

# Get current version
current_version = get_maven_version('vaadin.version')
log(f"Current Vaadin version: {current_version}")

# Update version
new_version = set_version('vaadin.version', '24.4.0')
if new_version:
    log(f"Updated to version: {new_version}")

# Add custom repository
add_repo_to_pom('https://maven.vaadin.com/vaadin-prereleases')

# Configure properties
change_maven_property('vaadin.pnpm.enable', 'true')
```

## Key Improvements Over Bash

1. **Type Safety**: Python's type hints help catch errors early
2. **Error Handling**: Proper exception handling and error reporting
3. **Cross-Platform**: Better Windows compatibility
4. **Maintainability**: Organized into logical modules
5. **Testing**: Easier to unit test individual functions
6. **Documentation**: Comprehensive docstrings and examples

## Environment Variables

The utilities respect the same environment variables as the bash version:

- `TEST` - When set, commands are only shown, not executed
- `VERBOSE` - Enables verbose output
- `OFFLINE` - Skips network operations
- `HEADLESS` - Forces headless mode
- `GHTK` - GitHub token for API access
- `GITHUB_STEP_SUMMARY` - GitHub Actions step summary file

## Running the Example

To see the utilities in action:

```bash
python example_usage.py
```

This will demonstrate various utility functions and show their output.

## Command Line Usage

You can also use the utilities from the command line via the provided CLI script:

### System Utilities

```bash
# Detect operating system
python pit_cli.py system os

# Check if commands are available
python pit_cli.py system check-commands java mvn git

# Get process IDs matching a pattern
python pit_cli.py system get-pids java

# Check if a port is busy
python pit_cli.py system check-port 8080

# Download a file
python pit_cli.py system download https://httpbin.org/status/200 test.txt
```

### Build Tool Detection

```bash
# Detect Maven command
python pit_cli.py build detect-mvn

# Detect Gradle command  
python pit_cli.py build detect-gradle

# Get Maven property version
python pit_cli.py build get-version vaadin.version
```

### Runtime Detection

```bash
# Detect Node.js and npm
python pit_cli.py runtime detect-npm

# Get Java major version
python pit_cli.py runtime java-version
```

### Vaadin Utilities

```bash
# Get version from platform
python pit_cli.py vaadin platform-version 24.4.0 flow
```

### Execute Commands

```bash
# Execute a command with logging
python pit_cli.py exec "Building project" "mvn clean compile"

# Test mode (show what would be executed)
python pit_cli.py exec "Building project" "mvn clean compile" --test

# Quiet mode
python pit_cli.py exec "Building project" "mvn clean compile" --quiet
```

### Quick One-Liners

For simple operations, you can also use Python's `-c` flag:

```bash
# Check operating system
python -c "from python.system_utils import is_windows; print('Windows' if is_windows() else 'Not Windows')"

# Check if Java is available
python -c "from python.system_utils import check_commands; exit(0 if check_commands('java') else 1)"

# Get current Vaadin version
python -c "from python.maven_utils import get_maven_version; print(get_maven_version('vaadin.version') or 'Not found')"
```

## Migration from Bash

To migrate existing bash scripts:

1. Replace bash function calls with Python imports
2. Use the `run_command()` function for shell commands
3. Replace bash variables with Python variables
4. Use the `ProcessManager` for background processes
5. Call `cleanup_and_exit()` instead of the bash `doExit()` function

## Dependencies

The implementation uses only Python standard library modules:
- `os`, `sys` - System operations
- `subprocess` - Process management
- `pathlib` - Path handling
- `urllib` - HTTP operations
- `json` - JSON parsing
- `re` - Regular expressions
- `time` - Time operations
- `threading` - Background operations

No external dependencies are required, making it easy to integrate into existing projects.
