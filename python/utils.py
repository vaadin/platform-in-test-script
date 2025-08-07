#!/usr/bin/env python3
"""
General utilities for Platform Integration Test (PiT).
Migrated from scripts/pit/lib/lib-utils.sh.
Provides system utilities, logging, process management, and file operations.
"""

import os
import sys
import time
import signal
import subprocess
import platform
import shutil
from pathlib import Path
from typing import Optional, List, Dict, Any, Callable
import logging
import json
import re

logger = logging.getLogger(__name__)

class PitLogger:
    """Enhanced logging with color support and PiT-specific formatting."""
    
    def __init__(self, test_mode: bool = False):
        self.test_mode = test_mode
        self.start_time = time.time()
        self.exit_commands = []
        
    def compute_time(self) -> str:
        """Compute elapsed time since start."""
        elapsed = time.time() - self.start_time
        return f"{elapsed:.2f}s"
    
    def log(self, message: str, newline: bool = True) -> None:
        """Log message with timestamp."""
        if self.test_mode:
            self.cmd(f"## {message}")
            return
        
        timestamp = self.compute_time()
        if newline:
            print(f"\033[0;32m> {message}\033[0m \033[2;36m- {timestamp}\033[0m", file=sys.stderr)
        else:
            print(f"\033[0;32m> {message}\033[0m \033[2;36m- {timestamp}\033[0m", file=sys.stderr, end="")
    
    def bold(self, message: str, newline: bool = True) -> None:
        """Log bold message with timestamp."""
        if self.test_mode:
            self.cmd(f"## {message}")
            return
        
        timestamp = self.compute_time()
        if newline:
            print(f"\033[1;32m> {message}\033[0m \033[2;36m- {timestamp}\033[0m", file=sys.stderr)
        else:
            print(f"\033[1;32m> {message}\033[0m \033[2;36m- {timestamp}\033[0m", file=sys.stderr, end="")
    
    def error(self, message: str) -> None:
        """Log error message."""
        print(f"\033[0;31m> {message}\033[0m", file=sys.stderr)
    
    def warn(self, message: str, newline: bool = True) -> None:
        """Log warning message."""
        if newline:
            print(f"\033[0;33m> {message}\033[0m", file=sys.stderr)
        else:
            print(f"\033[0;33m> {message}\033[0m", file=sys.stderr, end="")
    
    def cmd(self, message: str, newline: bool = True) -> None:
        """Log command message."""
        # Clean up the command for display
        clean_cmd = re.sub(r'\s+', ' ', message.replace('\n', '\\n'))
        if newline:
            print(f"\033[1;34m  {clean_cmd}\033[0m", file=sys.stderr)
        else:
            print(f"\033[1;34m  {clean_cmd}\033[0m", file=sys.stderr, end="")
    
    def dim(self, message: str) -> None:
        """Log dim message."""
        print(f"\033[0;36m{message}\033[0m", file=sys.stderr)
    
    def on_exit(self, command: str) -> None:
        """Register command to run on exit."""
        self.exit_commands.append(command)
    
    def do_exit(self) -> None:
        """Execute exit commands and exit."""
        print("►", end="", file=sys.stderr)
        for cmd in self.exit_commands:
            try:
                subprocess.run(cmd, shell=True, check=False)
            except Exception as e:
                self.warn(f"Error executing exit command: {e}")
        sys.exit(0)

