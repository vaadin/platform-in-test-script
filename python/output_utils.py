#!/usr/bin/env python3
"""
Output utilities for logging, coloring, and reporting.
"""

import sys
import os
import time
from typing import Optional
from pathlib import Path


class OutputFormatter:
    """Handles colored output formatting."""
    
    # ANSI color codes
    RESET = '\033[0m'
    BOLD = '\033[1m'
    
    # Colors
    BLACK = '\033[30m'
    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    BLUE = '\033[34m'
    MAGENTA = '\033[35m'
    CYAN = '\033[36m'
    WHITE = '\033[37m'
    
    # Background colors
    BG_BLACK = '\033[40m'
    BG_RED = '\033[41m'
    BG_GREEN = '\033[42m'
    BG_YELLOW = '\033[43m'
    BG_BLUE = '\033[44m'
    BG_MAGENTA = '\033[45m'
    BG_CYAN = '\033[46m'
    BG_WHITE = '\033[47m'


# Global start time for computing elapsed time
START_TIME = time.time()


def print_colored(prefix: str, color: str, text: str, newline: bool = True):
    """Print colored text to stderr."""
    output = f"{OutputFormatter.RESET}{prefix}{color}{text}{OutputFormatter.RESET}"
    if newline:
        output += "\n"
    print(output, file=sys.stderr, end="" if not newline else "\n")


def compute_time(start_time: Optional[float] = None) -> str:
    """
    Compute elapsed time in MM:SS format.
    
    Args:
        start_time: Start time in seconds since epoch (uses global START_TIME if None)
        
    Returns:
        str: Formatted time string
    """
    if start_time is None:
        start_time = START_TIME
    
    elapsed = int(time.time() - start_time)
    minutes = elapsed // 60
    seconds = elapsed % 60
    return f"{minutes:02d}:{seconds:02d}"


def log(message: str, newline: bool = False):
    """Log a message with timestamp."""
    test_mode = os.environ.get('TEST', '').strip()
    
    if newline:
        print("", file=sys.stderr)
        return
    
    if test_mode:
        cmd(f"## {message}")
        return
    
    timestamp = compute_time()
    print_colored('> ', OutputFormatter.GREEN, message, newline=False)
    print_colored('', f"{OutputFormatter.CYAN}", f" - {timestamp}", newline=True)


def bold(message: str, newline: bool = False):
    """Log a bold message with timestamp."""
    test_mode = os.environ.get('TEST', '').strip()
    
    if newline:
        print("", file=sys.stderr)
        return
    
    if test_mode:
        cmd(f"## {message}")
        return
    
    timestamp = compute_time()
    print_colored('> ', f"{OutputFormatter.BOLD}{OutputFormatter.GREEN}", message, newline=False)
    print_colored('', f"{OutputFormatter.CYAN}", f" - {timestamp}", newline=True)


def err(message: str):
    """Print an error message."""
    print_colored('> ', OutputFormatter.RED, message)


def warn(message: str, newline: bool = False):
    """Print a warning message."""
    if newline:
        print("", file=sys.stderr)
        return
    
    print_colored('> ', OutputFormatter.YELLOW, message)


def cmd(message: str, newline: bool = False):
    """Print a command that would be executed."""
    if newline:
        print("", file=sys.stderr)
        return
    
    # Format command by removing extra spaces and handling newlines
    formatted_cmd = ' '.join(message.split())
    formatted_cmd = formatted_cmd.replace('\\n', '\\\n')
    
    print_colored('  ', f"{OutputFormatter.BOLD}{OutputFormatter.BLUE}", f" {formatted_cmd}")


def dim(message: str):
    """Print a dimmed message."""
    print_colored('', OutputFormatter.CYAN, message)


def report_error(header: str, body: str):
    """
    Report an error to GitHub Actions step summary.
    
    Args:
        header: Error header
        body: Error body content
    """
    if not header or not body:
        return
    
    warn(f"reporting error: {header}")
    
    github_step_summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if not github_step_summary:
        return
    
    # Truncate body to reasonable size
    truncated_body = body[:300] if len(body) > 300 else body
    lines = truncated_body.split('\n')
    if len(lines) > 100:
        truncated_body = '\n'.join(lines[:100])
    
    try:
        with open(github_step_summary, 'a', encoding='utf-8') as f:
            f.write(f"""<details>
<summary><h4>{header}</h4></summary>
<pre>
{truncated_body}
</pre>
</details>
""")
    except Exception as e:
        warn(f"Failed to write to GitHub step summary: {e}")


