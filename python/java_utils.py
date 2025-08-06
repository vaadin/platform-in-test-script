#!/usr/bin/env python3
"""
Java runtime and tool management utilities.
"""

import os
import subprocess
import tempfile
import tarfile
import zipfile
import shutil
from pathlib import Path
from typing import Tuple, Optional
from .system_utils import is_linux, is_mac, is_windows, download_file
from .output_utils import warn, log, cmd, err
from .process_utils import run_command


# Global variables to store original environment
_original_path = None
_original_java_home = None


def compute_npm() -> Tuple[str, str]:
    """
    Compute npm command paths, preferring Vaadin's internal Node.js if available.
    
    Returns:
        Tuple[str, str]: (node_path, npm_command)
    """
    vaadin_node = Path.home() / '.vaadin' / 'node'
    vaadin_npm = vaadin_node / 'lib' / 'node_modules' / 'npm' / 'bin' / 'npm-cli.js'
    
    # Default to system npm
    npm_path = shutil.which('npm')
    npx_path = shutil.which('npx')
    node_path = shutil.which('node')
    
    npm_command = f"'{npm_path}'" if npm_path else 'npm'
    
    # Check for Vaadin's internal Node.js
    vaadin_node_bin = vaadin_node / 'bin' / 'node'
    if is_windows():
        vaadin_node_bin = vaadin_node / 'bin' / 'node.exe'
    
    if vaadin_node_bin.exists() and vaadin_npm.exists():
        node_path = str(vaadin_node_bin)
        npm_command = f"'{node_path}' '{vaadin_npm}'"
        
        # Update PATH to include Vaadin's node
        vaadin_bin = str(vaadin_node / 'bin')
        current_path = os.environ.get('PATH', '')
        if vaadin_bin not in current_path:
            os.environ['PATH'] = f"{vaadin_bin}{os.pathsep}{current_path}"
    
    return str(node_path) if node_path else 'node', npm_command


def install_jbr_runtime() -> bool:
    """
    Install JetBrains Runtime for HotSwap testing.
    
    Returns:
        bool: True if successful, False otherwise
    """
    global _original_path, _original_java_home
    
    # HotSwap Agent and JBR versions
    hotswap_version = "2.0.1"
    jbr_version = "21.0.5"
    jbr_build = "b631.16"
    
    hotswap_url = f"https://github.com/HotswapProjects/HotswapAgent/releases/download/RELEASE-{hotswap_version}/hotswap-agent-{hotswap_version}.jar"
    jbr_base_url = "https://cache-redirector.jetbrains.com/intellij-jbr"
    
    test_mode = os.environ.get('TEST', '').strip()
    if not test_mode:
        warn("Installing JBR for hotswap testing")
    
    # Determine JBR URL based on OS
    if is_linux():
        jbr_url = f"{jbr_base_url}/jbr-{jbr_version}-linux-x64-{jbr_build}.tar.gz"
    elif is_mac():
        jbr_url = f"{jbr_base_url}/jbr-{jbr_version}-osx-x64-{jbr_build}.tar.gz"
    elif is_windows():
        jbr_url = f"{jbr_base_url}/jbr-{jbr_version}-windows-x64-{jbr_build}.tar.gz"
    else:
        err("Unsupported operating system for JBR installation")
        return False
    
    temp_dir = Path(tempfile.gettempdir())
    jbr_archive = temp_dir / 'JBR.tgz'
    jbr_dir = temp_dir / 'jbr'
    
    # Download JBR if not already present
    if not jbr_archive.exists():
        if not download_file(jbr_url, str(jbr_archive), silent=False):
            return False
    
    # Extract JBR if not already extracted
    if not jbr_dir.exists():
        jbr_dir.mkdir(parents=True, exist_ok=True)
        try:
            with tarfile.open(jbr_archive, 'r:gz') as tar:
                # Extract with strip-components=1 equivalent
                members = tar.getmembers()
                for member in members:
                    if '/' in member.name:
                        member.name = '/'.join(member.name.split('/')[1:])
                        if member.name:  # Skip empty names
                            tar.extract(member, jbr_dir)
            
            if not test_mode:
                log("Extracted JBR")
            else:
                cmd("## Extracting JBR")
        except Exception as e:
            err(f"Error extracting JBR: {e}")
            return False
    
    # Set Java path
    if not set_java_path(str(jbr_dir)):
        return False
    
    # Install HotSwap Agent
    java_home = os.environ.get('JAVA_HOME')
    if java_home:
        hotswap_dir = Path(java_home) / 'lib' / 'hotswap'
        hotswap_jar = hotswap_dir / 'hotswap-agent.jar'
        
        if not hotswap_jar.exists():
            hotswap_dir.mkdir(parents=True, exist_ok=True)
            if download_file(hotswap_url, str(hotswap_jar), silent=False):
                if not test_mode:
                    log(f"Installed {hotswap_jar}")
            else:
                return False
        
        # Set HotSwap options
        os.environ['HOT'] = "-XX:+AllowEnhancedClassRedefinition -XX:HotswapAgent=fatjar"
    
    return True


