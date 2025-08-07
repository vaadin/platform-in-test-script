"""
Argument parsing utilities for PiT tests.
Converted from lib-args.sh
"""

import argparse
import os
from typing import Dict, Any, Optional
from pathlib import Path

from .repos import get_default_starters, ALL_STARTERS


class PitArgumentParser:
    """Enhanced argument parser for PiT test suite."""
    
    def __init__(self):
        self.parser = self._create_parser()
        
    def _create_parser(self) -> argparse.ArgumentParser:
        """Create the main argument parser."""
        parser = argparse.ArgumentParser(
            description='Platform Integration Test (PiT) runner',
            formatter_class=argparse.RawDescriptionHelpFormatter,
            epilog=self._get_epilog()
        )
        
        # Version options
        parser.add_argument('--version', type=str, 
                          help='Vaadin version to test, if not given it only tests current stable')
        
        # Test selection
        parser.add_argument('--demos', action='store_true',
                          help='Run all demo projects')
        parser.add_argument('--generated', action='store_true', 
                          help='Run all generated projects (start and archetypes)')
        parser.add_argument('--starters', type=str,
                          help='List of demos or presets separated by comma to run (default: all)')
        
        # Server configuration
        parser.add_argument('--port', type=int, default=8080,
                          help='HTTP port for the servlet container (default: 8080)')
        parser.add_argument('--timeout', type=int, default=300,
                          help='Time in secs to wait for server to start (default: 300)')
        
        # Java/Runtime options
        parser.add_argument('--jdk', type=str,
                          help='Use a specific JDK version to run the tests')
        
        # Build options  
        parser.add_argument('--verbose', action='store_true',
                          help='Show server output (default silent)')
        parser.add_argument('--offline', action='store_true',
                          help='Do not remove already downloaded projects, and do not use network for mvn')
        parser.add_argument('--pnpm', action='store_true',
                          help='Use pnpm instead of npm to speed up frontend compilation')
        parser.add_argument('--vite', action='store_true',
                          help='Use vite instead of webpack to speed up frontend compilation')
        
        # Test options
        parser.add_argument('--interactive', action='store_true',
                          help='Play a bell and ask user to manually test the application')
        parser.add_argument('--skip-tests', action='store_true',
                          help='Skip UI Tests (default run tests)')
        parser.add_argument('--skip-current', action='store_true',
                          help='Skip running build in current version')
        parser.add_argument('--skip-prod', action='store_true',
                          help='Skip production validations')
        parser.add_argument('--skip-dev', action='store_true',
                          help='Skip dev-mode validations')
        parser.add_argument('--skip-clean', action='store_true',
                          help='Do not clean maven cache')
        parser.add_argument('--skip-pw', action='store_true',
                          help='Do not run playwright tests')
        
        # Kubernetes/Control Center options
        parser.add_argument('--cluster', type=str,
                          help='Run tests in an existing k8s cluster')
        parser.add_argument('--vendor', type=str, default='kind',
                          choices=['kind', 'do', 'az', 'docker-desktop'],
                          help='Use a specific cluster vendor (default: kind)')
        parser.add_argument('--skip-helm', action='store_true',
                          help='Do not re-install control-center with helm')
        parser.add_argument('--keep-cc', action='store_true',
                          help='Keep control-center running after tests')
        parser.add_argument('--keep-apps', action='store_true',
                          help='Keep installed apps in control-center, implies --keep-cc')
        parser.add_argument('--proxy-cc', action='store_true',
                          help='Forward port 443 from k8s cluster to localhost')
        parser.add_argument('--events-cc', action='store_true',
                          help='Display events from control-center')
        parser.add_argument('--cc-version', type=str,
                          help='Install this version for current')
        parser.add_argument('--skip-build', action='store_true',
                          help='Skip building the docker images for control-center')
        parser.add_argument('--delete-cluster', action='store_true',
                          help='Delete the cluster/s')
        parser.add_argument('--dashboard', type=str, choices=['install', 'uninstall'],
                          help='Install kubernetes dashboard')
        
        # Git options
        parser.add_argument('--git-ssh', action='store_true',
                          help='Use git-ssh instead of https to checkout projects')
        parser.add_argument('--commit', action='store_true',
                          help='Commit changes to the base branch')
        
        # Browser options
        parser.add_argument('--hub', action='store_true',
                          help='Use selenium hub instead of local chrome')
        parser.add_argument('--headless', action='store_true',
                          help='Run the browser in headless mode even if interactive mode is enabled')
        parser.add_argument('--headed', action='store_true',
                          help='Run the browser in headed mode even if interactive mode is disabled')
        
        # Utility options
        parser.add_argument('--test', action='store_true',
                          help='Checkout starters, and show steps and commands to execute, but don\'t run them')
        parser.add_argument('--list', action='store_true',
                          help='Show the list of available starters')
        parser.add_argument('--function', type=str,
                          help='Run only one function of the libs')
        parser.add_argument('--path', action='store_true',
                          help='Show available SW installed in the container')
        
        return parser
    
    def _get_epilog(self) -> str:
        """Generate epilog with available starters."""
        starters_text = '\n                   · '.join([''] + get_default_starters())
        return f"""
Available starters:{starters_text}
"""
    
    def parse_args(self, args=None) -> argparse.Namespace:
        """Parse arguments and perform post-processing."""
        parsed_args = self.parser.parse_args(args)
        
        # Handle special cases
        if parsed_args.list:
            self._print_starters()
            exit(0)
            
        if parsed_args.path:
            self._print_path()
            exit(0)
        
        # Post-process arguments
        self._post_process_args(parsed_args)
        
        return parsed_args
    
    def _post_process_args(self, args: argparse.Namespace) -> None:
        """Post-process parsed arguments."""
        # Handle keep-apps implies keep-cc
        if args.keep_apps:
            args.keep_cc = True
            
        # Handle skip-helm implies offline and keep-cc  
        if args.skip_helm:
            args.offline = True
            args.keep_cc = True
            
        # Set default starters if none specified
        if not args.starters:
            if args.demos:
                from .repos import DEMOS
                args.starters = ','.join(DEMOS)
            elif args.generated:
                from .repos import PRESETS
                args.starters = ','.join(PRESETS)
            else:
                args.starters = ','.join(get_default_starters())
    
    def _print_starters(self) -> None:
        """Print available starters."""
        from .repos import PRESETS, DEMOS
        
        print("Available Presets:")
        for preset in PRESETS:
            print(f"  · {preset}")
            
        print("\nAvailable Demos:")
        for demo in DEMOS:
            print(f"  · {demo}")
    
    def _print_path(self) -> None:
        """Print available software paths (for container environments)."""
        paths = []
        hostedtools_path = Path('/opt/hostedtoolcache')
        
        if hostedtools_path.exists():
            for tool_dir in hostedtools_path.glob('*/*/x64'):
                bin_dir = tool_dir / 'bin'
                if bin_dir.exists():
                    paths.append(str(bin_dir))
                else:
                    paths.append(str(tool_dir))
        
        if paths:
            path_str = ':'.join(paths)
            print(f"export PATH={path_str}:$PATH")


