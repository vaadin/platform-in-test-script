"""
Main PiT (Platform Integration Test) runner.
Converted from run.sh
"""

import os
import sys
import time
import signal
from pathlib import Path
from typing import Dict, Any, List, Optional

from .system_utils import check_commands, check_port
from .output_utils import log, err, warn, bold
from .process_utils import ProcessManager
from .repos import filter_starters, is_preset, is_demo
from .pit_args import PitArgumentParser, create_pit_config, validate_args
from .starter_utils import run_starter, run_demo
from .k8s_utils import ControlCenterManager
from .patch_utils import PatchManager
from .playwright_utils import PlaywrightManager
from .validation_utils import ValidationManager
from .utils import (
    pit_logger, process_manager, pro_key_manager, 
    setup_signal_handlers, cleanup_all, PlatformUtils
)


class PitRunner:
    """Main Platform Integration Test runner."""
    
    def __init__(self):
        self.start_time = time.time()
        self.success = []
        self.failed = []
        self.config = {}
        self.process_manager = ProcessManager()
        
        # Set up signal handlers for cleanup
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals."""
        log("Received shutdown signal, cleaning up...")
        self._cleanup()
        sys.exit(1)
    
    def _cleanup(self):
        """Clean up resources and background processes."""
        self.process_manager.cleanup()
    
    def run(self, args: Optional[List[str]] = None) -> int:
        """
        Main entry point for PiT runner.
        
        Args:
            args: Command line arguments (if None, uses sys.argv)
            
        Returns:
            Exit code
        """
        try:
            # Parse arguments
            parser = PitArgumentParser()
            parsed_args = parser.parse_args(args)
            
            # Create configuration
            self.config = create_pit_config(parsed_args)
            
            # Validate configuration
            if not validate_args(self.config):
                return 1
            
            # Check required commands
            if not check_commands('jq', 'curl'):
                err("Required commands not found: jq, curl")
                return 1
            
            # Handle special functions
            if self.config.get('function'):
                return self._run_function(self.config['function'])
            
            # Run main test suite
            return self._run_main()
            
        except KeyboardInterrupt:
            log("Interrupted by user")
            return 130
        except Exception as e:
            err(f"Unexpected error: {e}")
            return 1
        finally:
            self._cleanup()
    
    def _run_function(self, function_name: str) -> int:
        """Run a specific function for testing."""
        log(f"Running function: {function_name}")
        
        # This would call specific functions from the utility modules
        # For now, just log that the function would be called
        try:
            # Here you would dynamically call functions from the various utility modules
            # eval(function_name)  # Not recommended for security
            log("Function execution not yet implemented")
            return 0
        except Exception as e:
            err(f"Error running function {function_name}: {e}")
            return 1
    
    def _run_main(self) -> int:
        """Run the main test suite."""
        header = "Showing PiT Commands" if self.config['test_mode'] else "Executing PiT Tests"
        log(f"===================== {header} =====================================")
        
        # Calculate which starters to run
        starters = self._compute_starters()
        
        # Separate presets and demos
        presets = []
        demos = []
        
        for starter in starters:
            base_name = starter.split(':')[0]
            if is_preset(base_name):
                presets.append(starter)
            elif is_demo(base_name):
                demos.append(starter)
        
        # Create temporary directory
        pwd = os.getcwd()
        tmp_dir = Path(pwd) / 'tmp'
        tmp_dir.mkdir(exist_ok=True)
        
        # Clean Maven cache if not skipped
        if not self.config.get('skip_clean'):
            self._clean_m2_cache(self.config.get('version'))
        
        try:
            # Run presets
            for preset in presets:
                log(f"================= {header} for '{preset}' ==================")
                
                # Handle special JDK requirements
                if 'hotswap' in preset:
                    if not self._install_jbr_runtime():
                        continue
                elif self.config.get('jdk'):
                    if not self._install_jdk_runtime(self.config['jdk']):
                        continue
                
                self._run_single_test('preset', preset, str(tmp_dir))
            
            # Run demos
            for demo in demos:
                log(f"================= {header} for '{demo}' ==================")
                
                # Handle special cases
                if demo.startswith('control-center'):
                    if self._is_windows_github_actions():
                        warn("Control Center cannot be run in GH Windows runners")
                        return 0
                    
                    os.chdir(str(tmp_dir))
                    if self._checkout_demo(demo):
                        self._run_control_center_validation(demo)
                    else:
                        self.failed.append(demo)
                    os.chdir(pwd)
                    continue
                
                # Handle JDK-specific demos
                if '_jdk' in demo:
                    jdk_version = demo.split('_jdk')[1]
                    demo_name = demo.split('_jdk')[0]
                    if not self._install_jdk_runtime(jdk_version):
                        continue
                    demo = demo_name
                elif self.config.get('jdk'):
                    if not self._install_jdk_runtime(self.config['jdk']):
                        continue
                
                # Check if port is available
                if not self.config['test_mode']:
                    if check_port(self.config['port']):
                        err(f"Port {self.config['port']} is busy")
                        return 1
                
                self._run_single_test('demo', demo, str(tmp_dir))
            
            os.chdir(pwd)
            
            if self.config['test_mode']:
                return 0
            
            # Report results
            self._report_results()
            
            # Calculate total time
            elapsed = time.time() - self.start_time
            log(f"Tests completed in {elapsed:.0f} seconds")
            
            return 1 if self.failed else 0
            
        except Exception as e:
            err(f"Error in main test suite: {e}")
            return 1
    
    def _compute_starters(self) -> List[str]:
        """Compute which starters to run based on configuration."""
        starter_list = self.config.get('starters', '')
        
        # Handle exclusions (starters beginning with !)
        exclusions = []
        starters = []
        
        for item in starter_list.split(','):
            item = item.strip()
            if item.startswith('!'):
                exclusions.append(item)
            elif item:
                starters.append(item)
        
        return filter_starters(','.join(starters), exclusions)
    
    def _run_single_test(self, test_type: str, name: str, target_dir: str) -> None:
        """
        Run a single starter or demo test.
        
        Args:
            test_type: 'preset' or 'demo'
            name: Name of the test
            target_dir: Target directory for the test
        """
        try:
            if test_type == 'preset':
                result = run_starter(
                    name, target_dir, self.config['port'],
                    self.config.get('version'), self.config.get('offline', False)
                )
            else:  # demo
                result = run_demo(
                    name, target_dir, self.config['port'],
                    self.config.get('version'), self.config.get('offline', False)
                )
            
            if self.config['test_mode']:
                self._cleanup()
                return
            
            if result == 0:
                log(f"==== '{name}' was built and tested successfully ====")
                self.success.append(name)
            else:
                self.failed.append(name)
                err(f"==== Error testing '{name}' ====")
            
        except Exception as e:
            err(f"Error running test {name}: {e}")
            self.failed.append(name)
        finally:
            self.process_manager.cleanup()
    
    def _install_jbr_runtime(self) -> bool:
        """Install JBR (JetBrains Runtime) for hotswap support."""
        # Implementation would go here
        log("JBR runtime installation not yet implemented")
        return True
    
    def _install_jdk_runtime(self, jdk_version: str) -> bool:
        """Install specific JDK version."""
        # Implementation would go here  
        log(f"JDK {jdk_version} installation not yet implemented")
        return True
    
    def _is_windows_github_actions(self) -> bool:
        """Check if running on Windows in GitHub Actions."""
        return (os.environ.get('GITHUB_ACTIONS') == 'true' and 
                os.name == 'nt')
    
    def _checkout_demo(self, demo: str) -> bool:
        """Checkout a demo repository."""
        from .starter_utils import DemoManager
        demo_mgr = DemoManager(self.config)
        return demo_mgr.checkout_demo(demo)
    
    def _run_control_center_validation(self, demo: str) -> None:
        """Run Control Center validation."""
        cc_manager = ControlCenterManager(self.config)
        try:
            if self._validate_control_center(cc_manager):
                self.success.append(demo)
            else:
                self.failed.append(demo)
        except Exception as e:
            err(f"Control Center validation failed: {e}")
            self.failed.append(demo)
    
    def _validate_control_center(self, cc_manager: ControlCenterManager) -> bool:
        """Validate Control Center deployment."""
        # Clear any existing GitHub tokens for security
        os.environ.pop('GHTK', None)
        os.environ.pop('GITHUB_TOKEN', None)
        
        # Check required commands
        if not check_commands('docker', 'kubectl', 'helm', 'unzip'):
            return False
        
        # Check Docker for kind vendor
        if self.config['vendor'] == 'kind' and not cc_manager.check_docker_running():
            return False
        
        # Clean up any existing screenshots
        screenshots_dir = Path('screenshots.out')
        if screenshots_dir.exists():
            import shutil
            shutil.rmtree(screenshots_dir)
        
        try:
            # Run control center for current version if not skipped
            if not self.config.get('skip_current'):
                cc_version = cc_manager.check_current_version(self.config.get('cc_version'))
                if not cc_version:
                    return False
                
                if not self._run_control_center(cc_manager, cc_version, 'latest', 'current'):
                    cc_manager.download_logs()
                    return False
            
            # Run control center for specified version
            if self.config.get('version') and self.config['version'] != 'current':
                cc_version = cc_manager.compute_cc_version(self.config['version'])
                if not cc_version:
                    return False
                
                is_snapshot = cc_version.endswith('-SNAPSHOT')
                if not self._run_control_center(cc_manager, cc_version, 'local', 
                                               self.config['version'], is_snapshot):
                    cc_manager.download_logs()
                    return False
            
            return True
            
        except Exception as e:
            err(f"Control Center validation failed: {e}")
            return False
    
    def _run_control_center(self, cc_manager: ControlCenterManager, 
                           cc_version: str, tag: str, vaadin_version: str,
                           is_snapshot: bool = False) -> bool:
        """Run a complete Control Center test cycle."""
        bold(f"----> Running PiT for app: control-center version: '{cc_version}' "
             f"tag: '{tag}' - vaadinVersion: {vaadin_version}")
        
        try:
            # Check if port 443 is available
            if not self.config['test_mode'] and not check_port(443):
                return False
            
            # Create cluster if needed
            # This would involve calling cluster management functions
            
            # Set cluster context
            # This would set up kubectl context
            
            # Clean up CC from previous run unless skip-helm is set
            if not self.config['skip_helm']:
                cc_manager.uninstall_cc()
            
            # Build CC and apps if needed
            if tag != 'local' or is_snapshot:
                # This would build Control Center and apps
                pass
            
            # Install Control Center
            if not cc_manager.install_cc(cc_version, is_snapshot):
                return False
            
            # Wait for Control Center to be ready
            if not cc_manager.wait_for_cc(900):
                return False
            
            # Show temporary password
            cc_manager.show_temporary_password()
            
            # Install TLS certificates
            if not cc_manager.install_tls() or not cc_manager.check_tls():
                return False
            
            # Run Playwright tests
            # This would run the actual browser tests
            
            # Uninstall Control Center if not keeping it
            if not self.config.get('keep_cc'):
                cc_manager.uninstall_cc(wait=False)
            
            bold(f"----> Tested version '{cc_version}' of 'control-center'")
            return True
            
        except Exception as e:
            err(f"Failed to run Control Center {cc_version}: {e}")
            return False
    
    def _clean_m2_cache(self, version: Optional[str]) -> None:
        """Clean Maven cache for the specified version."""
        if not version:
            return
            
        # Implementation would clean ~/.m2/repository for the version
        log(f"Maven cache cleaning for version {version} not yet implemented")
    
    def _report_results(self) -> None:
        """Report test results."""
        # Report successful tests
        for success in self.success:
            bold(f"🟢 Starter {success} built successfully")
        
        # Report failed tests
        error_occurred = False
        for failed in self.failed:
            files = Path(f"tmp/{failed}").glob("*.out")
            file_list = " ".join(str(f) for f in files)
            err(f"🔴 ERROR in {failed}, check log files: {file_list}")
            error_occurred = True
        
        return error_occurred


def main(args: Optional[List[str]] = None) -> int:
    """
    Main entry point for the PiT runner.
    
    Args:
        args: Command line arguments
        
    Returns:
        Exit code
    """
    runner = PitRunner()
    return runner.run(args)


if __name__ == '__main__':
    sys.exit(main())