def install_jdk_runtime(version: str) -> bool:
    """
    Install a specific version of OpenJDK.
    
    Args:
        version: Java version (e.g., "17", "21", "23")
        
    Returns:
        bool: True if successful, False otherwise
    """
    global _original_path, _original_java_home
    
    if not version:
        return False
    
    base_url = "https://download.oracle.com/java"
    
    # Determine OS-specific parameters
    if is_linux():
        os_suffix = "linux-x64"
        ext = "tar.gz"
    elif is_mac():
        os_suffix = "macos-x64"
        ext = "tar.gz"
    elif is_windows():
        os_suffix = "windows-x64"
        ext = "zip"
    else:
        err("Unsupported operating system for JDK installation")
        return False
    
    # Version-specific adjustments
    if version == "18":
        actual_version = "18.0.1"
        path_segment = "archive"
    elif version == "17":
        actual_version = "17.0.12"
        path_segment = "archive"
    else:
        actual_version = version
        path_segment = "latest"
    
    tar_file = f"jdk-{actual_version}_{os_suffix}_bin.{ext}"
    temp_dir = Path(tempfile.gettempdir())
    archive_path = temp_dir / tar_file
    extract_dir = temp_dir / f"jdk-{version}"
    
    jdk_url = f"{base_url}/{version}/{path_segment}/{tar_file}"
    
    # Download JDK if not already present
    if not archive_path.exists():
        if not download_file(jdk_url, str(archive_path), silent=False):
            return False
    
    # Remove existing extraction directory
    if extract_dir.exists():
        shutil.rmtree(extract_dir)
    
    extract_dir.mkdir(parents=True, exist_ok=True)
    
    # Extract archive
    try:
        if ext == "zip":
            with zipfile.ZipFile(archive_path, 'r') as zip_ref:
                zip_ref.extractall(extract_dir)
        else:
            with tarfile.open(archive_path, 'r:gz') as tar:
                tar.extractall(extract_dir)
        
        test_mode = os.environ.get('TEST', '').strip()
        if not test_mode:
            log(f"Extracted JDK-{version}")
        else:
            cmd(f"## Extracting JDK-{version}")
    except Exception as e:
        err(f"Error extracting JDK: {e}")
        return False
    
    return set_java_path(str(extract_dir))


