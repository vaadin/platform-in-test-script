"""
Starter and demo management utilities.
Converted from lib-start.sh and lib-demos.sh
"""

import os
import re
import zipfile
import subprocess
from pathlib import Path
from typing import Optional, Tuple, Dict, Any
from urllib.parse import urlparse

from .system_utils import download_file, is_windows, is_mac, is_linux
from .output_utils import log, err, warn
from .process_utils import run_command
from .maven_utils import compute_mvn, compute_gradle
from .java_utils import compute_npm
from .vaadin_utils import validate_token


class StarterManager:
    """Manages downloading and generating Vaadin starters."""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.verbose = config.get('verbose', False)
        self.offline = config.get('offline', False)
        self.test_mode = config.get('test_mode', False)
        
    def init_git(self, directory: str = '.') -> bool:
        """
        Initialize a git repository in the current starter project if not already initialized.
        
        Args:
            directory: Directory to initialize git in
            
        Returns:
            True if successful, False otherwise
        """
        git_dir = Path(directory) / '.git'
        if git_dir.exists():
            return True
            
        try:
            os.chdir(directory)
            
            # Initialize git repo
            if run_command("Initialize git repo", "git init -q") != 0:
                return False
                
            # Configure user if not set
            result = subprocess.run(['git', 'config', 'user.email'], 
                                  capture_output=True, text=True)
            if not result.stdout.strip():
                run_command("Set git user email", 
                          'git config user.email "vaadin-bot@vaadin.com"')
                          
            result = subprocess.run(['git', 'config', 'user.name'], 
                                  capture_output=True, text=True)
            if not result.stdout.strip():
                run_command("Set git user name", 
                          'git config user.name "Vaadin Bot"')
            
            # Disable warning about ignored files
            run_command("Configure git", 
                      "git config advice.addIgnoredFile false")
            
            # Add all files and make initial commit
            run_command("Add files to git", "git add .")
            run_command("Initial commit", "git commit -q -m 'First commit' -a")
            
            return True
            
        except Exception as e:
            err(f"Failed to initialize git: {e}")
            return False
    
    def download_starter(self, preset: str, directory: str) -> bool:
        """
        Download a starter from start.vaadin.com with the given preset.
        
        Args:
            preset: Preset name or multiple presets joined with '_'
            directory: Directory to extract the starter to
            
        Returns:
            True if successful, False otherwise
        """
        presets = preset.split('_')
        preset_params = '&'.join([f'preset={p}' for p in presets])
        url = f"https://start.vaadin.com/dl?{preset_params}&projectName={preset}"
        zip_file = f"{preset}.zip"
        
        try:
            # Download the starter zip
            log(f"Downloading starter: {preset}")
            if not download_file(url, zip_file, silent=not self.verbose):
                err(f"Failed to download starter from: {url}")
                return False
            
            # Extract the zip file
            log(f"Extracting starter: {preset}")
            with zipfile.ZipFile(zip_file, 'r') as zip_ref:
                zip_ref.extractall('.')
            
            # Clean up zip file
            os.remove(zip_file)
            
            # Change to the directory
            os.chdir(directory)
            
            return True
            
        except Exception as e:
            err(f"Failed to download starter {preset}: {e}")
            return False
    
    def generate_starter(self, name: str) -> bool:
        """
        Generate a starter using Maven archetypes or Hilla CLI.
        
        Args:
            name: Name of the starter to generate
            
        Returns:
            True if successful, False otherwise
        """
        mvn_cmd = compute_mvn()
        
        # Determine the command based on starter type
        if name.endswith('spring'):
            cmd = (f"{mvn_cmd} -ntp -q -B archetype:generate "
                  f"-DarchetypeGroupId=com.vaadin "
                  f"-DarchetypeArtifactId=vaadin-archetype-spring-application "
                  f"-DarchetypeVersion=LATEST "
                  f"-DgroupId=com.vaadin.starter "
                  f"-DartifactId={name}")
        elif name.startswith('archetype'):
            cmd = (f"{mvn_cmd} -ntp -q -B archetype:generate "
                  f"-DarchetypeGroupId=com.vaadin "
                  f"-DarchetypeArtifactId=vaadin-archetype-application "
                  f"-DarchetypeVersion=LATEST "
                  f"-DgroupId=com.vaadin.starter "
                  f"-DartifactId={name}")
        elif name == 'vaadin-quarkus':
            cmd = (f"{mvn_cmd} -ntp -q -B io.quarkus.platform:quarkus-maven-plugin:create "
                  f"-Dextensions=vaadin -DwithCodestart "
                  f"-DprojectGroupId=com.vaadin.starter "
                  f"-DprojectArtifactId={name}")
        elif name.endswith('-cli'):
            node_path, npm_cmd = compute_npm()
            if name.startswith('hilla-') and name.endswith('-cli'):
                cmd = f"npx @hilla/cli init --react {name}"
            else:
                err(f"Unknown CLI starter type: {name}")
                return False
        else:
            err(f"Unknown starter type: {name}")
            return False
        
        # Run the generation command
        if run_command(f"Generating {name}", cmd) != 0:
            return False
        
        # Change to the generated directory
        try:
            os.chdir(name)
            return True
        except OSError as e:
            err(f"Failed to change to directory {name}: {e}")
            return False


