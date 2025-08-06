#!/usr/bin/env python3
"""
Process management utilities for running commands, background processes, and output handling.
"""

import subprocess
import threading
import time
import os
import signal
import sys
from typing import Optional, List, Dict, Any, IO, Union
from pathlib import Path
from .system_utils import is_windows
from .output_utils import log, cmd, err, warn


class ProcessManager:
    """Manages background processes and their cleanup."""
    
    def __init__(self):
        self.background_processes: Dict[str, subprocess.Popen] = {}
        self.exit_commands: List[str] = []
    
    def add_exit_command(self, command: str):
        """Add a command to be executed on exit."""
        self.exit_commands.append(command)
    
    def cleanup(self):
        """Clean up all background processes and run exit commands."""
        # Kill background processes
        for name, process in self.background_processes.items():
            try:
                if process.poll() is None:  # Process is still running
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
            except Exception:
                pass
        
        self.background_processes.clear()
        
        # Run exit commands
        for command in self.exit_commands:
            try:
                subprocess.run(command, shell=True, capture_output=True)
            except Exception:
                pass
        
        self.exit_commands.clear()


# Global process manager instance
process_manager = ProcessManager()


def run_command(
    message: str,
    command: str,
    quiet: bool = False,
    force: bool = False,
    test_mode: bool = False,
    verbose: bool = False
) -> int:
    """
    Run a command with logging and error handling.
    
    Args:
        message: Message describing what the command does
        command: Command to execute
        quiet: If True, suppress output on error
        force: If True, run even in test mode
        test_mode: If True, only show what would be run
        verbose: If True, show command output in real-time
        
    Returns:
        int: Return code of the command
    """
    if not test_mode:
        log(message)
    else:
        cmd(f"## {message}")
    
    cmd(command)
    
    if test_mode and not force:
        return 0
    
    try:
        if '&' in command and command.strip().endswith('&'):
            # Background process
            command = command.rstrip('&').strip()
            process = subprocess.Popen(
                command,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True
            )
            time.sleep(2)
            if process.poll() is None:
                process_manager.background_processes[f"bg_{len(process_manager.background_processes)}"] = process
                return 0
            else:
                return process.returncode or 1
        else:
            # Foreground process
            if verbose:
                process = subprocess.Popen(
                    command,
                    shell=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                    universal_newlines=True
                )
                
                for line in process.stdout:
                    print(line, end='')
                
                return_code = process.wait()
            else:
                result = subprocess.run(
                    command,
                    shell=True,
                    capture_output=True,
                    text=True
                )
                return_code = result.returncode
                
                if return_code != 0 and not quiet:
                    print(result.stdout, file=sys.stderr)
                    print(result.stderr, file=sys.stderr)
            
            return return_code
    except KeyboardInterrupt:
        err("Command interrupted by user")
        return 130
    except Exception as e:
        err(f"Error running command: {e}")
        return 1


