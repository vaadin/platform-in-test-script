#!/usr/bin/env python3
"""
Vaadin-specific utilities for license management, version handling, and project configuration.
"""

import os
import subprocess
import json
import urllib.request
import urllib.error
from pathlib import Path
from typing import Optional, Dict, Any, List
from .output_utils import warn, log, cmd, err, report_error
from .process_utils import run_command


def remove_pro_key():
    """Remove Vaadin Pro key for testing core-only apps."""
    pro_key_path = Path.home() / '.vaadin' / 'proKey'
    
    if pro_key_path.exists():
        backup_path = Path.home() / '.vaadin' / f'proKey-{os.getpid()}'
        
        test_mode = os.environ.get('TEST', '').strip()
        if not test_mode:
            warn("Removing proKey license")
            pro_key_path.rename(backup_path)
        else:
            cmd(f"## mv {pro_key_path} {backup_path}")


def restore_pro_key():
    """Restore Vaadin Pro key that was previously removed."""
    backup_path = Path.home() / '.vaadin' / f'proKey-{os.getpid()}'
    pro_key_path = Path.home() / '.vaadin' / 'proKey'
    
    if not backup_path.exists():
        return
    
    # Check if a new proKey was generated during testing
    existing_content = ""
    if pro_key_path.exists():
        try:
            with open(pro_key_path, 'r', encoding='utf-8') as f:
                existing_content = f.read().strip()
        except Exception:
            pass
    
    test_mode = os.environ.get('TEST', '').strip()
    if not test_mode:
        warn("Restoring proKey license")
        backup_path.rename(pro_key_path)
    else:
        cmd(f"## mv {backup_path} {pro_key_path}")
    
    # Report error if a new proKey was generated during validation
    if not test_mode and existing_content:
        report_error("A proKey was generated while running validation", existing_content)
        return False
    
    return True


def get_version_from_platform(platform_branch: str, module_name: str) -> Optional[str]:
    """
    Get a specific module version from Vaadin platform versions.json.
    
    Args:
        platform_branch: Platform branch or version
        module_name: Module name to get version for
        
    Returns:
        Optional[str]: Module version or None if not found
    """
    try:
        url = f"https://raw.githubusercontent.com/vaadin/platform/{platform_branch}/versions.json"
        
        with urllib.request.urlopen(url) as response:
            content = response.read().decode('utf-8')
        
        # Clean up the JSON content (remove lines starting with digits 1-4)
        lines = content.split('\n')
        cleaned_lines = [line for line in lines if not line.strip().startswith(('1', '2', '3', '4'))]
        cleaned_content = ''.join(cleaned_lines).replace(' ', '').replace('\n', '')
        
        # Parse JSON
        versions_data = json.loads(cleaned_content)
        
        if module_name in versions_data and 'javaVersion' in versions_data[module_name]:
            return versions_data[module_name]['javaVersion']
    except Exception:
        pass
    
    return None


def set_version_from_platform(platform_version: str, module_name: str, property_name: str) -> Optional[str]:
    """
    Set a Maven property version based on the platform's versions.json.
    
    Args:
        platform_version: Platform version
        module_name: Module name in versions.json
        property_name: Property name to set in pom.xml
        
    Returns:
        Optional[str]: The version that was set, or None if unchanged
    """
    if platform_version == 'current':
        return None
    
    # Try to get version from the specified platform version
    version = get_version_from_platform(platform_version, module_name)
    
    # Fallback to master if not found
    if not version:
        version = get_version_from_platform('master', module_name)
    
    if version:
        from .maven_utils import set_version
        return set_version(property_name, version, reset_git=False)
    
    return None


def set_flow_version(platform_version: str) -> Optional[str]:
    """
    Set Flow version based on platform version.
    
    Args:
        platform_version: Platform version
        
    Returns:
        Optional[str]: The Flow version that was set
    """
    return set_version_from_platform(platform_version, 'flow', 'flow.version')


def set_mpr_version(platform_version: str) -> Optional[str]:
    """
    Set MPR (Multiplatform Runtime) version based on platform version.
    
    Args:
        platform_version: Platform version
        
    Returns:
        Optional[str]: The MPR version that was set
    """
    return set_version_from_platform(platform_version, 'mpr-v8', 'mpr.version')