class DemoManager:
    """Manages checking out and working with demo repositories."""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.verbose = config.get('verbose', False)
        self.offline = config.get('offline', False)
        self.test_mode = config.get('test_mode', False)
        self.git_ssh = config.get('git_ssh', False)
        
    def parse_demo_spec(self, demo_spec: str) -> Tuple[str, Optional[str], Optional[str]]:
        """
        Parse a demo specification into repo, branch, and folder.
        
        Format: repo[:branch][/folder]
        
        Args:
            demo_spec: Demo specification string
            
        Returns:
            Tuple of (repo, branch, folder)
        """
        parts = demo_spec.split(':')
        repo = parts[0]
        branch = parts[1] if len(parts) > 1 else None
        
        # Handle folder specification
        folder = None
        if '/' in repo:
            repo_parts = repo.split('/')
            if len(repo_parts) >= 3:
                folder = '/' + repo_parts[2]
                repo = '/'.join(repo_parts[:2])
        
        return repo, branch, folder
    
    def get_git_repo(self, demo_name: str) -> str:
        """
        Get the full GitHub repository path for a demo.
        
        Args:
            demo_name: Name of the demo
            
        Returns:
            Full repository path (e.g., 'vaadin/demo-name')
        """
        repo, _, _ = self.parse_demo_spec(demo_name)
        
        if '/' in repo:
            return repo
        else:
            return f"vaadin/{repo}"
    
    def checkout_demo(self, demo_spec: str, target_dir: Optional[str] = None) -> bool:
        """
        Checkout a demo from GitHub.
        
        Args:
            demo_spec: Demo specification (repo[:branch][/folder])
            target_dir: Target directory to checkout to
            
        Returns:
            True if successful, False otherwise
        """
        repo, branch, folder = self.parse_demo_spec(demo_spec)
        full_repo = self.get_git_repo(demo_spec)
        
        work_dir = repo + (folder or '')
        if target_dir:
            work_dir = target_dir
        
        # Construct git URL
        git_base = os.environ.get('GITBASE', 'https://github.com/')
        git_url = f"{git_base}{full_repo}.git"
        
        # Add authentication token if available and validate access
        if validate_token(full_repo):
            ghtk = os.environ.get('GHTK') or os.environ.get('GITHUB_TOKEN')
            if ghtk:
                git_url = git_url.replace('https://', f'https://{ghtk}@')
        
        # Use SSH if requested
        if self.git_ssh:
            git_url = f"git@github.com:{full_repo}.git"
        
        try:
            quiet_flag = '-q' if not self.verbose else ''
            
            # Remove existing directory or checkout fresh
            if not self.offline or not Path(work_dir).exists():
                if Path(repo).exists():
                    import shutil
                    import stat
                    
                    def handle_remove_readonly(func, path, exc):
                        """Handle read-only files on Windows."""
                        os.chmod(path, stat.S_IWRITE)
                        func(path)
                    
                    try:
                        log(f"Removing existing {repo}")
                        if is_windows():
                            shutil.rmtree(repo, onerror=handle_remove_readonly)
                        else:
                            shutil.rmtree(repo)
                    except Exception as e:
                        warn(f"Could not remove {repo}: {e}")
                        return False
                
                if run_command(f"Cloning {full_repo}", 
                             f"git clone {quiet_flag} {git_url}") != 0:
                    return False
                    
                os.chdir(work_dir)
            else:
                os.chdir(work_dir)
                if run_command(f"Resetting local changes in {full_repo}",
                             f"git reset {quiet_flag} --hard HEAD") != 0:
                    return False
                    
                # Clean .out files using cross-platform approach
                import glob
                out_files = glob.glob("*.out")
                for f in out_files:
                    try:
                        os.remove(f)
                    except:
                        pass
            
            # Checkout specific branch if specified
            if branch:
                if run_command(f"Checking out branch: {branch}",
                             f"git checkout {quiet_flag} {branch}") != 0:
                    return False
            
            return True
            
        except Exception as e:
            err(f"Failed to checkout demo {demo_spec}: {e}")
            return False
    
    def get_demo_info(self, demo_spec: str) -> Dict[str, str]:
        """
        Get information about a demo.
        
        Args:
            demo_spec: Demo specification
            
        Returns:
            Dictionary with demo information
        """
        repo, branch, folder = self.parse_demo_spec(demo_spec)
        full_repo = self.get_git_repo(demo_spec)
        
        return {
            'name': demo_spec,
            'repo': repo,
            'full_repo': full_repo,
            'branch': branch or 'main',
            'folder': folder or '',
            'work_dir': repo + (folder or '')
        }


