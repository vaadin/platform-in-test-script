#!/usr/bin/env python3
"""
Platform Integration Test (PiT) CLI

A comprehensive Python-based testing framework for Vaadin platform components.
Migrated from bash scripts to provide better maintainability and cross-platform support.

Completed migration includes:
- Repository management (repos.py)
- Argument parsing (pit_args.py)  
- Starter/demo handling (starter_utils.py)
- Kubernetes/Control Center management (k8s_utils.py)
- Main test runner (pit_runner.py)
- Patch management (patch_utils.py)
- Playwright testing (playwright_utils.py)
- Validation framework (validation_utils.py)
- General utilities (utils.py)

Commands:
    run         Run Platform Integration Tests (equivalent to scripts/pit/run.sh)
    list        List available starters and demos
    help        Show help information

For PiT run options, use: pit_cli.py run --help
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
    get_version_from_platform,
    # PiT runner
    pit_runner
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
    
    # PiT runner command
    pit_parser = subparsers.add_parser('run', help='Run Platform Integration Tests')
    pit_parser.add_argument('--version', type=str, help='Vaadin version to test')
    pit_parser.add_argument('--demos', action='store_true', help='Run all demo projects')
    pit_parser.add_argument('--generated', action='store_true', help='Run all generated projects')
    pit_parser.add_argument('--starters', type=str, help='Comma-separated list of starters to run')
    pit_parser.add_argument('--port', type=int, default=8080, help='HTTP port for servlet container')
    pit_parser.add_argument('--timeout', type=int, default=300, help='Timeout in seconds')
    pit_parser.add_argument('--jdk', type=str, help='Specific JDK version to use')
    pit_parser.add_argument('--verbose', action='store_true', help='Show server output')
    pit_parser.add_argument('--offline', action='store_true', help='Use offline mode')
    pit_parser.add_argument('--interactive', action='store_true', help='Interactive testing mode')
    pit_parser.add_argument('--skip-tests', action='store_true', help='Skip UI tests')
    pit_parser.add_argument('--skip-current', action='store_true', help='Skip current version')
    pit_parser.add_argument('--skip-prod', action='store_true', help='Skip production validations')
    pit_parser.add_argument('--skip-dev', action='store_true', help='Skip dev-mode validations')
    pit_parser.add_argument('--skip-clean', action='store_true', help='Do not clean maven cache')
    pit_parser.add_argument('--skip-helm', action='store_true', help='Do not re-install control-center')
    pit_parser.add_argument('--skip-pw', action='store_true', help='Do not run playwright tests')
    pit_parser.add_argument('--cluster', type=str, help='Existing k8s cluster name')
    pit_parser.add_argument('--vendor', type=str, default='kind', choices=['kind', 'do', 'az', 'docker-desktop'], help='Cluster vendor')
    pit_parser.add_argument('--keep-cc', action='store_true', help='Keep control-center running')
    pit_parser.add_argument('--keep-apps', action='store_true', help='Keep installed apps')
    pit_parser.add_argument('--proxy-cc', action='store_true', help='Forward port 443 from k8s')
    pit_parser.add_argument('--events-cc', action='store_true', help='Display CC events')
    pit_parser.add_argument('--cc-version', type=str, help='Control Center version')
    pit_parser.add_argument('--skip-build', action='store_true', help='Skip building docker images')
    pit_parser.add_argument('--delete-cluster', action='store_true', help='Delete clusters')
    pit_parser.add_argument('--dashboard', type=str, choices=['install', 'uninstall'], help='Kubernetes dashboard')
    pit_parser.add_argument('--pnpm', action='store_true', help='Use pnpm instead of npm')
    pit_parser.add_argument('--vite', action='store_true', help='Use vite instead of webpack')
    pit_parser.add_argument('--git-ssh', action='store_true', help='Use git-ssh instead of https')
    pit_parser.add_argument('--commit', action='store_true', help='Commit changes to base branch')
    pit_parser.add_argument('--hub', action='store_true', help='Use selenium hub')
    pit_parser.add_argument('--headless', action='store_true', help='Run browser in headless mode')
    pit_parser.add_argument('--headed', action='store_true', help='Run browser in headed mode')
    pit_parser.add_argument('--test', action='store_true', help='Show commands but do not run them')
    pit_parser.add_argument('--list', action='store_true', help='Show available starters')
    pit_parser.add_argument('--function', type=str, help='Run specific function')
    pit_parser.add_argument('--path', action='store_true', help='Show available SW paths')
    
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
        
        # PiT runner command
        elif args.command == 'run':
            # Convert argparse Namespace to list for pit_runner
            pit_args = []
            
            # Add all PiT-specific arguments
            if args.version:
                pit_args.extend(['--version', args.version])
            if args.demos:
                pit_args.append('--demos')
            if args.generated:
                pit_args.append('--generated')
            if args.starters:
                pit_args.extend(['--starters', args.starters])
            if args.port != 8080:
                pit_args.extend(['--port', str(args.port)])
            if args.timeout != 300:
                pit_args.extend(['--timeout', str(args.timeout)])
            if args.jdk:
                pit_args.extend(['--jdk', args.jdk])
            if args.verbose:
                pit_args.append('--verbose')
            if args.offline:
                pit_args.append('--offline')
            if args.interactive:
                pit_args.append('--interactive')
            if args.skip_tests:
                pit_args.append('--skip-tests')
            if args.skip_current:
                pit_args.append('--skip-current')
            if args.skip_prod:
                pit_args.append('--skip-prod')
            if args.skip_dev:
                pit_args.append('--skip-dev')
            if args.skip_clean:
                pit_args.append('--skip-clean')
            if args.skip_helm:
                pit_args.append('--skip-helm')
            if args.skip_pw:
                pit_args.append('--skip-pw')
            if args.cluster:
                pit_args.extend(['--cluster', args.cluster])
            if args.vendor != 'kind':
                pit_args.extend(['--vendor', args.vendor])
            if args.keep_cc:
                pit_args.append('--keep-cc')
            if args.keep_apps:
                pit_args.append('--keep-apps')
            if args.proxy_cc:
                pit_args.append('--proxy-cc')
            if args.events_cc:
                pit_args.append('--events-cc')
            if args.cc_version:
                pit_args.extend(['--cc-version', args.cc_version])
            if args.skip_build:
                pit_args.append('--skip-build')
            if args.delete_cluster:
                pit_args.append('--delete-cluster')
            if args.dashboard:
                pit_args.extend(['--dashboard', args.dashboard])
            if args.pnpm:
                pit_args.append('--pnpm')
            if args.vite:
                pit_args.append('--vite')
            if args.git_ssh:
                pit_args.append('--git-ssh')
            if args.commit:
                pit_args.append('--commit')
            if args.hub:
                pit_args.append('--hub')
            if args.headless:
                pit_args.append('--headless')
            if args.headed:
                pit_args.append('--headed')
            if args.test:
                pit_args.append('--test')
            if args.list:
                pit_args.append('--list')
            if args.function:
                pit_args.extend(['--function', args.function])
            if args.path:
                pit_args.append('--path')
            
            # Run the PiT runner
            return pit_runner.main(pit_args)
            
    except Exception as e:
        err(f'Error: {e}')
        return 1


if __name__ == '__main__':
    sys.exit(main())