def get_latest_hilla_version(version_input: str) -> str:
    """
    Compute the latest Hilla version based on platform or Hilla version input.
    
    Args:
        version_input: Platform or Hilla version
        
    Returns:
        str: Latest compatible Hilla version
    """
    # If it's already a valid Hilla version, return as-is
    if version_input.startswith('2.') or '-SNAPSHOT' in version_input:
        return version_input
    
    # If it's within supported platform versions, return as-is
    if any(version_input.startswith(v) for v in ['24.4.', '24.5.']):
        return version_input
    
    # Map platform versions to Hilla version patterns
    version_mapping = {
        '24.0.': '2.4.[09]*',
        '24.1.': '2.4.[09]*',
        '24.2.': '2.4.[09]*',
        '24.3.': '2.5.*'
    }
    
    pattern = None
    for platform_prefix, hilla_pattern in version_mapping.items():
        if version_input.startswith(platform_prefix):
            pattern = hilla_pattern
            break
    
    if not pattern:
        return version_input
    
    try:
        # Get releases from GitHub API
        url = "https://api.github.com/repos/vaadin/hilla/releases"
        with urllib.request.urlopen(url) as response:
            releases = json.loads(response.read().decode('utf-8'))
        
        # Find matching versions
        import re
        regex_pattern = pattern.replace('*', r'[0-9]+').replace('.', r'\.')
        
        for release in releases:
            tag_name = release.get('tag_name', '')
            if re.match(f'^{regex_pattern}$', tag_name):
                return tag_name
    except Exception:
        pass
    
    return version_input


def compute_version(project_name: str, version: str) -> str:
    """
    Compute the version to be used for testing based on project type.
    
    Args:
        project_name: Project name/type
        version: Input version
        
    Returns:
        str: Computed version
    """
    if version == 'current':
        return version
    
    if 'hilla' in project_name.lower():
        return get_latest_hilla_version(version)
    
    return version


def compute_property(project_name: str) -> str:
    """
    Compute the property name used for the version in the project.
    
    Args:
        project_name: Project name/type
        
    Returns:
        str: Property name
    """
    project_lower = project_name.lower()
    
    if 'gradle' in project_lower:
        return 'vaadinVersion'
    
    return 'vaadin.version'


def compute_property_after_patch(project_name: str) -> str:
    """
    Compute the property name after applying patches for next release.
    
    Args:
        project_name: Project name/type
        
    Returns:
        str: Property name
    """
    project_lower = project_name.lower()
    
    if 'hilla' in project_lower and 'gradle' in project_lower:
        return 'hillaVersion'
    elif 'gradle' in project_lower:
        return 'vaadinVersion'
    elif any(keyword in project_lower for keyword in ['typescript', 'hilla', 'react', '-lit']):
        return 'hilla.version'
    
    return 'vaadin.version'


def get_mvn_dependency_version(group_id: str, artifact_id: str, extra_args: str = "") -> Optional[str]:
    """
    Get the version of a specific dependency in a Maven project.
    
    Args:
        group_id: Maven group ID
        artifact_id: Maven artifact ID
        extra_args: Extra arguments for mvn command
        
    Returns:
        Optional[str]: Dependency version or None if not found
    """
    if not Path('pom.xml').exists():
        warn("Not a maven project")
        return None
    
    from .maven_utils import compute_mvn
    mvn_cmd = compute_mvn()
    
    try:
        cmd_args = [mvn_cmd, 'dependency:tree']
        if extra_args:
            cmd_args.extend(extra_args.split())
        
        result = subprocess.run(cmd_args, capture_output=True, text=True)
        
        if result.returncode != 0:
            return None
        
        # Parse dependency tree output
        for line in result.stdout.split('\n'):
            if 'INFO' in line and f"{group_id}:{artifact_id}" in line:
                # Extract version from line like: [INFO] +- com.vaadin:vaadin-core:jar:24.4.0:compile
                parts = line.split()
                for part in parts:
                    if f"{group_id}:{artifact_id}" in part:
                        dependency_parts = part.split(':')
                        if len(dependency_parts) >= 4:
                            return dependency_parts[3]
        
        return None
    except Exception as e:
        err(f"Error getting dependency version: {e}")
        return None