def run_starter(starter_name: str, target_dir: str, port: int, 
               version: Optional[str] = None, offline: bool = False) -> int:
    """
    Generate and test a starter application.
    """
    config = {
        'verbose': os.environ.get('VERBOSE') == '1',
        'offline': offline,
        'test_mode': os.environ.get('TEST') == '1'
    }
    
    original_dir = os.getcwd()
    
    try:
        # Generate starter
        starter_mgr = StarterManager(config)
        if not starter_mgr.generate_starter(starter_name, target_dir, version):
            err(f"Failed to generate starter {starter_name}")
            return 1
        
        # Change to starter directory
        work_dir = Path(target_dir) / starter_name
        if not work_dir.exists():
            err(f"Starter directory does not exist: {work_dir}")
            return 1
        
        os.chdir(work_dir)
        
        # Apply patches BEFORE validation
        from .patch_utils import PatchManager
        patch_mgr = PatchManager()
        patch_version = version or 'latest'
        if not patch_mgr.apply_patches(starter_name, patch_version):
            warn(f"Some patches failed to apply for {starter_name} version {patch_version}")
        
        # Determine build tool and commands
        build_tool, compile_cmd, run_cmd = _determine_build_commands(starter_name)
        
        # Determine check string based on starter type
        check_string = _determine_check_string(starter_name, build_tool)
        
        log(f"Using build tool: {build_tool}")
        log(f"Compile command: {compile_cmd}")
        log(f"Run command: {run_cmd}")
        log(f"Check string: {check_string}")
        
        # Run validation
        from .validation_utils import ValidationManager
        validation_mgr = ValidationManager()
        success = validation_mgr.run_validations(
            mode='dev',
            version=version or 'latest',
            name=starter_name,
            port=str(port),
            compile_cmd=compile_cmd,
            run_cmd=run_cmd,
            check_string=check_string,
            test_file=None,
            timeout=300,
            interactive=False,
            skip_tests=config.get('test_mode', False),
            skip_playwright=config.get('test_mode', False),
            verbose=config.get('verbose', False),
            offline=offline,
            test_mode=config.get('test_mode', False)
        )
        
        if success:
            log(f"Starter {starter_name} processed successfully")
            return 0
        else:
            err(f"Starter {starter_name} validation failed")
            return 1
        
    except Exception as e:
        err(f"Failed to run starter {starter_name}: {e}")
        return 1
    finally:
        os.chdir(original_dir)


