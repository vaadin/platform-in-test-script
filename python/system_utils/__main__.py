#!/usr/bin/env python3
"""
Command-line interface for the system_utils module.
"""

import sys
import argparse
from . import (
    is_linux, is_mac, is_windows,
    check_commands, get_pids, check_port,
    download_file
)


def main():
    """Main CLI function for system_utils."""
    parser = argparse.ArgumentParser(
        description='System utilities command-line interface',
        prog='python -m python.system_utils'
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # OS detection
    os_parser = subparsers.add_parser('os', help='Detect operating system')
    
    # Command checking
    cmd_parser = subparsers.add_parser('check-commands', help='Check if commands are available')
    cmd_parser.add_argument('commands', nargs='+', help='Commands to check')
    
    # Process management
    pid_parser = subparsers.add_parser('get-pids', help='Get process IDs matching pattern')
    pid_parser.add_argument('pattern', help='Process name pattern to search for')
    
    # Port checking
    port_parser = subparsers.add_parser('check-port', help='Check if port is busy')
    port_parser.add_argument('port', type=int, help='Port number to check')
    
    # Download file
    download_parser = subparsers.add_parser('download', help='Download a file')
    download_parser.add_argument('url', help='URL to download')
    download_parser.add_argument('output', nargs='?', help='Output file path (optional)')
    download_parser.add_argument('--quiet', '-q', action='store_true', help='Suppress output')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    try:
        if args.command == 'os':
            if is_linux():
                print('Linux')
            elif is_mac():
                print('macOS')
            elif is_windows():
                print('Windows')
            else:
                print('Unknown')
            return 0
            
        elif args.command == 'check-commands':
            if check_commands(*args.commands):
                print('All commands available')
                return 0
            else:
                print('Some commands missing')
                return 1
                
        elif args.command == 'get-pids':
            pids = get_pids(args.pattern)
            if pids:
                print(' '.join(pids))
                return 0
            else:
                print(f'No processes found matching: {args.pattern}')
                return 1
                
        elif args.command == 'check-port':
            if check_port(args.port):
                print(f'Port {args.port} is busy')
                return 0
            else:
                print(f'Port {args.port} is free')
                return 1
                
        elif args.command == 'download':
            success = download_file(args.url, args.output, silent=args.quiet)
            if success:
                print(f'Downloaded: {args.url}')
                return 0
            else:
                print(f'Failed to download: {args.url}')
                return 1
                
    except Exception as e:
        print(f'Error: {e}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
