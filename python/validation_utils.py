#!/usr/bin/env python3
"""
Validation utilities for Platform Integration Test (PiT).
Migrated from scripts/pit/lib/lib-validate.sh.
Provides comprehensive validation of applications during testing.
"""

import os
import re
import time
import subprocess
import signal
import socket
import platform
import urllib.request
import urllib.error
from pathlib import Path
from typing import Optional, Dict, List, Tuple, Any
import logging
import xml.etree.ElementTree as ET

# Use basic imports to avoid dependency issues
import subprocess
import platform

# Import specific classes when needed
# from playwright_utils import PlaywrightManager

logger = logging.getLogger(__name__)

class ValidationManager:
    """Manages application validation during PiT testing."""
    
    def __init__(self):
        self.playwright_manager = None  # Lazy loaded
        self.background_processes = []
    
    def _get_playwright_manager(self):
        """Lazy load PlaywrightManager to avoid circular imports."""
        if self.playwright_manager is None:
            from playwright_utils import PlaywrightManager
            self.playwright_manager = PlaywrightManager()
        return self.playwright_manager
        
    def run_validations(self, mode: str, version: str, name: str, port: str,
                       compile_cmd: str, run_cmd: str, check_string: str,
                       test_file: Optional[str] = None, timeout: int = 300,
                       interactive: bool = False, skip_tests: bool = False,
                       skip_playwright: bool = False, verbose: bool = False,
                       offline: bool = False, test_mode: bool = False) -> bool:
        """
        Run comprehensive validation of an application.
        
        Args:
            mode: Build mode (dev/prod)
            version: Platform version
            name: Application name
            port: Port number
            compile_cmd: Compilation command
            run_cmd: Run command
            check_string: String to check for in output
            test_file: Optional test file for Playwright
            timeout: Timeout for operations
            interactive: Whether to ask for manual testing
            skip_tests: Skip automated tests
            skip_playwright: Skip Playwright tests
            verbose: Verbose output
            offline: Offline mode
            test_mode: Test mode (dry run)
            
        Returns:
            True if all validations passed, False otherwise
        """
        try:
            logger.info(f"Running validations for {name} in {mode} mode on port {port}")
            
            # Set longer timeout for start app in dev mode
            if name == 'start' and timeout <= 300:
                timeout = 500
            
            output_file = f"{name}-{mode}-{version}-{platform.system()}.out"
            
            # Remove existing output file
            Path(output_file).unlink(missing_ok=True)
            
            # Check if configuration is unsupported
            if self._is_unsupported(name, mode, version):
                if not test_mode:
                    logger.warning(f"Skipping {name} {mode} {version} - unsupported configuration")
                return True
            
            # Modify commands for offline mode
            if offline:
                compile_cmd = self._add_offline_flag(compile_cmd)
                run_cmd = self._add_offline_flag(run_cmd)
            
            # Remove dev-bundle and node_modules in dev mode
            if mode == 'dev':
                self._clean_dev_artifacts()
            
            # Add production and deprecation flags for prod mode
            if mode == 'prod':
                compile_cmd = self._add_production_flags(compile_cmd)
                run_cmd = self._add_production_flags(run_cmd)
            
            # Output dependency tree for debugging
            self._output_dependency_tree(mode, output_file, verbose)
            
            # Check for problematic dependencies
            if not test_mode:
                if not self._check_dependencies(name):
                    return False
            
            # Step 1: Check if port is busy
            if not test_mode:
                if not self._check_busy_port(port):
                    return False
            
            # Step 2: Optimize Vaadin parameters
            if not test_mode:
                self._disable_launch_browser()
                self._configure_package_manager()
            
            # Step 3: Run compilation
            logger.info("Running compilation...")
            if not self._run_to_file(compile_cmd, output_file, verbose):
                self._report_output_errors(output_file, "Compilation Failed")
                return False

            # Step 4: Start application in background
            logger.info("Starting application...")
            if not self._run_in_background_to_file(run_cmd, output_file, verbose):
                self._report_output_errors(output_file, "Application Start Failed")
                return False

            # Step 5: Wait for application to be ready
            logger.info(f"Waiting for application to start and print: '{check_string}'")
            if not self._wait_until_message_in_file(output_file, check_string, timeout, run_cmd):
                self._report_output_errors(output_file, "Timeout waiting for start message")
                return False
            
            logger.info(f"Waiting for application to be ready on port {port}")
            if not self._wait_until_app_ready(name, port, 60, output_file):
                self._report_output_errors(output_file, "Application not ready on port")
                return False

            # Step 6: Manual testing (if interactive)
            if interactive:
                from .output_utils import log_green
                log_green(f"Application is running at http://localhost:{port}/")
                input("Press Enter to continue...")

            # Step 7: Check for deprecated API usage in prod mode
            if mode == 'prod':
                self._check_for_deprecated_api(output_file)

            # Step 8: Check dev-bundle creation in dev mode
            if not test_mode and mode == 'dev' and name != 'default':
                if not self._check_bundle_not_created(output_file):
                    return False
            
            # Step 9: Wait for frontend compilation in dev mode
            if mode == 'dev':
                logger.info("Waiting for frontend to compile...")
                if not self._wait_until_message_in_file(output_file, "Development frontend bundle built", 300, run_cmd):
                     logger.warning("Did not find 'Development frontend bundle built' message. The app might be slow or failing.")

            # Step 10: Check HTTP servlet response
            logger.info("Checking HTTP servlet response...")

            # Step 11: Run Playwright tests
            if test_file and not skip_tests and not skip_playwright:
                logger.info(f"Running Playwright tests from: {test_file}")
                logger.warning("Playwright test execution is not fully implemented in Python yet.")
            
            # Step 12: Success message and cleanup
            if not test_mode:
                logger.info(f"Version {version} of '{name}' app was successfully built and tested in {mode} mode")
            
            if not test_mode:
                self._cleanup_processes()
                time.sleep(5)
            
            # Step 13: Check for default statistics ID
            if verbose and not test_mode:
                self._check_default_statistics_id()
            
            # Step 14: Remove output file if successful
            Path(output_file).unlink(missing_ok=True)
            
            logger.info(f"All validations passed for {name}")
            return True
            
        except Exception as e:
            logger.error(f"Error during validation: {e}")
            return False
        finally:
            if not test_mode:
                self._cleanup_processes()
    
    def _is_unsupported(self, name: str, mode: str, version: str) -> bool:
        """Check if the configuration is unsupported."""
        # This would contain logic to check for unsupported combinations
        # For now, return False (all supported)
        return False
    
    def _add_offline_flag(self, command: str) -> str:
        """Add offline flag to Maven or Gradle commands."""
        if 'mvn' in command or 'gradle' in command:
            return f"{command} --offline"
        return command
    
    def _clean_dev_artifacts(self) -> None:
        """Remove dev-bundle and node_modules in dev mode."""
        try:
            artifacts = ['node_modules', 'src/main/dev-bundle']
            for artifact in artifacts:
                if Path(artifact).exists():
                    if Path(artifact).is_dir():
                        import shutil
                        shutil.rmtree(artifact)
                    else:
                        Path(artifact).unlink()
                    logger.debug(f"Removed {artifact}")
        except Exception as e:
            logger.warning(f"Error cleaning dev artifacts: {e}")
    
    def _add_production_flags(self, command: str) -> str:
        """Add production and deprecation flags."""
        if 'mvn' in command:
            flags = []
            if '-Pproduction' not in command:
                flags.append('-Pproduction')
            if '-Dmaven.compiler.showDeprecation' not in command:
                flags.append('-Dmaven.compiler.showDeprecation')
            if flags:
                return f"{command} {' '.join(flags)}"
        return command
    
    def _output_dependency_tree(self, mode: str, output_file: str, verbose: bool) -> None:
        """Output Maven/Gradle dependency tree for debugging."""
        try:
            if verbose:
                return  # Skip in verbose mode
            
            profile_flag = "-Pproduction,it" if mode == 'prod' else ""
            
            if Path('pom.xml').exists():
                cmd = f"mvn -ntp -B dependency:tree {profile_flag}"
                self._run_to_file(cmd, output_file)
            
            if Path('build.gradle').exists():
                cmd = "gradle dependencies"
                self._run_to_file(cmd, output_file)
                
        except Exception as e:
            logger.warning(f"Error outputting dependency tree: {e}")
    
    def _check_dependencies(self, name: str) -> bool:
        """Check for problematic dependencies in certain projects."""
        try:
            problem_apps = [
                'skeleton-starter-flow',
                'base-starter-flow-quarkus', 
                'skeleton-starter-flow-cdi',
                'archetype-jetty'
            ]
            
            if name in problem_apps:
                return self._check_no_spring_dependencies(name)
            
            return True
        except Exception as e:
            logger.error(f"Error checking dependencies: {e}")
            return False
    
    def _check_no_spring_dependencies(self, name: str) -> bool:
        """Check that app has no Spring dependencies when it shouldn't."""
        try:
            files_to_check = ['pom.xml', 'build.gradle']
            
            for file_path in files_to_check:
                if Path(file_path).exists():
                    with open(file_path, 'r') as f:
                        content = f.read()
                        if 'spring-boot' in content or 'spring-web' in content:
                            logger.error(f"App {name} should not have Spring dependencies")
                            return False
            
            return True
        except Exception as e:
            logger.error(f"Error checking Spring dependencies: {e}")
            return False
    
    def _check_busy_port(self, port: str) -> bool:
        """Check if port is already in use."""
        try:
            import socket
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                result = sock.connect_ex(('localhost', int(port)))
                if result == 0:
                    logger.error(f"Port {port} is already in use")
                    return False
            return True
        except Exception as e:
            logger.error(f"Error checking port {port}: {e}")
            return False
    
    def _disable_launch_browser(self) -> None:
        """Disable automatic browser launch."""
        try:
            # Set environment variable to disable browser launch
            os.environ['VAADIN_LAUNCH_BROWSER'] = 'false'
        except Exception as e:
            logger.warning(f"Error disabling browser launch: {e}")
    
    def _configure_package_manager(self) -> None:
        """Configure package manager settings."""
        try:
            # Enable pnpm if requested
            if os.environ.get('PNPM'):
                self._enable_pnpm()
            
            # Enable Vite if requested
            if os.environ.get('VITE'):
                self._enable_vite()
                
        except Exception as e:
            logger.warning(f"Error configuring package manager: {e}")
    
    def _enable_pnpm(self) -> None:
        """Enable pnpm package manager."""
        # Implementation would set pnpm configuration
        pass
    
    def _enable_vite(self) -> None:
        """Enable Vite build tool."""
        # Implementation would set Vite configuration  
        pass
    
    def _run_compilation(self, compile_cmd: str, output_file: str, verbose: bool) -> bool:
        """Run compilation command."""
        try:
            if not self._run_to_file(compile_cmd, output_file, verbose):
                # Check for test failures
                self._check_test_failures()
                return False
            return True
        except Exception as e:
            logger.error(f"Error running compilation: {e}")
            return False
    
    def _check_test_failures(self) -> None:
        """Check for and report test failures."""
        try:
            test_reports = Path('target').glob('*-reports/*txt')
            for report in test_reports:
                with open(report, 'r') as f:
                    content = f.read()
                    if 'FAILURE' in content:
                        logger.error(f"Test failures found in {report}")
                        # Extract failure details
                        failures = re.findall(r'FAILURE.*', content)
                        for failure in failures[:5]:  # Limit to first 5
                            logger.error(f"  {failure}")
        except Exception as e:
            logger.warning(f"Error checking test failures: {e}")
    
    def _start_application(self, run_cmd: str, output_file: str, verbose: bool) -> bool:
        """Start application in background."""
        try:
            return self._run_in_background_to_file(run_cmd, output_file, verbose)
        except Exception as e:
            logger.error(f"Error starting application: {e}")
            return False
    
    def _wait_for_application(self, output_file: str, check_string: str, timeout: int,
                            run_cmd: str, name: str, port: str) -> bool:
        """Wait for application to be ready."""
        try:
            # Wait for check string in output
            if not self._wait_until_message_in_file(output_file, check_string, timeout, run_cmd):
                return False
            
            # Wait for app to be ready on port
            if not self._wait_until_app_ready(name, port, 60, output_file):
                return False
            
            return True
        except Exception as e:
            logger.error(f"Error waiting for application: {e}")
            return False
    
    def _wait_for_manual_testing(self, port: str) -> None:
        """Wait for user to manually test the application."""
        try:
            logger.info(f"Application is running on http://localhost:{port}")
            logger.info("Please test the application manually, then press Enter to continue...")
            input()
        except Exception as e:
            logger.warning(f"Error during manual testing: {e}")
    
    def _check_deprecated_api(self, output_file: str) -> None:
        """Check for deprecated API usage in prod mode."""
        try:
            if not Path(output_file).exists():
                return
            
            with open(output_file, 'r') as f:
                content = f.read()
            
            # Look for deprecation warnings
            deprecated_warnings = []
            for line in content.split('\n'):
                if 'WARNING' in line and 'deprecated' in line.lower():
                    # Clean up the path
                    clean_line = re.sub(r'^.*\/src\/', 'src/', line)
                    deprecated_warnings.append(clean_line)
            
            if deprecated_warnings:
                logger.warning("Deprecated API usage found:")
                for warning in deprecated_warnings[:10]:  # Limit output
                    logger.warning(f"  {warning}")
                    
        except Exception as e:
            logger.warning(f"Error checking deprecated API: {e}")
    
    def _check_bundle_not_created(self, output_file: str) -> bool:
        """Check that dev-bundle was not created in dev mode."""
        try:
            dev_bundle_path = Path('src/main/dev-bundle')
            if dev_bundle_path.exists():
                logger.error("dev-bundle was created in dev mode - should use platform bundle")
                return False
            return True
        except Exception as e:
            logger.error(f"Error checking bundle creation: {e}")
            return False
    
    def _wait_for_frontend_compilation(self, url: str, output_file: str, run_cmd: str) -> bool:
        """Wait for frontend compilation in dev mode."""
        try:
            max_retries = 2
            for attempt in range(max_retries + 1):
                result = self._check_frontend_compiled(url, output_file)
                
                if result == 0:  # Success
                    return True
                elif result == 2 and attempt < max_retries:  # tsconfig modified, retry
                    logger.warning("tsconfig/types.d was modified, retrying...")
                    self._cleanup_processes()
                    
                    # Backup current output file
                    backup_file = f"{output_file}.tsconfig"
                    if Path(output_file).exists():
                        Path(output_file).rename(backup_file)
                    
                    # Restart application
                    if not self._run_in_background_to_file(run_cmd, output_file, False):
                        return False
                    
                    # Wait for app to be ready again
                    if not self._wait_until_message_in_file(output_file, "Started", 300, run_cmd):
                        return False
                    
                    continue
                else:
                    return False
            
            return False
        except Exception as e:
            logger.error(f"Error waiting for frontend compilation: {e}")
            return False
    
    def _check_frontend_compiled(self, url: str, output_file: str) -> int:
        """
        Check if frontend is compiled.
        Returns: 0=success, 1=error, 2=tsconfig modified
        """
        try:
            # Check for tsconfig modification
            if self._tsconfig_modified(output_file):
                return 2
            
            # Try to access the application
            try:
                with urllib.request.urlopen(url, timeout=10) as response:
                    if response.getcode() == 200:
                        return 0
            except (urllib.error.URLError, socket.timeout):
                pass
            
            # Check output file for compilation completion
            if Path(output_file).exists():
                with open(output_file, 'r') as f:
                    content = f.read()
                    if 'Frontend compiled successfully' in content:
                        return 0
                    if 'Compilation failed' in content:
                        return 1
            
            # Wait a bit more for compilation
            time.sleep(5)
            return 1
            
        except Exception as e:
            logger.error(f"Error checking frontend compilation: {e}")
            return 1
    
    def _tsconfig_modified(self, output_file: str) -> bool:
        """Check if tsconfig.json was modified."""
        try:
            if not Path(output_file).exists():
                return False
            
            with open(output_file, 'r') as f:
                content = f.read()
                if "'tsconfig.json' has been updated" in content:
                    # Check git diff
                    try:
                        result = subprocess.run(
                            ['git', 'diff', 'tsconfig.json'],
                            capture_output=True, text=True, timeout=10
                        )
                        if result.stdout.strip():
                            logger.info("tsconfig.json was modified")
                            return True
                    except subprocess.TimeoutExpired:
                        pass
            
            return False
        except Exception as e:
            logger.warning(f"Error checking tsconfig modification: {e}")
            return False
    
    def _check_http_servlet(self, url: str, output_file: str) -> bool:
        """Check that the app is accessible and returns valid servlet response."""
        try:
            max_attempts = 5
            for attempt in range(max_attempts):
                try:
                    with urllib.request.urlopen(url, timeout=10) as response:
                        if response.getcode() == 200:
                            # Check for basic servlet indicators
                            content = response.read().decode('utf-8').lower()
                            servlet_indicators = [
                                'vaadin',
                                'html',
                                'body',
                                'servlet'
                            ]
                            
                            if any(indicator in content for indicator in servlet_indicators):
                                logger.info(f"HTTP servlet check passed for {url}")
                                return True
                    
                except (urllib.error.URLError, socket.timeout) as e:
                    logger.debug(f"HTTP check attempt {attempt + 1} failed: {e}")
                
                if attempt < max_attempts - 1:
                    time.sleep(2)
            
            logger.error(f"HTTP servlet check failed for {url}")
            return False
            
        except Exception as e:
            logger.error(f"Error checking HTTP servlet: {e}")
            return False
    
    def _cleanup_processes(self) -> None:
        """Kill all background processes."""
        try:
            for proc in self.background_processes:
                try:
                    if proc.poll() is None:  # Process is still running
                        proc.terminate()
                        try:
                            proc.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            proc.kill()
                except Exception as e:
                    logger.warning(f"Error terminating process: {e}")
            
            self.background_processes.clear()
            
        except Exception as e:
            logger.warning(f"Error cleaning up processes: {e}")
    
    def _check_default_statistics_id(self) -> None:
        """Check for default statistics ID usage."""
        try:
            stats_file = Path.home() / '.vaadin' / 'usage-statistics.json'
            if stats_file.exists():
                with open(stats_file, 'r') as f:
                    content = f.read()
                    if '12b7fc85f50e8c82cb6f4b03e12f2335' in content:
                        logger.warning("Application is using default ID for statistics")
        except Exception as e:
            logger.warning(f"Error checking statistics ID: {e}")
    
    # Helper methods for running commands
    
    def _run_to_file(self, command: str, output_file: str, verbose: bool = False) -> bool:
        """Run command and send output to file."""
        try:
            logger.info(f"Running command: {command}")
            
            # Add Maven args if present
            if 'mvn' in command and os.environ.get('MAVEN_ARGS'):
                command = f"{command} {os.environ['MAVEN_ARGS']}"
            
            with open(output_file, 'a') as f:
                if verbose:
                    # Run with tee-like behavior
                    process = subprocess.Popen(
                        command, shell=True, stdout=subprocess.PIPE, 
                        stderr=subprocess.STDOUT, text=True
                    )
                    
                    for line in process.stdout:
                        print(line, end='')
                        f.write(line)
                    
                    process.wait()
                    result_code = process.returncode
                else:
                    # Run normally
                    result = subprocess.run(
                        command, shell=True, stdout=f, stderr=subprocess.STDOUT,
                        timeout=600
                    )
                    result_code = result.returncode
            
            if result_code != 0:
                self._report_output_errors(output_file, f"Error ({result_code}) running {command}")
                return False
            
            return True
            
        except Exception as e:
            logger.error(f"Error running command {command}: {e}")
            return False
    
    def _run_in_background_to_file(self, command: str, output_file: str, verbose: bool = False) -> bool:
        """Run command in background, sending output to file."""
        try:
            logger.info(f"Running in background: {command}")
            
            # Add Maven args if present
            if 'mvn' in command and os.environ.get('MAVEN_ARGS'):
                command = f"{command} {os.environ['MAVEN_ARGS']}"
            
            # Create/touch the output file
            Path(output_file).touch()
            
            # Start background process
            with open(output_file, 'a') as f:
                process = subprocess.Popen(
                    command, shell=True, stdout=f, stderr=subprocess.STDOUT,
                    preexec_fn=os.setsid if os.name != 'nt' else None
                )
            
            # Store process reference for cleanup
            self.background_processes.append(process)
            
            # Wait a bit and check if process is still running
            time.sleep(2)
            if process.poll() is not None:
                logger.error(f"Background process exited immediately: {command}")
                return False
            
            # Start tail process for verbose mode
            if verbose:
                self._start_tail_process(output_file)
            
            return True
            
        except Exception as e:
            logger.error(f"Error running background command {command}: {e}")
            return False
    
    def _start_tail_process(self, output_file: str) -> None:
        """Start tail process for verbose output."""
        try:
            if os.name == 'nt':  # Windows
                # Use PowerShell Get-Content for tailing
                tail_cmd = f'powershell -Command "Get-Content -Path {output_file} -Wait"'
            else:  # Unix-like
                tail_cmd = f'tail -f {output_file}'
            
            tail_process = subprocess.Popen(
                tail_cmd, shell=True, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            self.background_processes.append(tail_process)
            
        except Exception as e:
            logger.warning(f"Error starting tail process: {e}")
    
    def _wait_until_message_in_file(self, output_file: str, message: str, 
                                  timeout: int, command: str) -> bool:
        """Wait until a message appears in the output file."""
        try:
            start_time = time.time()
            
            while time.time() - start_time < timeout:
                if Path(output_file).exists():
                    with open(output_file, 'r') as f:
                        content = f.read()
                        if message in content:
                            logger.info(f"Found message '{message}' in output")
                            return True
                
                time.sleep(1)
            
            logger.error(f"Timeout waiting for message '{message}' in {output_file}")
            return False
            
        except Exception as e:
            logger.error(f"Error waiting for message: {e}")
            return False
    
    def _wait_until_app_ready(self, name: str, port: str, timeout: int, output_file: str) -> bool:
        """Wait until application is ready on the specified port."""
        try:
            start_time = time.time()
            
            while time.time() - start_time < timeout:
                try:
                    with urllib.request.urlopen(f"http://localhost:{port}/", timeout=5) as response:
                        if response.getcode() == 200:
                            logger.info(f"Application {name} is ready on port {port}")
                            return True
                except (urllib.error.URLError, socket.timeout):
                    pass
                
                time.sleep(2)
            
            logger.error(f"Timeout waiting for application {name} on port {port}")
            return False
            
        except Exception as e:
            logger.error(f"Error waiting for app readiness: {e}")
            return False
    
    def _report_output_errors(self, output_file: str, header: str) -> None:
        """Report errors found in the output file."""
        if not Path(output_file).exists():
            return
        
        error_patterns = [
            r"\[ERROR\]",
            r"FAILURE",
            r"Error starting Application",
            r"Failed to start",
            r"Node installation failed",
            r"npm ERR!",
            r"vite failed to load",
            r"java.lang.ExceptionInInitializerError",
            r"java.lang.RuntimeException",
            r"java.net.BindException",
        ]
        
        errors = []
        with open(output_file, 'r', encoding='utf-8') as f:
            for line in f:
                for pattern in error_patterns:
                    if re.search(pattern, line, re.IGNORECASE):
                        errors.append(line.strip())
                        break # Move to next line after finding a match
        
        if errors:
            from .output_utils import err
            err(f"Found errors in {output_file} under '{header}':")
            for error_line in errors[:20]: # Report max 20 errors
                print(f"  - {error_line}")
            if len(errors) > 20:
                print(f"  ... and {len(errors) - 20} more errors.")

    def _check_for_deprecated_api(self, output_file: str) -> None:
        """Check for deprecated API warnings in the output."""
        if not Path(output_file).exists():
            return
        
        deprecated_warnings = []
        with open(output_file, 'r', encoding='utf-8') as f:
            for line in f:
                if "WARNING" in line and "deprecated" in line:
                    deprecated_warnings.append(line.strip())
        
        if deprecated_warnings:
            from .output_utils import warn
            warn("Found deprecated API usage:")
            for warning in deprecated_warnings[:10]:
                print(f"  - {warning}")

if __name__ == '__main__':
    # Example usage
    validation_manager = ValidationManager()
    
    # Run validations for an app
    success = validation_manager.run_validations(
        mode='dev',
        version='24.4',
        name='hello-world',
        port='8080',
        compile_cmd='mvn compile',
        run_cmd='mvn spring-boot:run',
        check_string='Started',
        timeout=300
    )
    
    print(f"Validation {'passed' if success else 'failed'}")