def create_pit_config(args: argparse.Namespace) -> Dict[str, Any]:
    """
    Create a configuration dictionary from parsed arguments.
    
    Args:
        args: Parsed command line arguments
        
    Returns:
        Configuration dictionary
    """
    config = {
        # Version and basic config
        'version': args.version,
        'port': args.port,
        'timeout': args.timeout,
        'jdk': args.jdk,
        
        # Test selection
        'starters': args.starters,
        'demos_only': args.demos,
        'generated_only': args.generated,
        
        # Build options
        'verbose': args.verbose,
        'offline': args.offline,
        'pnpm': args.pnpm,
        'vite': args.vite,
        
        # Test options
        'interactive': args.interactive,
        'skip_tests': args.skip_tests,
        'skip_current': args.skip_current,
        'skip_prod': args.skip_prod,
        'skip_dev': args.skip_dev,
        'skip_clean': args.skip_clean,
        'skip_pw': args.skip_pw,
        
        # Kubernetes options
        'cluster': args.cluster,
        'vendor': args.vendor,
        'skip_helm': args.skip_helm,
        'keep_cc': args.keep_cc,
        'keep_apps': args.keep_apps,
        'proxy_cc': args.proxy_cc,
        'events_cc': args.events_cc,
        'cc_version': args.cc_version,
        'skip_build': args.skip_build,
        'delete_cluster': args.delete_cluster,
        'dashboard': args.dashboard,
        
        # Git options
        'git_ssh': args.git_ssh,
        'commit': args.commit,
        
        # Browser options
        'hub': args.hub,
        'headless': args.headless,
        'headed': args.headed,
        
        # Utility options
        'test_mode': args.test,
        'function': args.function,
    }
    
    # Set environment variables from config
    if args.verbose:
        os.environ['VERBOSE'] = '1'
    if args.offline:
        os.environ['OFFLINE'] = '1'
    if args.test:
        os.environ['TEST'] = '1'
    if args.interactive:
        os.environ['INTERACTIVE'] = '1'
    
    return config


def validate_args(config: Dict[str, Any]) -> bool:
    """
    Validate the configuration.
    
    Args:
        config: Configuration dictionary
        
    Returns:
        True if valid, False otherwise
    """
    # Add validation logic here
    if config.get('port', 0) < 1 or config.get('port', 0) > 65535:
        print("Error: Port must be between 1 and 65535")
        return False
        
    if config.get('timeout', 0) < 1:
        print("Error: Timeout must be positive")
        return False
        
    return True
