#!/usr/bin/env python3
"""
Example script demonstrating the usage of the PiT Python utilities.

This script shows how to use the various utility functions that were
converted from the original bash lib-utils.sh file.
"""

import sys
import os
from pathlib import Path

# Add the python directory to the path so we can import our utilities
sys.path.insert(0, str(Path(__file__).parent))

# Import PiT utilities
from python import (
    # System utilities
    is_linux, is_mac, is_windows, check_commands,
    
    # Output utilities  
    log, bold, err, warn, cmd, print_time,
    
    # Process utilities
    run_command, wait_until_port, check_http_servlet,
    
    # Maven/Gradle utilities
    compute_mvn, compute_gradle, get_maven_version,
    change_maven_property, add_prereleases,
    
    # Java utilities
    compute_npm, install_jdk_runtime, set_java_path,
    disable_launch_browser, enable_pnpm,
    
    # Vaadin utilities
    remove_pro_key, restore_pro_key, get_version_from_platform,
    set_flow_version, compute_version,
    
    # Cleanup
    cleanup_and_exit
)


def main():
    """Main example function."""
    try:
        # Example 1: System detection
        bold("=== System Detection ===")
        log(f"Operating System: {'Linux' if is_linux() else 'macOS' if is_mac() else 'Windows' if is_windows() else 'Unknown'}")
        
        # Example 2: Command checking
        bold("=== Command Availability ===")
        if check_commands('java', 'mvn'):
            log("Required commands are available")
        else:
            err("Some required commands are missing")
        
        # Example 3: Maven/Gradle detection
        bold("=== Build Tool Detection ===")
        mvn_cmd = compute_mvn()
        gradle_cmd = compute_gradle()
        log(f"Maven command: {mvn_cmd}")
        log(f"Gradle command: {gradle_cmd}")
        
        # Example 4: Java/Node setup
        bold("=== Tool Configuration ===")
        node_path, npm_cmd = compute_npm()
        log(f"Node.js path: {node_path}")
        log(f"NPM command: {npm_cmd}")
        
        # Example 5: Project configuration (if in a Maven project)
        if Path('pom.xml').exists():
            bold("=== Maven Project Configuration ===")
            
            # Get current Vaadin version
            vaadin_version = get_maven_version('vaadin.version')
            if vaadin_version:
                log(f"Current Vaadin version: {vaadin_version}")
            
            # Example: Add pre-releases repository
            log("Adding pre-releases repository...")
            add_prereleases()
            
            # Example: Disable browser launch
            log("Disabling automatic browser launch...")
            disable_launch_browser()
            
            # Example: Enable pnpm for faster builds
            log("Enabling pnpm...")
            enable_pnpm()
        
        # Example 6: Vaadin license management
        bold("=== License Management ===")
        log("Removing Pro key (if exists)...")
        remove_pro_key()
        
        log("Restoring Pro key...")
        restore_pro_key()
        
        # Example 7: Version management
        bold("=== Version Management ===")
        platform_version = "24.4.0"
        flow_version = get_version_from_platform(platform_version, 'flow')
        if flow_version:
            log(f"Flow version for platform {platform_version}: {flow_version}")
        
        # Example 8: Running commands
        bold("=== Command Execution ===")
        if is_windows():
            return_code = run_command(
                "Listing current directory",
                "dir",
                test_mode=True  # Only show what would be run
            )
        else:
            return_code = run_command(
                "Listing current directory", 
                "ls -la",
                test_mode=True  # Only show what would be run
            )
        
        log(f"Command return code: {return_code}")
        
        # Example 9: Port checking
        bold("=== Network Utilities ===")
        test_port = 8080
        if wait_until_port(test_port, timeout=1, log_file=""):
            log(f"Port {test_port} is available")
        else:
            log(f"Port {test_port} is not available or timeout reached")
        
        # Example 10: HTTP checking
        test_url = "https://httpbin.org/status/200"
        if check_http_servlet(test_url):
            log(f"URL {test_url} returned HTTP 200")
        else:
            log(f"URL {test_url} did not return HTTP 200")
        
        bold("=== Example Complete ===")
        print_time()
        
    except KeyboardInterrupt:
        warn("Example interrupted by user")
        return 1
    except Exception as e:
        err(f"Example failed with error: {e}")
        return 1
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