def run_demo(demo_name: str, target_dir: str, port: int,
            version: Optional[str] = None, offline: bool = False) -> int:
    """
    Run a complete demo test.
    
    Args:
        demo_name: Name of the demo to test
        target_dir: Directory to work in  
        port: Port to run the server on
        version: Vaadin version to test
        offline: Whether to use offline mode
        
    Returns:
        Exit code (0 for success)
    """
    config = {
        'verbose': os.environ.get('VERBOSE') == '1',
        'offline': offline,
        'test_mode': os.environ.get('TEST') == '1'
    }
    
    demo_mgr = DemoManager(config)
    
    # Create target directory  
    os.makedirs(target_dir, exist_ok=True)
    original_dir = os.getcwd()
    
    try:
        os.chdir(target_dir)
        
        # Checkout the demo
        if not demo_mgr.checkout_demo(demo_name):
            return 1
        
        # Get demo info for validation
        demo_info = demo_mgr.get_demo_info(demo_name)
        work_dir = demo_info['work_dir']
        
        # Change to the demo directory
        if os.path.exists(work_dir):
            os.chdir(work_dir)
        
        # Import validation modules when needed to avoid circular imports
        from .validation_utils import ValidationManager
        from .patch_utils import PatchManager
        
        # Apply patches if needed
        if version:
            patch_mgr = PatchManager()
            patch_mgr.apply_patches(demo_name, version)
        
        # Run validation process
        validation_mgr = ValidationManager()
        
        # Determine build tool and commands using smart detection
        build_tool, compile_cmd, run_cmd = _determine_build_commands(demo_name)
        
        # Determine check string based on demo type
        check_string = _determine_check_string(demo_name, build_tool)
        
        log(f"Using build tool: {build_tool}")
        log(f"Compile command: {compile_cmd}")
        log(f"Run command: {run_cmd}")
        log(f"Check string: {check_string}")
        
        # Run the validation process
        success = validation_mgr.run_validations(
            mode='dev',  # Default to dev mode
            version=version or 'latest',
            name=demo_name,
            port=str(port),
            compile_cmd=compile_cmd,
            run_cmd=run_cmd,
            check_string=check_string,
            test_file=None,  # Could be determined based on demo
            timeout=600,  # Increased timeout for frontend bundle build
            interactive=False,
            skip_tests=config.get('test_mode', False),
            skip_playwright=config.get('test_mode', False),
            verbose=config.get('verbose', False),
            offline=offline,
            test_mode=config.get('test_mode', False)
        )
        
        if success:
            log(f"Demo {demo_name} processed successfully")
            return 0
        else:
            err(f"Demo {demo_name} validation failed")
            return 1
        
    except Exception as e:
        err(f"Failed to run demo {demo_name}: {e}")
        return 1
    finally:
        os.chdir(original_dir)


def _determine_build_commands(app_name: str) -> Tuple[str, str, str]:
    """
    Determine the appropriate build tool and commands for an application.
    
    Returns:
        Tuple of (build_tool, compile_cmd, run_cmd)
    """
    # Check if Gradle project
    if Path('build.gradle').exists() or Path('build.gradle.kts').exists():
        gradle_cmd = compute_gradle()
        return ('gradle', f"{gradle_cmd} compileJava", f"{gradle_cmd} appRun")
    
    # Maven project
    mvn_cmd = compute_mvn()
    
    # Check pom.xml content to determine the right plugin
    if Path('pom.xml').exists():
        try:
            with open('pom.xml', 'r', encoding='utf-8') as f:
                pom_content = f.read()
            
            # Check for different Maven plugins
            if 'jetty-maven-plugin' in pom_content or 'jetty-ee10-maven-plugin' in pom_content:
                return ('maven', f"{mvn_cmd} compile", f"{mvn_cmd} jetty:run")
            elif 'tomcat7-maven-plugin' in pom_content:
                return ('maven', f"{mvn_cmd} compile", f"{mvn_cmd} tomcat7:run")
            elif 'spring-boot-maven-plugin' in pom_content:
                return ('maven', f"{mvn_cmd} compile", f"{mvn_cmd} spring-boot:run")
            elif 'exec-maven-plugin' in pom_content:
                return ('maven', f"{mvn_cmd} compile", f"{mvn_cmd} exec:java")
            
        except Exception as e:
            warn(f"Error reading pom.xml: {e}")
    
    # Default fallback - many Vaadin demos use Jetty
    return ('maven', f"{mvn_cmd} compile", f"{mvn_cmd} jetty:run")


def _determine_check_string(app_name: str, build_tool: str) -> str:
    """
    Determine the appropriate check string to wait for during startup.
    
    Args:
        app_name: Name of the application
        build_tool: Build tool being used
        
    Returns:
        String to search for in the output
    """
    # Spring Boot applications
    spring_boot_patterns = [
        'spring-boot', 'starter-', 'boot-'
    ]
    
    if any(pattern in app_name.lower() for pattern in spring_boot_patterns):
        return "Started.*in.*seconds"
    
    # Jetty applications (common pattern for Jetty startup)
    jetty_patterns = [
        'jetty', 'spreadsheet', 'addressbook', 'demo'
    ]
    
    if any(pattern in app_name.lower() for pattern in jetty_patterns):
        return "Started oejs.Server"
    
    # Gradle applications
    if build_tool == 'gradle':
        return "Server startup"
    
    # Default for Maven/Jetty
    return "Started Server"