def report_out_errors(file_path: str, header: str):
    """
    Report file content errors to GitHub Actions step summary.
    
    Args:
        file_path: Path to the file containing errors
        header: Header for the error report
    """
    if not Path(file_path).exists():
        return
    
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        # Filter out common noise
        lines = content.split('\n')
        filtered_lines = [
            line for line in lines 
            if ' *at ' not in line and 'org.atmosphere.cpr.AtmosphereFramework' not in line
        ]
        
        # Take last 300 lines
        if len(filtered_lines) > 300:
            filtered_lines = filtered_lines[-300:]
        
        filtered_content = '\n'.join(filtered_lines)
        report_error(header, filtered_content)
    except Exception as e:
        warn(f"Failed to read error file {file_path}: {e}")


def ask(question: str) -> str:
    """
    Ask user a question and return their response.
    
    Args:
        question: Question to ask the user
        
    Returns:
        str: User's response
    """
    # Flush stdin (not directly possible in Python, but we can work around it)
    try:
        import select
        import sys
        
        if sys.stdin in select.select([sys.stdin], [], [], 0)[0]:
            sys.stdin.read()
    except (ImportError, OSError):
        # select not available on Windows
        pass
    
    print_colored('', OutputFormatter.GREEN, f"{question}...", newline=False)
    try:
        return input()
    except (EOFError, KeyboardInterrupt):
        return ""


def play_bell():
    """Play a bell sound (console beep)."""
    while True:
        time.sleep(2)
        print("\a.", end="", flush=True)


def wait_for_user_with_bell(message: str = ""):
    """
    Alert user with a bell and wait for them to press enter.
    
    Args:
        message: Optional message to display
    """
    import threading
    
    # Start bell in background
    bell_thread = threading.Thread(target=play_bell, daemon=True)
    bell_thread.start()
    
    if message:
        log(message)
    
    ask("Push ENTER to stop the bell and continue")


def wait_for_user_manual_testing(port: int):
    """
    Inform user that app is running and wait for them to test it.
    
    Args:
        port: Port number the app is running on
    """
    log(f"App is running in http://localhost:{port}, open it in your browser")
    ask("When you finish, push ENTER to continue")


def print_time(start_time: Optional[float] = None):
    """
    Print elapsed time.
    
    Args:
        start_time: Start time in seconds since epoch (uses global START_TIME if None)
    """
    elapsed = compute_time(start_time)
    print("")
    log(f"Elapsed Time: {elapsed}")


def print_versions(maven_command: str, maven_opts: str = "", maven_args: str = ""):
    """
    Print versions of various tools.
    
    Args:
        maven_command: Maven command to use
        maven_opts: Maven options
        maven_args: Maven arguments
    """
    import subprocess
    try:
        from .java_utils import compute_npm
    except ImportError:
        # Fallback if java_utils is not available
        def compute_npm():
            return "node", "npm"
    
    test_mode = os.environ.get('TEST', '').strip()
    if test_mode:
        return
    
    try:
        # Get Maven version
        env = os.environ.copy()
        env['MAVEN_OPTS'] = f"{maven_opts} {env.get('MAVEN_OPTS', '')}"
        
        result = subprocess.run(
            [maven_command, '-version'],
            capture_output=True,
            text=True,
            env=env
        )
        
        if result.returncode != 0:
            err(f"Error {result.returncode} when running {maven_command}")
            return
        
        maven_version = result.stdout.replace('\\', '/')
        
        # Get Java version
        java_result = subprocess.run(['java', '-version'], capture_output=True, text=True)
        java_version = java_result.stderr
        
        # Get Node and NPM info
        node_path, npm_command = compute_npm()
        
        node_result = subprocess.run([node_path, '--version'], capture_output=True, text=True)
        node_version = node_result.stdout.strip()
        
        npm_result = subprocess.run(npm_command.split() + ['--version'], capture_output=True, text=True)
        npm_version = npm_result.stdout.strip()
        
        log(f"""==== VERSIONS ====

MAVEN_OPTS='{maven_opts} {env.get('MAVEN_OPTS', '')}' MAVEN_ARGS='{maven_args}' {maven_command} -version
{maven_version}
NODE={node_path}
Java version: {java_version}
Node version: {node_version}
NPM={npm_command}
Npm version: {npm_version}
""")
    except Exception as e:
        err(f"Error getting versions: {e}")