def set_mvn_dependency_version(group_id: str, artifact_id: str, version: str, extra_args: str = "") -> bool:
    """
    Set the version of a specific dependency in pom.xml.
    
    Args:
        group_id: Maven group ID
        artifact_id: Maven artifact ID
        version: New version
        extra_args: Extra arguments for mvn command
        
    Returns:
        bool: True if successful, False otherwise
    """
    # Convert version format
    if 'SNAPSHOT' not in version:
        new_version = version.replace('-', '.')
    else:
        new_version = version
    
    current_version = get_mvn_dependency_version(group_id, artifact_id, extra_args)
    if not current_version:
        return False
    
    if current_version != new_version:
        try:
            from .maven_utils import change_block
        except ImportError:
        # Simple fallback implementation
            def change_block(left_pattern, right_pattern, replacement, file_path):
                pass
        
        # Update the dependency version
        try:
            with open('pom.xml', 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Pattern to match the dependency and add/update version
            import re
            pattern = f'(<artifactId>{artifact_id}</artifactId>)(\\s*)(</dependency>)'
            replacement = f'\\g<1>\\g<2><version>{new_version}</version>\\g<2>\\g<3>'
            
            new_content = re.sub(pattern, replacement, content)
            
            if new_content != content:
                with open('pom.xml', 'w', encoding='utf-8') as f:
                    f.write(new_content)
        except Exception:
            pass
        
        # Verify the change
        updated_version = get_mvn_dependency_version(group_id, artifact_id, extra_args)
        if updated_version != new_version:
            err(f"Version mismatch {updated_version} != {new_version}")
            return False
    
    log(f"App is using {group_id}:{artifact_id}:{current_version}")
    return True


def get_repos_from_website() -> List[str]:
    """
    Get all demo repositories available on the Vaadin website.
    
    Returns:
        List[str]: List of repository names
    """
    demos = []
    
    try:
        # Get examples and demos
        examples_url = "https://vaadin.com/examples-and-demos"
        with urllib.request.urlopen(examples_url) as response:
            content = response.read().decode('utf-8')
        
        import re
        examples_matches = re.findall(r'/github\.com/vaadin/([\w\-]+)', content)
        demos.extend(examples_matches)
        
        # Get hello world starters
        starters_url = "https://vaadin.com/hello-world-starters"
        with urllib.request.urlopen(starters_url) as response:
            content = response.read().decode('utf-8')
        
        starters_matches = re.findall(r'/github\.com/vaadin/([\w\-]+)', content)
        demos.extend(starters_matches)
        
    except Exception:
        pass
    
    # Remove duplicates and sort
    return sorted(list(set(demos)))


def validate_token(repo: str) -> bool:
    """
    Validate GitHub token and repository access.
    
    Args:
        repo: Repository name in format 'owner/repo'
        
    Returns:
        bool: True if token is valid and has access, False otherwise
    """
    github_token = os.environ.get('GHTK')
    if not github_token:
        return False
    
    try:
        # Validate token
        headers = {'Authorization': f'Bearer {github_token}'}
        user_req = urllib.request.Request('https://api.github.com/user', headers=headers)
        
        with urllib.request.urlopen(user_req) as response:
            user_data = json.loads(response.read().decode('utf-8'))
        
        login = user_data.get('login')
        if not login:
            err(f"Invalid GHTK, {login}")
            return False
        
        log(f"Using GH {login}")
        
        # Check repository access
        repo_req = urllib.request.Request(f'https://api.github.com/repos/{repo}', headers=headers)
        
        with urllib.request.urlopen(repo_req) as response:
            repo_data = json.loads(response.read().decode('utf-8'))
        
        permissions = repo_data.get('permissions', {})
        if not permissions.get('pull'):
            err(f"No pull access {permissions.get('pull')}")
            return False
        
        return True
        
    except Exception as e:
        err(f"Error validating token: {e}")
        return False


def add_prereleases():
    """Add Vaadin pre-releases repository to project files."""
    repo_url = "https://maven.vaadin.com/vaadin-prereleases"
    
    if Path('pom.xml').exists():
        from .maven_utils import add_repo_to_pom
        add_repo_to_pom(repo_url)
    
    if Path('build.gradle').exists():
        from .maven_utils import add_repo_to_gradle
        add_repo_to_gradle(repo_url)


def add_spring_release_repo():
    """Add Spring release repository to project files."""
    repo_url = "https://repo.spring.io/milestone/"
    
    if Path('pom.xml').exists():
        from .maven_utils import add_repo_to_pom
        add_repo_to_pom(repo_url)
    
    if Path('build.gradle').exists():
        from .maven_utils import add_repo_to_gradle
        add_repo_to_gradle(repo_url)


def enable_snapshots():
    """Enable snapshots for pre-release repositories in pom.xml."""
    from .maven_utils import get_pom_files
    
    def change_block(left_pattern, right_pattern, replacement, file_path):
        """Simple implementation for changing blocks in files."""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            import re
            pattern = f'{left_pattern}.*?{right_pattern}'
            new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
            
            if new_content != content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
        except Exception:
            pass
    
    for pom_file in get_pom_files():
        try:
            # Enable snapshots in existing snapshots sections
            change_block(
                '<snapshots>\\s+<enabled>',
                '</enabled>\\s+</snapshots>',
                '<snapshots><enabled>true</enabled></snapshots>',
                pom_file
            )
        except Exception:
            pass