class ProcessManager:
    """Manages background processes and cleanup."""
    
    def __init__(self):
        self.background_pids = []
        self.tail_pid = None
        self.bell_pid = None
    
    def get_pids(self, pattern: str) -> List[int]:
        """Get process IDs matching a pattern."""
        try:
            pids = []
            if platform.system() == 'Windows':
                # Use tasklist on Windows
                result = subprocess.run(
                    ['tasklist', '/fo', 'csv'],
                    capture_output=True, text=True, timeout=30
                )
                if result.returncode == 0:
                    for line in result.stdout.split('\n')[1:]:  # Skip header
                        if pattern in line:
                            parts = line.split(',')
                            if len(parts) >= 2:
                                try:
                                    pid = int(parts[1].strip('"'))
                                    pids.append(pid)
                                except ValueError:
                                    continue
            else:
                # Use ps on Unix-like systems
                result = subprocess.run(
                    ['ps', 'aux'],
                    capture_output=True, text=True, timeout=30
                )
                if result.returncode == 0:
                    for line in result.stdout.split('\n')[1:]:  # Skip header
                        if pattern in line:
                            parts = line.split()
                            if len(parts) >= 2:
                                try:
                                    pid = int(parts[1])
                                    pids.append(pid)
                                except ValueError:
                                    continue
            return pids
        except Exception as e:
            logger.error(f"Error getting PIDs for pattern '{pattern}': {e}")
            return []
    
    def kill_process(self, pid: int, force: bool = False) -> bool:
        """Kill a process."""
        try:
            if platform.system() == 'Windows':
                # Use taskkill on Windows
                cmd = ['taskkill', '/PID', str(pid)]
                if force:
                    cmd.append('/F')
                result = subprocess.run(cmd, timeout=10)
                return result.returncode == 0
            else:
                # Use kill on Unix-like systems
                import signal
                sig = signal.SIGKILL if force else signal.SIGTERM
                os.kill(pid, sig)
                return True
        except (OSError, subprocess.TimeoutExpired) as e:
            if "No such process" in str(e):
                return True  # Already dead
            logger.error(f"Error killing process {pid}: {e}")
            return False
        except Exception as e:
            logger.error(f"Error killing process {pid}: {e}")
            return False
    
    def kill_processes(self, pids: List[int]) -> None:
        """Kill multiple processes."""
        for pid in pids:
            self.kill_process(pid)
    
    def cleanup(self) -> None:
        """Kill all tracked background processes."""
        all_pids = self.background_pids.copy()
        if self.tail_pid:
            all_pids.append(self.tail_pid)
        if self.bell_pid:
            all_pids.append(self.bell_pid)
        
        self.kill_processes(all_pids)
        
        # Clear tracking
        self.background_pids.clear()
        self.tail_pid = None
        self.bell_pid = None

class ProKeyManager:
    """Manages Vaadin Pro key for testing."""
    
    def __init__(self):
        self.vaadin_dir = Path.home() / '.vaadin'
        self.pro_key_path = self.vaadin_dir / 'proKey'
        self.backup_suffix = None
    
    def remove_pro_key(self) -> bool:
        """Remove pro key for core-only testing."""
        try:
            if self.pro_key_path.exists():
                # Create unique backup suffix
                self.backup_suffix = str(os.getpid())
                backup_path = Path(f"{self.pro_key_path}-{self.backup_suffix}")
                
                self.pro_key_path.rename(backup_path)
                logger.info("Removed proKey license for testing")
                return True
            return False
        except Exception as e:
            logger.error(f"Error removing pro key: {e}")
            return False
    
    def restore_pro_key(self) -> bool:
        """Restore previously removed pro key."""
        try:
            if not self.backup_suffix:
                return False
            
            backup_path = Path(f"{self.pro_key_path}-{self.backup_suffix}")
            if not backup_path.exists():
                return False
            
            # Check if a new key was generated during testing
            new_key_content = None
            if self.pro_key_path.exists():
                with open(self.pro_key_path, 'r') as f:
                    new_key_content = f.read().strip()
            
            # Restore original key
            backup_path.rename(self.pro_key_path)
            logger.info("Restored proKey license")
            
            # Report if new key was generated
            if new_key_content:
                logger.error(f"A proKey was generated during validation: {new_key_content}")
                return False
            
            return True
            
        except Exception as e:
            logger.error(f"Error restoring pro key: {e}")
            return False

class PlatformUtils:
    """Platform-specific utility functions."""
    
    @staticmethod
    def is_linux() -> bool:
        """Check if running on Linux."""
        return platform.system() == 'Linux'
    
    @staticmethod
    def is_mac() -> bool:
        """Check if running on macOS."""
        return platform.system() == 'Darwin'
    
    @staticmethod
    def is_windows() -> bool:
        """Check if running on Windows."""
        return platform.system() == 'Windows'
    
    @staticmethod
    def get_platform() -> str:
        """Get platform name for file naming."""
        return platform.system()

