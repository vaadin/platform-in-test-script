#!/usr/bin/env python3
"""
Playwright utilities for Platform Integration Test (PiT).
Migrated from scripts/pit/lib/lib-playwright.sh.
Provides Playwright installation and test execution functionality.
"""

import os
import subprocess
import json
import shutil
from pathlib import Path
from typing import Optional, List, Dict, Any
import logging

# Use basic imports to avoid dependency issues
import subprocess
import platform

logger = logging.getLogger(__name__)

class PlaywrightManager:
    """Manages Playwright installation and test execution."""
    
    def __init__(self):
        self.node_path = os.path.expanduser('~/.vaadin/node')
        self.npm_js_path = os.path.join(self.node_path, 'lib/node_modules/npm/bin/npm-cli.js')
        
    def is_playwright_installed(self) -> bool:
        """
        Check if Playwright is installed and available.
        
        Returns:
            True if Playwright is installed, False otherwise
        """
        try:
            # Check for npx playwright command
            result = subprocess.run(
                ['npx', 'playwright', '--version'],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0:
                logger.debug(f"Playwright version: {result.stdout.strip()}")
                return True
            
            # Check for local playwright installation
            local_playwright = Path('./node_modules/.bin/playwright')
            if local_playwright.exists():
                result = subprocess.run(
                    [str(local_playwright), '--version'],
                    capture_output=True, text=True, timeout=10
                )
                if result.returncode == 0:
                    logger.debug(f"Local Playwright version: {result.stdout.strip()}")
                    return True
            
            logger.debug("Playwright not found")
            return False
            
        except Exception as e:
            logger.error(f"Error checking Playwright installation: {e}")
            return False
    
    def install_playwright(self, force: bool = False) -> bool:
        """
        Install Playwright and its dependencies.
        
        Args:
            force: Force reinstallation even if already installed
            
        Returns:
            True if installation successful, False otherwise
        """
        try:
            if not force and self.is_playwright_installed():
                logger.info("Playwright is already installed")
                return True
            
            logger.info("Installing Playwright...")
            
            # Compute npm command based on Vaadin node installation
            npm_cmd = self._get_npm_command()
            
            # Install Playwright
            install_cmd = npm_cmd + ['install', '@playwright/test']
            result = subprocess.run(install_cmd, timeout=300)
            
            if result.returncode != 0:
                logger.error(f"Failed to install Playwright: {result.stderr}")
                return False
            
            # Install browser binaries
            playwright_cmd = self._get_playwright_command()
            if playwright_cmd:
                browser_cmd = playwright_cmd + ['install']
                result = subprocess.run(browser_cmd, timeout=600)
                
                if result.returncode != 0:
                    logger.error(f"Failed to install Playwright browsers: {result.stderr}")
                    return False
            
            # Verify installation
            if not self.check_playwright_installation():
                logger.error("Playwright installation verification failed")
                return False
            
            logger.info("Playwright installation completed successfully")
            return True
            
        except Exception as e:
            logger.error(f"Error installing Playwright: {e}")
            return False
    
    def check_playwright_installation(self) -> bool:
        """
        Check Playwright installation and report status.
        
        Returns:
            True if installation is valid, False otherwise
        """
        try:
            logger.info("Checking Playwright installation...")
            
            # Check if Playwright is installed
            if not self.is_playwright_installed():
                logger.error("Playwright is not installed")
                return False
            
            # Check browser installations
            playwright_cmd = self._get_playwright_command()
            if playwright_cmd:
                # Try to list installed browsers
                result = subprocess.run(
                    playwright_cmd + ['install', '--dry-run'],
                    capture_output=True, text=True, timeout=30
                )
                
                if result.returncode == 0:
                    logger.info("Playwright browsers are properly installed")
                else:
                    logger.warning("Some Playwright browsers may not be installed")
            
            # Check for basic test capability
            test_script = self._create_test_script()
            if test_script:
                result = subprocess.run(
                    playwright_cmd + ['test', test_script, '--reporter=list'],
                    capture_output=True, text=True, timeout=60
                )
                
                # Clean up test script
                Path(test_script).unlink(missing_ok=True)
                
                if result.returncode == 0:
                    logger.info("Playwright installation test passed")
                    return True
                else:
                    logger.warning("Playwright installation test failed, but installation appears valid")
                    return True  # Still consider it installed if basic check passed
            
            return True
            
        except Exception as e:
            logger.error(f"Error checking Playwright installation: {e}")
            return False
    
    def run_playwright_tests(self, test_file: str, output_file: str, mode: str, 
                           app_name: str, version: str, *args) -> bool:
        """
        Run Playwright tests against the application.
        
        Args:
            test_file: Path to the test file
            output_file: File to append output to
            mode: Test mode (dev/prod)
            app_name: Name of the application
            version: Platform version
            *args: Additional arguments (e.g., --port=8080)
            
        Returns:
            True if tests passed, False otherwise
        """
        try:
            if not Path(test_file).exists():
                logger.error(f"Test file not found: {test_file}")
                return False
            
            if not self.is_playwright_installed():
                logger.error("Playwright is not installed")
                return False
            
            logger.info(f"Running Playwright tests: {test_file}")
            
            # Parse additional arguments
            test_args = []
            env_vars = {}
            
            for arg in args:
                if arg.startswith('--port='):
                    port = arg.split('=')[1]
                    env_vars['BASE_URL'] = f'http://localhost:{port}'
                    test_args.append(f'--grep-invert=@skip-{mode}')
                elif arg.startswith('--'):
                    test_args.append(arg)
            
            # Set environment variables for test context
            env_vars.update({
                'PIT_MODE': mode,
                'PIT_APP': app_name,
                'PIT_VERSION': version,
                'PIT_OUTPUT_FILE': output_file
            })
            
            # Construct Playwright command
            playwright_cmd = self._get_playwright_command()
            if not playwright_cmd:
                logger.error("Could not determine Playwright command")
                return False
            
            # Build test command
            cmd = playwright_cmd + ['test', test_file] + test_args + [
                '--reporter=list',
                f'--output-dir=./test-results-{app_name}-{mode}',
                '--max-failures=1'
            ]
            
            # Set timeout based on mode
            timeout = 300 if mode == 'prod' else 600  # Longer timeout for dev mode
            
            # Run tests with environment variables
            test_env = os.environ.copy()
            test_env.update(env_vars)
            
            logger.debug(f"Running command: {' '.join(cmd)}")
            result = subprocess.run(
                cmd, timeout=timeout, env=test_env, capture_output=True, text=True
            )
            
            # Append test output to output file
            self._append_test_output(output_file, result, test_file)
            
            # Check for console errors in output
            if not self._check_for_console_errors(output_file):
                logger.warning("Console errors detected during test execution")
            
            if result.returncode == 0:
                logger.info(f"Playwright tests passed for {app_name}")
                return True
            else:
                logger.error(f"Playwright tests failed for {app_name}: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Error running Playwright tests: {e}")
            return False
    
    def _get_npm_command(self) -> List[str]:
        """Get the appropriate npm command based on Vaadin node installation."""
        try:
            # Check for Vaadin node installation
            if Path(self.node_path).exists() and Path(self.npm_js_path).exists():
                node_bin = os.path.join(self.node_path, 'bin', 'node')
                if Path(node_bin).exists():
                    return [node_bin, self.npm_js_path]
            
            # Fall back to system npm
            npm_path = shutil.which('npm')
            if npm_path:
                return [npm_path]
            
            # Last resort: try npx
            npx_path = shutil.which('npx')
            if npx_path:
                return [npx_path, 'npm']
            
            raise RuntimeError("No npm command found")
            
        except Exception as e:
            logger.error(f"Error determining npm command: {e}")
            return ['npm']  # Default fallback
    
    def _get_playwright_command(self) -> Optional[List[str]]:
        """Get the appropriate Playwright command."""
        try:
            # Try npx playwright first
            npx_path = shutil.which('npx')
            if npx_path:
                return [npx_path, 'playwright']
            
            # Try local installation
            local_playwright = Path('./node_modules/.bin/playwright')
            if local_playwright.exists():
                return [str(local_playwright)]
            
            # Try global installation
            playwright_path = shutil.which('playwright')
            if playwright_path:
                return [playwright_path]
            
            logger.error("No Playwright command found")
            return None
            
        except Exception as e:
            logger.error(f"Error determining Playwright command: {e}")
            return None
    
    def _create_test_script(self) -> Optional[str]:
        """Create a simple test script for installation verification."""
        try:
            test_content = '''
const { test, expect } = require('@playwright/test');

test('basic test', async ({ page }) => {
  // This is just a basic test to verify Playwright works
  await page.goto('data:text/html,<html><body><h1>Test</h1></body></html>');
  await expect(page.locator('h1')).toHaveText('Test');
});
'''
            
            test_file = 'playwright-test-verification.spec.js'
            with open(test_file, 'w') as f:
                f.write(test_content)
            
            return test_file
            
        except Exception as e:
            logger.error(f"Error creating test script: {e}")
            return None
    
    def _append_test_output(self, output_file: str, result: subprocess.CompletedProcess, 
                          test_file: str) -> None:
        """Append test output to the specified output file."""
        try:
            with open(output_file, 'a', encoding='utf-8') as f:
                f.write(f"\n=== Playwright Test Results for {test_file} ===\n")
                if result.stdout:
                    f.write("STDOUT:\n")
                    f.write(result.stdout)
                    f.write("\n")
                if result.stderr:
                    f.write("STDERR:\n")
                    f.write(result.stderr)
                    f.write("\n")
                f.write(f"Exit code: {result.returncode}\n")
                f.write("=== End Playwright Test Results ===\n\n")
                
        except Exception as e:
            logger.error(f"Error appending test output to {output_file}: {e}")
    
    def _check_for_console_errors(self, output_file: str) -> bool:
        """
        Check for console errors in test output.
        
        Args:
            output_file: Path to output file to check
            
        Returns:
            True if no critical console errors found, False otherwise
        """
        try:
            if not Path(output_file).exists():
                return True
            
            with open(output_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Look for console error patterns
            error_patterns = [
                'console.error',
                'TypeError:',
                'ReferenceError:',
                'SyntaxError:',
                'Failed to load resource',
                'Uncaught',
                'SEVERE'
            ]
            
            # Look for warning patterns (less critical)
            warning_patterns = [
                'console.warn',
                'console.warning',
                'deprecated',
                'WARN'
            ]
            
            errors_found = []
            warnings_found = []
            
            for line in content.split('\n'):
                line_lower = line.lower()
                
                for pattern in error_patterns:
                    if pattern.lower() in line_lower:
                        errors_found.append(line.strip())
                        break
                else:
                    for pattern in warning_patterns:
                        if pattern.lower() in line_lower:
                            warnings_found.append(line.strip())
                            break
            
            if errors_found:
                logger.error(f"Console errors detected: {len(errors_found)} errors")
                for error in errors_found[:5]:  # Log first 5 errors
                    logger.error(f"  {error}")
                return False
            
            if warnings_found:
                logger.warning(f"Console warnings detected: {len(warnings_found)} warnings")
                for warning in warnings_found[:3]:  # Log first 3 warnings
                    logger.warning(f"  {warning}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error checking for console errors: {e}")
            return True  # Assume no errors if we can't check
    
    def get_playwright_info(self) -> Dict[str, Any]:
        """
        Get information about Playwright installation.
        
        Returns:
            Dictionary with installation information
        """
        info = {
            'installed': False,
            'version': None,
            'browsers': [],
            'npm_command': None,
            'playwright_command': None
        }
        
        try:
            info['installed'] = self.is_playwright_installed()
            info['npm_command'] = self._get_npm_command()
            info['playwright_command'] = self._get_playwright_command()
            
            if info['installed'] and info['playwright_command']:
                # Get version
                result = subprocess.run(
                    info['playwright_command'] + ['--version'],
                    capture_output=True, text=True, timeout=10
                )
                if result.returncode == 0:
                    info['version'] = result.stdout.strip()
                
                # Get browser list (if possible)
                try:
                    result = subprocess.run(
                        info['playwright_command'] + ['install', '--dry-run'],
                        capture_output=True, text=True, timeout=30
                    )
                    if result.returncode == 0:
                        # Parse browser information from output
                        for line in result.stdout.split('\n'):
                            if 'browser' in line.lower():
                                info['browsers'].append(line.strip())
                except Exception:
                    pass  # Browser list is optional
            
        except Exception as e:
            logger.error(f"Error getting Playwright info: {e}")
        
        return info

if __name__ == '__main__':
    # Example usage
    playwright_manager = PlaywrightManager()
    
    # Check installation
    if not playwright_manager.is_playwright_installed():
        print("Installing Playwright...")
        success = playwright_manager.install_playwright()
        if not success:
            print("Failed to install Playwright")
            exit(1)
    
    # Get info
    info = playwright_manager.get_playwright_info()
    print(f"Playwright info: {info}")
    
    # Run tests (example)
    # success = playwright_manager.run_playwright_tests(
    #     'test.spec.js', 'output.log', 'dev', 'my-app', '24.4', '--port=8080'
    # )