def set_java_path(java_dir: str) -> bool:
    """
    Set JAVA_HOME and update PATH for the specified Java installation.
    
    Args:
        java_dir: Path to the Java installation directory
        
    Returns:
        bool: True if successful, False otherwise
    """
    global _original_path, _original_java_home
    
    # Store original values if not already stored
    if _original_path is None:
        _original_path = os.environ.get('PATH', '')
    if _original_java_home is None:
        _original_java_home = os.environ.get('JAVA_HOME', '')
    
    # Find the actual Java home (some distributions have a 'Home' subdirectory)
    java_path = Path(java_dir)
    home_dir = java_path / 'Home'
    
    if home_dir.exists():
        java_home = str(home_dir)
    else:
        java_home = java_dir
    
    java_bin = Path(java_home) / 'bin'
    if not java_bin.exists():
        err(f"Java bin directory not found: {java_bin}")
        return False
    
    test_mode = os.environ.get('TEST', '').strip()
    if not test_mode:
        log(f"Setting JAVA_HOME={java_home} PATH={java_bin}:$PATH")
    else:
        cmd(f"## Setting JAVA_HOME={java_home} PATH={java_bin}:$PATH")
    
    # Update environment
    os.environ['JAVA_HOME'] = java_home
    current_path = os.environ.get('PATH', '')
    os.environ['PATH'] = f"{java_bin}{os.pathsep}{current_path}"
    
    return True


def unset_java_path():
    """Restore original Java environment variables."""
    global _original_path, _original_java_home
    
    test_mode = os.environ.get('TEST', '').strip()
    
    if _original_java_home is not None:
        if not test_mode:
            warn(f"Un-setting PATH and JAVA_HOME ({os.environ.get('JAVA_HOME', '')})")
        else:
            cmd(f"## Un-setting PATH and JAVA_HOME ({os.environ.get('JAVA_HOME', '')})")
    
    if _original_path is not None:
        os.environ['PATH'] = _original_path
        _original_path = None
    
    if _original_java_home is not None:
        if _original_java_home:
            os.environ['JAVA_HOME'] = _original_java_home
        else:
            os.environ.pop('JAVA_HOME', None)
        _original_java_home = None
    
    # Remove HotSwap options
    os.environ.pop('HOT', None)


def enable_jbr_autoreload():
    """
    Enable autoreload for JetBrains Runtime by configuring HotSwap Agent.
    """
    # Create hotswap-agent.properties
    properties_path = Path('src/main/resources/hotswap-agent.properties')
    properties_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(properties_path, 'w', encoding='utf-8') as f:
        f.write("autoHotswap=true\n")
    
    test_mode = os.environ.get('TEST', '').strip()
    if not test_mode:
        warn("Disabled Jetty autoreload")
    
    # Disable Jetty scan
    from .maven_utils import change_maven_property
    change_maven_property('scan', '-1')


def compute_java_major() -> Optional[int]:
    """
    Compute the major version of the current Java installation.
    
    Returns:
        Optional[int]: Java major version or None if unable to determine
    """
    try:
        result = subprocess.run(['java', '-version'], capture_output=True, text=True)
        version_output = result.stderr
        
        # Parse version from output like: java version "17.0.1" or openjdk version "11.0.12"
        import re
        match = re.search(r'version "(\d+)', version_output)
        if match:
            return int(match.group(1))
        
        err("Could not determine Java version")
        return None
    except Exception as e:
        err(f"Error getting Java version: {e}")
        return None


def upgrade_gradle(version: str):
    """
    Upgrade Gradle to the specified version.
    
    Args:
        version: Target Gradle version
    """
    if not version:
        return
    
    from .maven_utils import compute_gradle
    gradle_cmd = compute_gradle().split()[0]  # Remove the extra arguments
    
    try:
        # Get current version
        result = subprocess.run([gradle_cmd, '--version'], capture_output=True, text=True)
        if result.returncode != 0:
            return
        
        current_version = None
        for line in result.stdout.split('\n'):
            if line.startswith('Gradle '):
                current_version = line.split()[1]
                break
        
        if current_version and current_version.startswith(version):
            return  # Already at target version
        
        # Upgrade wrapper
        test_mode = os.environ.get('TEST', '').strip()
        if not test_mode:
            warn(f"Upgrading Gradle from {current_version} to {version}")
            subprocess.run([gradle_cmd, 'wrapper', '-q', '--gradle-version', version])
        else:
            cmd(f"## Upgrading Gradle from {current_version} to {version}")
    except Exception as e:
        err(f"Error upgrading Gradle: {e}")


