#!/usr/bin/env python3
"""
Command-line interface for the PiT Python utilities.
"""

import sys
import argparse
from pathlib import Path

# Add the python directory to path
sys.path.insert(0, str(Path(__file__).parent / 'python'))

from python import (
    # System utilities
    is_linux, is_mac, is_windows, check_commands, get_pids, check_port, download_file,
    # Output utilities
    log, err, warn, bold,
    # Process utilities
    run_command,
    # Maven utilities
    compute_mvn, compute_gradle, get_maven_version,
    # Java utilities
    compute_npm, compute_java_major,
    # Vaadin utilities
    get_version_from_platform
)


def main():
    """Main CLI function."""
    parser = argparse.ArgumentParser(
        description='Platform Integration Test (PiT) Python utilities CLI',
        prog='python pit_cli.py'
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # System commands
    system_parser = subparsers.add_parser('system', help='System utilities')
    system_subparsers = system_parser.add_subparsers(dest='system_command')
    
    # OS detection
    system_subparsers.add_parser('os', help='Detect operating system')
    
    # Command checking
    check_cmd_parser = system_subparsers.add_parser('check-commands', help='Check if commands are available')
    check_cmd_parser.add_argument('commands', nargs='+', help='Commands to check')
    
    # Process management
    pid_parser = system_subparsers.add_parser('get-pids', help='Get process IDs matching pattern')
    pid_parser.add_argument('pattern', help='Process name pattern to search for')
    
    # Port checking
    port_parser = system_subparsers.add_parser('check-port', help='Check if port is busy')
    port_parser.add_argument('port', type=int, help='Port number to check')
    
    # Download file
    download_parser = system_subparsers.add_parser('download', help='Download a file')
    download_parser.add_argument('url', help='URL to download')
    download_parser.add_argument('output', nargs='?', help='Output file path (optional)')
    download_parser.add_argument('--quiet', '-q', action='store_true', help='Suppress output')
    
    # Build tool commands
    build_parser = subparsers.add_parser('build', help='Build tool utilities')
    build_subparsers = build_parser.add_subparsers(dest='build_command')
    
    build_subparsers.add_parser('detect-mvn', help='Detect Maven command')
    build_subparsers.add_parser('detect-gradle', help='Detect Gradle command')
    
    version_parser = build_subparsers.add_parser('get-version', help='Get Maven property version')
    version_parser.add_argument('property', help='Property name (e.g., vaadin.version)')
    
    # Runtime commands
    runtime_parser = subparsers.add_parser('runtime', help='Runtime utilities')
    runtime_subparsers = runtime_parser.add_subparsers(dest='runtime_command')
    
    runtime_subparsers.add_parser('detect-npm', help='Detect Node.js/npm')
    runtime_subparsers.add_parser('java-version', help='Get Java major version')
    
    # Vaadin commands
    vaadin_parser = subparsers.add_parser('vaadin', help='Vaadin utilities')
    vaadin_subparsers = vaadin_parser.add_subparsers(dest='vaadin_command')
    
    platform_version_parser = vaadin_subparsers.add_parser('platform-version', help='Get version from platform')
    platform_version_parser.add_argument('branch', help='Platform branch/version')
    platform_version_parser.add_argument('module', help='Module name (e.g., flow)')
    
    # Execute command - use 'cmd' as argument name to avoid conflict with subparser 'command'
    exec_parser = subparsers.add_parser('exec', help='Execute a command with logging')
    exec_parser.add_argument('message', help='Description of what the command does')
    exec_parser.add_argument('cmd', help='Command to execute')
    exec_parser.add_argument('--test', action='store_true', help='Test mode (show only)')
    exec_parser.add_argument('--quiet', '-q', action='store_true', help='Quiet mode')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    try:
        # System commands
        if args.command == 'system':
            if not args.system_command:
                system_parser.print_help()
                return 1
                
            if args.system_command == 'os':
                if is_linux():
                    print('Linux')
                elif is_mac():
                    print('macOS')
                elif is_windows():
                    print('Windows')
                else:
                    print('Unknown')
                return 0
                
            elif args.system_command == 'check-commands':
                if check_commands(*args.commands):
                    print('✓ All commands available')
                    return 0
                else:
                    print('✗ Some commands missing')
                    return 1
                    
            elif args.system_command == 'get-pids':
                pids = get_pids(args.pattern)
                if pids:
                    print(' '.join(pids))
                    return 0
                else:
                    print(f'No processes found matching: {args.pattern}')
                    return 1
                    
            elif args.system_command == 'check-port':
                if check_port(args.port):
                    print(f'Port {args.port} is busy')
                    return 0
                else:
                    print(f'Port {args.port} is free')
                    return 1
                    
            elif args.system_command == 'download':
                success = download_file(args.url, args.output, silent=args.quiet)
                if success:
                    print(f'✓ Downloaded: {args.url}')
                    return 0
                else:
                    print(f'✗ Failed to download: {args.url}')
                    return 1
        
        # Build tool commands
        elif args.command == 'build':
            if not args.build_command:
                build_parser.print_help()
                return 1
                
            if args.build_command == 'detect-mvn':
                mvn_cmd = compute_mvn()
                print(mvn_cmd)
                return 0
                
            elif args.build_command == 'detect-gradle':
                gradle_cmd = compute_gradle()
                print(gradle_cmd)
                return 0
                
            elif args.build_command == 'get-version':
                version = get_maven_version(args.property)
                if version:
                    print(version)
                    return 0
                else:
                    print(f'Property {args.property} not found')
                    return 1
        
        # Runtime commands
        elif args.command == 'runtime':
            if not args.runtime_command:
                runtime_parser.print_help()
                return 1
                
            if args.runtime_command == 'detect-npm':
                node_path, npm_cmd = compute_npm()
                print(f'Node: {node_path}')
                print(f'NPM: {npm_cmd}')
                return 0
                
            elif args.runtime_command == 'java-version':
                java_version = compute_java_major()
                if java_version:
                    print(java_version)
                    return 0
                else:
                    print('Could not determine Java version')
                    return 1
        
        # Vaadin commands
        elif args.command == 'vaadin':
            if not args.vaadin_command:
                vaadin_parser.print_help()
                return 1
                
            if args.vaadin_command == 'platform-version':
                version = get_version_from_platform(args.branch, args.module)
                if version:
                    print(version)
                    return 0
                else:
                    print(f'Version not found for {args.module} in {args.branch}')
                    return 1
        
        # Execute command
        elif args.command == 'exec':
            # Show what we're about to do
            if args.test:
                print(f"[TEST MODE] {args.message}", flush=True)
                print(f"[TEST MODE] Command: {args.cmd}", flush=True)
                return 0
            else:
                print(f"Executing: {args.message}", flush=True)
                print(f"Command: {args.cmd}", flush=True)
            
            return_code = run_command(
                args.message,
                args.cmd,
                quiet=args.quiet,
                test_mode=args.test,
                verbose=not args.quiet
            )
            print(f"Command completed with return code: {return_code}", flush=True)
            return return_code
            
    except Exception as e:
        err(f'Error: {e}')
        return 1


if __name__ == '__main__':
    sys.exit(main())

