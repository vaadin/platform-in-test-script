#!/usr/bin/env python3
"""
System utilities for platform detection, command checking, and basic system operations.
"""

import platform
import subprocess
import shutil
import os
import sys
from pathlib import Path
from typing import List, Optional, Union


def is_linux() -> bool:
    """Check if the current system is Linux."""
    return platform.system() == 'Linux'


def is_mac() -> bool:
    """Check if the current system is Darwin (macOS)."""
    return platform.system() == 'Darwin'


def is_windows() -> bool:
    """Check if the current system is Windows."""
    return platform.system() == 'Windows'


def check_commands(*command_names: str) -> bool:
    """
    Check if a set of commands are installed and available in PATH.
    
    Args:
        *command_names: Variable number of command names to check
        
    Returns:
        bool: True if all commands are available, False otherwise
    """
    for command_name in command_names:
        if not shutil.which(command_name):
            print(f"Command: '{command_name}' is not installed", file=sys.stderr)
            return False
    return True


def get_pids(process_pattern: str) -> List[str]:
    """
    Get process IDs for processes matching the given pattern.
    
    Args:
        process_pattern: Pattern to match in process command line
        
    Returns:
        List of process IDs as strings
    """
    pids = []
    try:
        if is_linux():
            # Try using /proc filesystem first
            proc_dir = Path('/proc')
            if proc_dir.exists():
                for pid_dir in proc_dir.iterdir():
                    if pid_dir.is_dir() and pid_dir.name.isdigit():
                        try:
                            cmdline_file = pid_dir / 'cmdline'
                            if cmdline_file.exists():
                                with open(cmdline_file, 'r') as f:
                                    cmdline = f.read()
                                    if process_pattern in cmdline:
                                        pids.append(pid_dir.name)
                        except (PermissionError, FileNotFoundError):
                            continue
        
        # Fallback to ps command
        if not pids:
            try:
                if is_windows():
                    result = subprocess.run(['tasklist'], capture_output=True, text=True)
                    for line in result.stdout.splitlines():
                        if process_pattern in line:
                            parts = line.split()
                            if len(parts) >= 2:
                                pids.append(parts[1])
                else:
                    result = subprocess.run(['ps', '-eo', 'pid,cmd'], capture_output=True, text=True)
                    for line in result.stdout.splitlines():
                        if process_pattern in line and 'grep' not in line:
                            parts = line.strip().split()
                            if parts:
                                pids.append(parts[0])
            except subprocess.SubprocessError:
                pass
                
    except Exception:
        pass
    
    return pids


def kill_process(*pids: Union[str, int]) -> None:
    """
    Kill processes and their children.
    
    Args:
        *pids: Variable number of process IDs to kill
    """
    import signal
    
    for pid in pids:
        pid_str = str(pid)
        try:
            # Get child processes first
            child_pids = []
            if shutil.which('pgrep'):
                result = subprocess.run(['pgrep', '-P', pid_str], 
                                      capture_output=True, text=True)
                if result.returncode == 0:
                    child_pids = result.stdout.strip().split('\n')
            
            # Kill children first, then parent
            all_pids = child_pids + [pid_str]
            for p in all_pids:
                if p and p.isdigit():
                    try:
                        if is_windows():
                            subprocess.run(['taskkill', '/F', '/PID', p], 
                                         capture_output=True)
                        else:
                            os.kill(int(p), signal.SIGTERM)
                    except (ProcessLookupError, OSError, ValueError):
                        pass
        except Exception:
            pass


def check_port(port: int) -> bool:
    """
    Check if a port is occupied.
    
    Args:
        port: Port number to check
        
    Returns:
        bool: True if port is occupied, False otherwise
    """
    import socket
    
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(2)
            result = sock.connect_ex(('localhost', port))
            return result == 0
    except Exception:
        return False


def compute_absolute_path(script_path: str) -> str:
    """
    Compute the absolute path of a script.
    
    Args:
        script_path: Path to the script
        
    Returns:
        str: Absolute path
    """
    path = Path(script_path).parent
    return str(path.resolve())


def download_file(url: str, output_path: Optional[str] = None, silent: bool = True) -> bool:
    """
    Download a file from the internet.
    
    Args:
        url: URL to download from
        output_path: Path to save the file (optional)
        silent: Whether to suppress output
        
    Returns:
        bool: True if successful, False otherwise
    """
    try:
        import urllib.request
        
        if output_path:
            urllib.request.urlretrieve(url, output_path)
            if not silent:
                print(f"Downloaded {url} to {output_path}")
        else:
            response = urllib.request.urlopen(url)
            content = response.read()
            if not silent:
                # Try to decode as text, fall back to showing size for binary files
                try:
                    decoded_content = content.decode('utf-8')
                    print(decoded_content)
                except UnicodeDecodeError:
                    print(f"Downloaded binary content ({len(content)} bytes)")
        return True
    except Exception as e:
        if not silent:
            print(f"Error downloading {url}: {e}", file=sys.stderr)
        return False