class CommandRunner:
    """Enhanced command runner with logging and file output."""
    
    def __init__(self, logger: PitLogger, test_mode: bool = False):
        self.logger = logger
        self.test_mode = test_mode
    
    def check_commands(self, *commands: str) -> bool:
        """Check if commands are installed."""
        try:
            for cmd in commands:
                if not shutil.which(cmd):
                    self.logger.error(f"Command '{cmd}' is not installed")
                    return False
            return True
        except Exception as e:
            self.logger.error(f"Error checking commands: {e}")
            return False
    
    def run_command(self, message: str, command: str, 
                   force: bool = False, quiet: bool = False) -> bool:
        """
        Run a command with logging.
        
        Args:
            message: Description of what the command does
            command: Command to run
            force: Force execution even in test mode
            quiet: Suppress output on error
            
        Returns:
            True if command succeeded, False otherwise
        """
        try:
            if not self.test_mode:
                self.logger.log(message)
            else:
                self.logger.cmd(f"## {message}")
            
            self.logger.cmd(command)
            
            if self.test_mode and not force:
                return True
            
            # Handle background commands
            if command.strip().endswith('&'):
                return self._run_background_command(command[:-1].strip())
            
            # Run regular command
            result = subprocess.run(
                command, shell=True, capture_output=True, text=True,
                timeout=300
            )
            
            if result.returncode == 0:
                return True
            else:
                if not quiet:
                    self.logger.error(f"Command failed: {result.stderr}")
                return False
                
        except subprocess.TimeoutExpired:
            self.logger.error(f"Command timed out: {command}")
            return False
        except Exception as e:
            self.logger.error(f"Error running command: {e}")
            return False
    
    def _run_background_command(self, command: str) -> bool:
        """Run command in background."""
        try:
            process = subprocess.Popen(
                command, shell=True, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE, preexec_fn=os.setsid if os.name != 'nt' else None
            )
            
            # Wait a bit to check if process started successfully
            time.sleep(2)
            if process.poll() is not None:
                return False
            
            return True
            
        except Exception as e:
            self.logger.error(f"Error running background command: {e}")
            return False
    
    def run_to_file(self, command: str, output_file: str, verbose: bool = False,
                   stdout_only: bool = False) -> bool:
        """Run command and send output to file."""
        try:
            if not self.test_mode:
                self.logger.log(f"Running and sending output to > {output_file}")
            
            # Add Maven args if applicable
            if 'mvn' in command and os.environ.get('MAVEN_ARGS'):
                command = f"{command} {os.environ['MAVEN_ARGS']}"
            
            self.logger.cmd(command)
            
            if self.test_mode:
                return True
            
            with open(output_file, 'a', encoding='utf-8') as f:
                if verbose:
                    # Tee-like behavior
                    process = subprocess.Popen(
                        command, shell=True, stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT if not stdout_only else subprocess.PIPE,
                        text=True
                    )
                    
                    for line in process.stdout:
                        print(line, end='')
                        f.write(line)
                    
                    process.wait()
                    result_code = process.returncode
                else:
                    # Direct to file
                    if stdout_only:
                        result = subprocess.run(
                            command, shell=True, stdout=f, text=True, timeout=600
                        )
                    else:
                        result = subprocess.run(
                            command, shell=True, stdout=f, stderr=subprocess.STDOUT,
                            text=True, timeout=600
                        )
                    result_code = result.returncode
            
            if result_code != 0:
                self._report_output_errors(output_file, f"Error ({result_code}) running {command}")
                return False
            
            return True
            
        except Exception as e:
            self.logger.error(f"Error running command to file: {e}")
            return False
    
    def run_in_background_to_file(self, command: str, output_file: str, 
                                verbose: bool = False) -> Optional[subprocess.Popen]:
        """Run command in background, sending output to file."""
        try:
            if not self.test_mode:
                self.logger.log(f"Running in background and sending output to > {output_file}")
            
            # Add Maven args if applicable
            if 'mvn' in command and os.environ.get('MAVEN_ARGS'):
                command = f"{command} {os.environ['MAVEN_ARGS']}"
            
            self.logger.cmd(command)
            
            if self.test_mode:
                return None
            
            # Create/touch output file
            Path(output_file).touch()
            
            # Start tail process if verbose
            if verbose:
                self._start_tail_process(output_file)
            
            # Start main process
            with open(output_file, 'a', encoding='utf-8') as f:
                process = subprocess.Popen(
                    command, shell=True, stdout=f, stderr=subprocess.STDOUT,
                    preexec_fn=os.setsid if os.name != 'nt' else None
                )
            
            # Check if process started successfully
            time.sleep(2)
            if process.poll() is not None:
                return None
            
            return process
            
        except Exception as e:
            self.logger.error(f"Error running background command: {e}")
            return None
    
    def _start_tail_process(self, output_file: str) -> Optional[subprocess.Popen]:
        """Start tail process for verbose output."""
        try:
            if PlatformUtils.is_windows():
                # Use PowerShell Get-Content for tailing on Windows
                tail_cmd = f'powershell -Command "Get-Content -Path \'{output_file}\' -Wait"'
            else:
                # Use tail on Unix-like systems
                tail_cmd = f'tail -f "{output_file}"'
            
            tail_process = subprocess.Popen(
                tail_cmd, shell=True, stdout=sys.stdout, stderr=sys.stderr
            )
            
            return tail_process
            
        except Exception as e:
            self.logger.warn(f"Error starting tail process: {e}")
            return None
    
    def _report_output_errors(self, output_file: str, header: str) -> None:
        """Report errors from output file."""
        try:
            if not Path(output_file).exists():
                return
            
            with open(output_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            # Filter out noise and get last 300 lines
            filtered_lines = []
            for line in lines:
                if not re.search(r'\s*at |org\.atmosphere\.cpr\.AtmosphereFramework', line):
                    filtered_lines.append(line.rstrip())
            
            # Take last 300 lines and limit to 60KB
            error_lines = filtered_lines[-300:]
            error_content = '\n'.join(error_lines)
            
            # Truncate if too long
            if len(error_content) > 60000:
                error_content = error_content[-60000:]
                error_content = "...[truncated]...\n" + error_content
            
            self._report_error(header, error_content)
            
        except Exception as e:
            self.logger.warn(f"Error reporting output errors: {e}")
    
    def _report_error(self, header: str, content: str) -> None:
        """Report error to GitHub Actions step summary if available."""
        try:
            if not header or not content:
                return
            
            self.logger.warn(f"Reporting error: {header}")
            
            # Check for GitHub Actions environment
            step_summary = os.environ.get('GITHUB_STEP_SUMMARY')
            if not step_summary:
                return
            
            # Truncate content for display
            display_content = content[:300] if len(content) > 300 else content
            
            # Append to step summary
            with open(step_summary, 'a', encoding='utf-8') as f:
                f.write(f"""
<details>
<summary><h4>{header}</h4></summary>
<pre>
{display_content}
</pre>
</details>
""")
                
        except Exception as e:
            self.logger.warn(f"Error reporting to GitHub Actions: {e}")

class MavenGradleUtils:
    """Utilities for Maven and Gradle projects."""
    
    @staticmethod
    def compute_mvn() -> str:
        """Compute the Maven command to use."""
        if Path('./mvnw').is_file():
            return './mvnw'
        elif PlatformUtils.is_windows():
            if Path('./mvnw.bat').is_file():
                return './mvnw.bat'
            elif Path('./mvnw.cmd').is_file():
                return './mvnw.cmd'
        return 'mvn'
    
    @staticmethod
    def compute_gradle() -> str:
        """Compute the Gradle command to use."""
        gradle_cmd = 'gradle'
        
        if Path('./gradlew').is_file():
            gradle_cmd = './gradlew'
        elif PlatformUtils.is_windows():
            if Path('./gradlew.bat').is_file():
                gradle_cmd = './gradlew.bat'
            elif Path('./gradlew.cmd').is_file():
                gradle_cmd = './gradlew.cmd'
        
        # Add Java installation auto-detect flag
        return f"{gradle_cmd} -Porg.gradle.java.installations.auto-detect=false"

class NodeNpmUtils:
    """Utilities for Node.js and npm operations."""
    
    @staticmethod
    def compute_npm() -> Dict[str, str]:
        """Compute npm and node commands, preferring Vaadin installations."""
        vaadin_node = Path.home() / '.vaadin' / 'node'
        npm_js = vaadin_node / 'lib' / 'node_modules' / 'npm' / 'bin' / 'npm-cli.js'
        
        result = {
            'npm': shutil.which('npm') or 'npm',
            'npx': shutil.which('npx') or 'npx', 
            'node': shutil.which('node') or 'node'
        }
        
        # Prefer Vaadin node installation if available
        vaadin_node_bin = vaadin_node / 'bin' / 'node'
        if vaadin_node_bin.exists() and npm_js.exists():
            # Update PATH to include Vaadin node
            vaadin_bin = str(vaadin_node / 'bin')
            current_path = os.environ.get('PATH', '')
            os.environ['PATH'] = f"{vaadin_bin}{os.pathsep}{current_path}"
            
            result.update({
                'node': str(vaadin_node_bin),
                'npm': f"'{result['node']}' '{npm_js}'"
            })
        
        return result

class FileUtils:
    """File and directory utilities."""
    
    @staticmethod
    def ask_user(question: str) -> str:
        """Ask user a question and return response."""
        try:
            # Flush stdin
            import sys
            if hasattr(sys.stdin, 'flush'):
                sys.stdin.flush()
            
            print(f"\033[0;32m{question}\033[0m...", end="", file=sys.stderr)
            response = input()
            return response.strip()
            
        except KeyboardInterrupt:
            print("\nUser cancelled", file=sys.stderr)
            return ""
        except Exception as e:
            logger.error(f"Error asking user: {e}")
            return ""
    
    @staticmethod
    def compute_absolute_path(script_path: str) -> str:
        """Compute absolute path of the executed script."""
        try:
            path = Path(script_path).parent.resolve()
            return str(path)
        except Exception as e:
            logger.error(f"Error computing absolute path: {e}")
            return str(Path.cwd())

# Global utilities instance
pit_logger = PitLogger()
process_manager = ProcessManager()
pro_key_manager = ProKeyManager()
command_runner = CommandRunner(pit_logger)

def cleanup_all() -> None:
    """Clean up all resources."""
    pro_key_manager.restore_pro_key()
    process_manager.cleanup()

def setup_signal_handlers() -> None:
    """Set up signal handlers for cleanup."""
    def signal_handler(signum, frame):
        pit_logger.warn("Received interrupt signal, cleaning up...")
        cleanup_all()
        pit_logger.do_exit()
    
    # Set up signal handlers (Unix-like systems)
    if os.name != 'nt':
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)

if __name__ == '__main__':
    # Example usage
    setup_signal_handlers()
    
    # Test logging
    pit_logger.log("Starting PiT utilities test")
    pit_logger.bold("Bold message")
    pit_logger.warn("Warning message")
    pit_logger.error("Error message")
    pit_logger.cmd("echo 'test command'")
    pit_logger.dim("Dim message")
    
    # Test platform detection
    print(f"Platform: {PlatformUtils.get_platform()}")
    print(f"Is Linux: {PlatformUtils.is_linux()}")
    print(f"Is Mac: {PlatformUtils.is_mac()}")
    print(f"Is Windows: {PlatformUtils.is_windows()}")
    
    # Test Maven/Gradle detection
    print(f"Maven command: {MavenGradleUtils.compute_mvn()}")
    print(f"Gradle command: {MavenGradleUtils.compute_gradle()}")
    
    # Test npm detection
    npm_info = NodeNpmUtils.compute_npm()
    print(f"npm info: {npm_info}")
    
    cleanup_all()