def clean_m2(version: str):
    """
    Clean Vaadin artifacts from local Maven repository for the specified version.
    
    Args:
        version: Version to clean
    """
    if not version or os.environ.get('OFFLINE'):
        return
    
    m2_repo = Path.home() / '.m2' / 'repository' / 'com' / 'vaadin'
    
    if not m2_repo.exists():
        return
    
    # Check if version directories exist
    version_dirs = []
    for vaadin_dir in m2_repo.iterdir():
        if vaadin_dir.is_dir():
            version_dir = vaadin_dir / version
            if version_dir.exists():
                version_dirs.append(version_dir)
    
    if version_dirs:
        warn(f"removing ~/.m2/repository/com/vaadin/*/{version}")
        for version_dir in version_dirs:
            try:
                shutil.rmtree(version_dir)
            except Exception as e:
                warn(f"Failed to remove {version_dir}: {e}")


def disable_launch_browser():
    """Disable automatic browser launch after app startup."""
    from .maven_utils import get_pom_files
    
    for pom_file in get_pom_files():
        pom_dir = Path(pom_file).parent
        app_props = pom_dir / 'src' / 'main' / 'resources' / 'application.properties'
        
        if app_props.exists():
            set_property_in_file(str(app_props), 'vaadin.launch-browser', 'remove')


def enable_pnpm():
    """Enable pnpm for faster package management."""
    app_props_files = list(Path('.').rglob('application.properties'))
    
    for app_props in app_props_files:
        set_property_in_file(str(app_props), 'vaadin.pnpm.enable', 'true')


def enable_vite():
    """Enable Vite for faster frontend builds."""
    app_props_files = list(Path('.').rglob('application.properties'))
    
    for app_props in app_props_files:
        set_property_in_file(str(app_props), 'com.vaadin.experimental.viteForFrontendBuild', 'true')


def set_property_in_file(file_path: str, key: str, value: str):
    """
    Set a property in a properties file.
    
    Args:
        file_path: Path to the properties file
        key: Property key
        value: Property value (use 'remove' to delete the property)
    """
    from .output_utils import warn, cmd
    
    file_path_obj = Path(file_path)
    if not file_path_obj.exists():
        return
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        lines = content.split('\n')
        
        # Find existing property
        current_value = None
        for i, line in enumerate(lines):
            line_stripped = line.strip()
            if line_stripped.startswith(key) and ('=' in line_stripped or ':' in line_stripped):
                if '=' in line_stripped:
                    current_value = line_stripped.split('=', 1)[1]
                else:
                    current_value = line_stripped.split(':', 1)[1]
                
                if value == 'remove':
                    lines[i] = ''  # Remove the line
                else:
                    lines[i] = f"{key}={value}"
                break
        else:
            # Property not found, add it if not removing
            if value != 'remove':
                lines.append(f"{key}={value}")
        
        new_content = '\n'.join(lines)
        
        if new_content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            
            test_mode = os.environ.get('TEST', '').strip()
            if value == 'remove':
                if not test_mode:
                    warn(f"Remove {key} in {file_path}")
                else:
                    cmd(f"## Remove {key} in {file_path}")
            else:
                if not test_mode:
                    warn(f"Change {key} from '{current_value}' to '{value}' in {file_path}")
                else:
                    cmd(f"## Change {key} from '{current_value}' to '{value}' in {file_path}")
    except Exception as e:
        from .output_utils import err
        err(f"Error setting property in {file_path}: {e}")


def is_headless() -> bool:
    """
    Determine whether to run in headless mode.
    
    Returns:
        bool: True if should run headless
    """
    headless_env = os.environ.get('HEADLESS', '').strip()
    verbose_env = os.environ.get('VERBOSE', '').strip()
    
    if headless_env == 'true':
        return True
    
    if headless_env == 'false':
        return False
    
    # Check if we have a display (Linux) or if not in verbose mode
    try:
        if is_linux():
            hostname_result = subprocess.run(['hostname', '-i'], capture_output=True, text=True)
            if hostname_result.returncode == 0 and hostname_result.stdout.strip():
                return True
    except Exception:
        pass
    
    return not verbose_env