def run_to_file(
    command: str,
    output_file: str,
    verbose: bool = False,
    stdout_only: bool = False,
    test_mode: bool = False
) -> int:
    """
    Run a command and send output to a file.
    
    Args:
        command: Command to execute
        output_file: File to write output to
        verbose: If True, also print output to console
        stdout_only: If True, only capture stdout (not stderr)
        test_mode: If True, only show what would be run
        
    Returns:
        int: Return code of the command
    """
    if not test_mode:
        log(f"Running and sending output to > {output_file}")
    
    cmd(command)
    
    if test_mode:
        return 0
    
    try:
        output_path = Path(output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        if verbose:
            # Use tee-like functionality
            process = subprocess.Popen(
                command,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT if not stdout_only else subprocess.PIPE,
                text=True,
                bufsize=1,
                universal_newlines=True
            )
            
            with open(output_file, 'a', encoding='utf-8') as f:
                for line in process.stdout:
                    print(line, end='')
                    f.write(line)
                    f.flush()
            
            return_code = process.wait()
        else:
            # Direct to file
            with open(output_file, 'a', encoding='utf-8') as f:
                if stdout_only:
                    result = subprocess.run(
                        command,
                        shell=True,
                        stdout=f,
                        stderr=subprocess.PIPE,
                        text=True
                    )
                else:
                    result = subprocess.run(
                        command,
                        shell=True,
                        stdout=f,
                        stderr=subprocess.STDOUT,
                        text=True
                    )
            
            return_code = result.returncode
        
        if return_code != 0:
            from .output_utils import report_out_errors
            report_out_errors(output_file, f"Error ({return_code}) running {command}")
        
        return return_code
    except Exception as e:
        err(f"Error running command to file: {e}")
        return 1


def run_in_background_to_file(
    command: str,
    output_file: str,
    verbose: bool = False,
    test_mode: bool = False
) -> Optional[subprocess.Popen]:
    """
    Run a command in background and send output to a file.
    
    Args:
        command: Command to execute
        output_file: File to write output to
        verbose: If True, also tail the output file
        test_mode: If True, only show what would be run
        
    Returns:
        subprocess.Popen: The background process, or None if failed
    """
    if not test_mode:
        log(f"Running in background and sending output to > {output_file}")
    
    cmd(command)
    
    if test_mode:
        return None
    
    try:
        output_path = Path(output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.touch()  # Create file if it doesn't exist
        
        # Start the main process
        with open(output_file, 'a', encoding='utf-8') as f:
            process = subprocess.Popen(
                command,
                shell=True,
                stdout=f,
                stderr=subprocess.STDOUT,
                text=True
            )
        
        # Start tail process if verbose
        if verbose:
            def tail_file():
                try:
                    subprocess.run(['tail', '-f', output_file])
                except Exception:
                    pass
            
            tail_thread = threading.Thread(target=tail_file, daemon=True)
            tail_thread.start()
        
        time.sleep(2)
        
        # Check if process is still running
        if process.poll() is None:
            process_manager.background_processes[f"bg_{len(process_manager.background_processes)}"] = process
            return process
        else:
            return None
    except Exception as e:
        err(f"Error running background command: {e}")
        return None


def wait_until_message_in_file(
    file_path: str,
    message: str,
    timeout: int,
    command_desc: str = "",
    test_mode: bool = False
) -> int:
    """
    Wait until a specific message appears in a log file.
    
    Args:
        file_path: Path to the file to monitor
        message: Message or regex pattern to wait for
        timeout: Timeout in seconds
        command_desc: Description of the command being monitored
        test_mode: If True, only show what would be done
        
    Returns:
        int: 0 on success, 1 on error, 2 on special condition
    """
    import re
    
    if test_mode:
        cmd(f"## Wait for: '{message}'")
        return 0
    
    log(f"Waiting for server to start, timeout={timeout} secs, message='{message}'")
    
    sleep_interval = 4
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        # Check if background process is still running
        active_processes = [p for p in process_manager.background_processes.values() 
                          if p.poll() is None]
        
        if not active_processes:
            from .maven_utils import check_tsconfig_modified
            if check_tsconfig_modified(file_path):
                return 2
            from .output_utils import report_out_errors
            report_out_errors(file_path, f"Error {command_desc} failed to start")
            return 1
        
        # Check for message in file
        try:
            if Path(file_path).exists():
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    if re.search(message, content):
                        elapsed = int(time.time() - start_time)
                        log(f"Found '{message}' in {file_path} after {elapsed} secs")
                        
                        # Append to file
                        with open(file_path, 'a', encoding='utf-8') as af:
                            af.write(f"\n>>>> PiT: Found '{message}' after {elapsed} secs\n")
                        
                        time.sleep(sleep_interval)
                        return 0
        except Exception:
            pass
        
        time.sleep(sleep_interval)
    
    from .output_utils import report_out_errors
    report_out_errors(file_path, f"Timeout: could not find '{message}' in {file_path} after {timeout} secs")
    return 1


def wait_until_port(port: int, timeout: int, log_file: str = "") -> bool:
    """
    Wait until a port is listening.
    
    Args:
        port: Port number to check
        timeout: Timeout in seconds
        log_file: Optional log file to write to
        
    Returns:
        bool: True if port becomes available, False on timeout
    """
    from .system_utils import check_port
    
    log(f"Waiting for port {port} to be available")
    
    for i in range(timeout):
        if check_port(port):
            if log_file:
                with open(log_file, 'a', encoding='utf-8') as f:
                    f.write(f">>>> PiT: Checked that port {port} is listening\n")
            return True
        time.sleep(1)
    
    err(f"Server not listening in port {port} after {timeout} secs")
    return False


def check_http_servlet(url: str, output_file: str = "", verbose: bool = False) -> bool:
    """
    Check that an HTTP servlet responds with 200.
    
    Args:
        url: URL to check
        output_file: Optional output file for logging
        verbose: Whether to show verbose output
        
    Returns:
        bool: True if URL returns 200, False otherwise
    """
    import urllib.request
    import urllib.error
    
    log(f"Checking whether url {url} returns HTTP 200")
    
    try:
        headers = {'Accept': 'text/html'}
        request = urllib.request.Request(url, headers=headers)
        
        with urllib.request.urlopen(request) as response:
            return response.getcode() == 200
    except urllib.error.HTTPError as e:
        if output_file:
            from .output_utils import report_out_errors
            report_out_errors(output_file, "Server Logs")
        return False
    except Exception:
        return False


def wait_until_frontend_compiled(url: str, output_file: str) -> int:
    """
    Wait until Vaadin frontend compilation is complete in dev-mode.
    
    Args:
        url: URL to check
        output_file: Output file for logging
        
    Returns:
        int: 0 on success, 1 on error, 2 on config modification
    """
    import urllib.request
    import urllib.error
    
    log(f"Waiting for dev-mode to be ready at {url}")
    
    total_time = 0
    
    while True:
        try:
            headers = {'Accept': 'text/html'}
            request = urllib.request.Request(url, headers=headers)
            
            with urllib.request.urlopen(request) as response:
                dev_mode_pending = response.headers.get('X-DevModePending')
                
                if dev_mode_pending:
                    time.sleep(3)
                    total_time += 3
                else:
                    with open(output_file, 'a', encoding='utf-8') as f:
                        f.write(f">>>> PiT: Checked that frontend is compiled and dev-mode is ready after {total_time} secs\n")
                    log(f"Found a valid response after {total_time} secs")
                    return 0
                    
        except urllib.error.HTTPError:
            from .maven_utils import check_tsconfig_modified
            if check_tsconfig_modified(output_file):
                with open(output_file, 'a', encoding='utf-8') as f:
                    f.write(">>>> PiT: config file modified, retrying ....\n")
                from .output_utils import report_out_errors
                report_out_errors(output_file, "File tsconfig/types.d was modified and servlet threw an Exception")
                return 2
            else:
                with open(output_file, 'a', encoding='utf-8') as f:
                    f.write(">>>> PiT: Found Error when compiling frontend\n")
                from .output_utils import report_out_errors
                report_out_errors(output_file, "Error checking dev-mode")
                return 1
        except Exception:
            return 1
