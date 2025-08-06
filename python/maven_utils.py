#!/usr/bin/env python3
"""
Maven and Gradle utilities for project management and dependency handling.
"""

import os
import re
import subprocess
import xml.etree.ElementTree as ET
from typing import Optional, List, Dict, Any
from pathlib import Path
from .system_utils import is_windows
from .output_utils import warn, cmd, err, log


def compute_mvn() -> str:
    """
    Compute the Maven command to use for the project.
    
    Returns:
        str: Maven command (mvn, ./mvnw, or ./mvnw.bat/cmd)
    """
    if Path('./mvnw').is_file() and os.access('./mvnw', os.X_OK):
        return './mvnw'
    elif is_windows():
        if Path('./mvnw.bat').is_file():
            return './mvnw.bat'
        elif Path('./mvnw.cmd').is_file():
            return './mvnw.cmd'
    
    return 'mvn'


def compute_gradle() -> str:
    """
    Compute the Gradle command to use for the project.
    
    Returns:
        str: Gradle command with auto-detect disabled
    """
    gradle_cmd = 'gradle'
    
    if Path('./gradlew').is_file() and os.access('./gradlew', os.X_OK):
        gradle_cmd = './gradlew'
    elif is_windows():
        if Path('./gradlew.bat').is_file():
            gradle_cmd = './gradlew.bat'
        elif Path('./gradlew.cmd').is_file():
            gradle_cmd = './gradlew.cmd'
    
    return f"{gradle_cmd} -Porg.gradle.java.installations.auto-detect=false"


def get_pom_files() -> List[str]:
    """
    Get all pom.xml files in the project, excluding target and bin directories.
    
    Returns:
        List[str]: List of pom.xml file paths
    """
    pom_files = []
    for root, dirs, files in os.walk('.'):
        # Skip target and bin directories
        dirs[:] = [d for d in dirs if d not in ['target', 'bin']]
        
        if 'pom.xml' in files:
            pom_path = Path(root) / 'pom.xml'
            pom_files.append(str(pom_path))
    
    return pom_files


def get_current_property(property_name: str, pom_file: str) -> Optional[str]:
    """
    Read a property value from a pom.xml file.
    
    Args:
        property_name: Name of the property
        pom_file: Path to the pom.xml file
        
    Returns:
        Optional[str]: Property value or None if not found
    """
    try:
        with open(pom_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        pattern = f'<{property_name}>(.+?)</{property_name}>'
        match = re.search(pattern, content)
        if match:
            return match.group(1)
    except Exception:
        pass
    
    return None


def change_maven_property(property_name: str, value: str) -> bool:
    """
    Change a Maven property in all pom.xml files.
    
    Args:
        property_name: Name of the property to change
        value: New value (use 'remove' to delete the property)
        
    Returns:
        bool: True if any changes were made, False otherwise
    """
    test_mode = os.environ.get('TEST', '').strip()
    changes_made = False
    
    for pom_file in get_pom_files():
        current_value = get_current_property(property_name, pom_file)
        
        try:
            with open(pom_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if value == 'remove' and current_value:
                # Remove the property
                pattern = f'\\s*<{property_name}>[^<]+</{property_name}>\\s*'
                new_content = re.sub(pattern, '', content)
                
                if new_content != content:
                    with open(pom_file, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    
                    if not test_mode:
                        warn(f"Removing Maven property {property_name} from {pom_file}")
                    else:
                        cmd(f"## Remove Maven property {property_name} from {pom_file}")
                    changes_made = True
                    
            elif value != 'remove' and value != current_value:
                # Change the property value
                pattern = f'(\\s*<{property_name}>)[^<]+(</{ property_name}>)'
                replacement = f'\\g<1>{value}\\g<2>'
                new_content = re.sub(pattern, replacement, content)
                
                if new_content != content:
                    with open(pom_file, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    
                    if not test_mode:
                        warn(f"Changing Maven property {property_name} from {current_value} -> {value} in {pom_file}")
                    else:
                        cmd(f"## Change Maven property {property_name} from {current_value} -> {value} in {pom_file}")
                    changes_made = True
                    
        except Exception as e:
            err(f"Error changing property {property_name} in {pom_file}: {e}")
    
    return changes_made


def change_maven_block(
    tag: str = "dependency",
    group_id: str = "",
    artifact_id: str = "",
    version: str = "",
    new_group_id: str = "",
    new_artifact_id: str = "",
    extra_content: str = ""
) -> None:
    """
    Change a Maven block (dependency, plugin, etc.) in pom.xml files.
    
    Args:
        tag: XML tag name (default: dependency)
        group_id: Group ID to match
        artifact_id: Artifact ID to match
        version: New version (use 'remove' to delete the block)
        new_group_id: New group ID (optional)
        new_artifact_id: New artifact ID (optional)
        extra_content: Additional content to include
    """
    test_mode = os.environ.get('TEST', '').strip()
    
    if not new_group_id:
        new_group_id = group_id
    if not new_artifact_id:
        new_artifact_id = artifact_id
    
    for pom_file in get_pom_files():
        try:
            with open(pom_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_content = content
            
            if version == 'remove':
                # Remove the entire block
                pattern = (
                    f'\\s*<{tag}>\\s*<groupId>{group_id}</groupId>\\s*'
                    f'<artifactId>{artifact_id}</artifactId>.*?</{tag}>'
                )
                content = re.sub(pattern, '', content, flags=re.DOTALL)
                
                if content != original_content:
                    if not test_mode:
                        warn(f"Remove {tag} {group_id}:{artifact_id}")
                    else:
                        cmd(f"## Remove Maven Block {tag} {group_id}:{artifact_id}")
            else:
                # Update or add version
                # First try to find existing version tag
                version_pattern = (
                    f'(<{tag}>\\s*<groupId>{group_id}</groupId>\\s*'
                    f'<artifactId>{artifact_id}</artifactId>\\s*)<version>[^<]+</version>'
                )
                
                if re.search(version_pattern, content):
                    # Update existing version
                    replacement = f'\\g<1><version>{version}</version>'
                    content = re.sub(version_pattern, replacement, content)
                else:
                    # Add version tag after artifactId
                    no_version_pattern = (
                        f'(<{tag}>\\s*<groupId>{group_id}</groupId>\\s*'
                        f'<artifactId>{artifact_id}</artifactId>)(\\s*)'
                    )
                    replacement = f'\\g<1>\\g<2><version>{version}</version>\\g<2>'
                    content = re.sub(no_version_pattern, replacement, content)
                
                if content != original_content:
                    if not test_mode:
                        warn(f"Change {tag} {group_id}:{artifact_id} {version}")
                    else:
                        cmd(f"## Change Maven Block {tag} {group_id}:{artifact_id} -> {new_group_id}:{new_artifact_id}:{version}")
            
            if content != original_content:
                with open(pom_file, 'w', encoding='utf-8') as f:
                    f.write(content)
                    
        except Exception as e:
            err(f"Error changing Maven block in {pom_file}: {e}")


def get_maven_version(property_name: str) -> Optional[str]:
    """
    Get a property value from any pom.xml file in the project.
    
    Args:
        property_name: Name of the property
        
    Returns:
        Optional[str]: Property value or None if not found
    """
    for pom_file in get_pom_files():
        value = get_current_property(property_name, pom_file)
        if value:
            return value
    return None


def set_version(property_name: str, new_version: str, reset_git: bool = True) -> Optional[str]:
    """
    Set the value of a property in pom files.
    
    Args:
        property_name: Property name to set
        new_version: New version value
        reset_git: Whether to reset git changes first
        
    Returns:
        Optional[str]: The new version if set, None if unchanged
    """
    if reset_git:
        subprocess.run(['git', 'checkout', '-q', '.'], capture_output=True)
    
    if new_version == 'current':
        current = get_maven_version(property_name)
        return current
    
    if change_maven_property(property_name, new_version):
        return new_version
    return None


def get_gradle_version(property_name: str) -> Optional[str]:
    """
    Get the value of a property from gradle.properties or build.gradle.
    
    Args:
        property_name: Name of the property
        
    Returns:
        Optional[str]: Property value or None if not found
    """
    # Check gradle.properties first
    gradle_props = Path('gradle.properties')
    if gradle_props.exists():
        try:
            with open(gradle_props, 'r', encoding='utf-8') as f:
                for line in f:
                    if '=' in line and line.strip().startswith(property_name):
                        return line.split('=', 1)[1].strip()
        except Exception:
            pass
    
    # Check build.gradle
    build_gradle = Path('build.gradle')
    if build_gradle.exists():
        try:
            with open(build_gradle, 'r', encoding='utf-8') as f:
                content = f.read()
                pattern = f'set.*{property_name}.*"([\\d][^"]+)"'
                match = re.search(pattern, content)
                if match:
                    return match.group(1)
        except Exception:
            pass
    
    return None


def set_gradle_version(property_name: str, new_version: str, reset_git: bool = True) -> Optional[str]:
    """
    Set the value of a property in gradle files.
    
    Args:
        property_name: Property name to set
        new_version: New version value
        reset_git: Whether to reset git changes first
        
    Returns:
        Optional[str]: The new version if set, None if unchanged
    """
    if reset_git:
        subprocess.run(['git', 'checkout', '-q', '.'], capture_output=True)
    
    current_version = get_gradle_version(property_name)
    
    if new_version == 'current':
        return current_version
    
    if current_version == new_version:
        return None
    
    test_mode = os.environ.get('TEST', '').strip()
    
    # Update gradle.properties
    gradle_props = Path('gradle.properties')
    if gradle_props.exists():
        try:
            with open(gradle_props, 'r', encoding='utf-8') as f:
                content = f.read()
            
            pattern = f'({property_name}\\s*=\\s*)[^\\n]+'
            new_content = re.sub(pattern, f'\\g<1>{new_version}', content)
            
            if new_content != content:
                with open(gradle_props, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                
                if not test_mode:
                    warn(f"Changing {property_name} to {new_version} in gradle.properties")
                else:
                    cmd(f"## Change {property_name} to {new_version} in gradle.properties")
                return new_version
        except Exception:
            pass
    
    # Update build.gradle
    build_gradle = Path('build.gradle')
    if build_gradle.exists():
        try:
            with open(build_gradle, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Update property setting
            pattern = f'(^.*set.*{property_name}.*?)(\\d[^"]+)(.*$)'
            new_content = re.sub(pattern, f'\\g<1>{new_version}\\g<3>', content, flags=re.MULTILINE)
            
            # Update plugin version
            plugin_pattern = f"(id +'com\\.vaadin' +version +')[\\d\\.]+(')"
            new_content = re.sub(plugin_pattern, f'\\g<1>{new_version}\\g<2>', new_content)
            
            if new_content != content:
                with open(build_gradle, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                
                if not test_mode:
                    warn(f"Changing {property_name} to {new_version} in build.gradle")
                else:
                    cmd(f"## Change {property_name} to {new_version} in build.gradle")
                return new_version
        except Exception:
            pass
    
    return None


def check_tsconfig_modified(log_file: str) -> bool:
    """
    Check whether Flow modified the tsconfig.json file.
    
    Args:
        log_file: Log file to check and append to
        
    Returns:
        bool: True if tsconfig.json was modified
    """
    try:
        with open(log_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if "'tsconfig.json' has been updated" in content:
            # Check git diff
            try:
                result = subprocess.run(['git', 'diff', 'tsconfig.json'], 
                                      capture_output=True, text=True)
                diff_content = result.stdout
                
                result2 = subprocess.run(['git', 'diff', 'types.d.ts'], 
                                       capture_output=True, text=True)
                diff_content += result2.stdout
                
                with open(log_file, 'a', encoding='utf-8') as f:
                    f.write(">>>> PiT: Found tsconfig.json modified\n")
                
                from .output_utils import report_error
                report_error("File 'tsconfig.json' was modified and servlet threw an Exception", diff_content)
                return True
            except Exception:
                pass
    except Exception:
        pass
    
    return False


def check_bundle_not_created(log_file: str) -> bool:
    """
    Check whether an express dev-bundle has been created for the project.
    
    Args:
        log_file: Log file to check
        
    Returns:
        bool: True if dev-bundle is being used, False otherwise
    """
    log("Checking Express Bundle")
    
    try:
        with open(log_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if "A development mode bundle build is not needed" in content:
            log("Using dev-bundle, no need to compile frontend")
            return True
        else:
            from .output_utils import report_out_errors
            report_out_errors(log_file, "Default vaadin-dev-bundle is not used")
            return False
    except Exception:
        return False


def check_no_spring_dependencies() -> bool:
    """
    Check that there are no Spring or Hilla dependencies in the project.
    
    Returns:
        bool: True if no problematic dependencies found
    """
    try:
        mvn = compute_mvn()
        result = subprocess.run([mvn, '-ntp', '-B', 'dependency:tree'], 
                              capture_output=True, text=True)
        
        if result.returncode != 0:
            return False
        
        dependency_tree = result.stdout
        
        # Check for problematic dependencies
        problematic_lines = []
        for line in dependency_tree.split('\n'):
            if re.search(r'spring|hilla', line, re.IGNORECASE):
                if not re.search(r'spring-data-commons|hilla-dev', line):
                    problematic_lines.append(line)
        
        if problematic_lines:
            from .output_utils import report_error
            report_error("There are spring/hilla dependencies", '\n'.join(problematic_lines))
            print('\n'.join(problematic_lines))
            return False
        
        # Check for allowed dependencies
        allowed_lines = []
        for line in dependency_tree.split('\n'):
            if re.search(r'spring-data-commons|hilla-dev', line):
                allowed_lines.append(line)
        
        if allowed_lines:
            from .output_utils import report_error
            report_error("There is spring-data-commons|hilla-dev dependency", '\n'.join(allowed_lines))
            print('\n'.join(allowed_lines))
            return True
        
        log("No Spring/Hilla dependencies found")
        return True
        
    except Exception as e:
        err(f"Error checking dependencies: {e}")
        return False


def check_vite_compilation_warnings(log_file: str):
    """
    Check for Vite compilation warnings in the log file.
    
    Args:
        log_file: Path to the log file to check
    """
    log("Checking Vite Compilation Warnings")
    
    try:
        with open(log_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if "DevServerOutputTracker   : Failed" in content:
            from .output_utils import report_out_errors
            report_out_errors(log_file, "Vite Compilation Warnings")
    except Exception:
        pass


def add_repo_to_pom(repo_url: str):
    """
    Add a repository to pom.xml files.
    
    Args:
        repo_url: Repository URL to add
    """
    for pom_file in get_pom_files():
        try:
            with open(pom_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if repo_url in content:
                continue
            
            original_content = content
            
            # Add repositories and pluginRepositories sections
            for repo_type in ['repositor', 'pluginRepositor']:
                section_name = f"{repo_type}ies"
                
                if f"<{section_name}>" not in content:
                    # Add entire section before </project>
                    repo_section = f"""    <{section_name}>
        <{repo_type}y>
            <id>v</id>
            <url>{repo_url}</url>
        </{repo_type}y>
    </{section_name}>
"""
                    content = content.replace('</project>', f'{repo_section}</project>')
                else:
                    # Add repository to existing section
                    pattern = f'(\\s*)(<{section_name}>)'
                    replacement = f'\\g<1>\\g<2>\n\\g<1>    <{repo_type}y><id>v</id><url>{repo_url}</url></{repo_type}y>'
                    content = re.sub(pattern, replacement, content)
            
            if content != original_content:
                with open(pom_file, 'w', encoding='utf-8') as f:
                    f.write(content)
                
                test_mode = os.environ.get('TEST', '').strip()
                if not test_mode:
                    warn(f"Adding {repo_url} repository to {pom_file}")
                else:
                    cmd(f"## Adding {repo_url} repository to {pom_file}")
                    
        except Exception as e:
            err(f"Error adding repository to {pom_file}: {e}")


def add_repo_to_gradle(repo_url: str):
    """
    Add a repository to Gradle files.
    
    Args:
        repo_url: Repository URL to add
    """
    # Add to settings.gradle
    settings_gradle = Path('settings.gradle')
    if settings_gradle.exists():
        try:
            with open(settings_gradle, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if repo_url not in content:
                plugin_management = f'''pluginManagement {{
  repositories {{
    maven {{ url = "{repo_url}" }}
    gradlePluginPortal()
  }}
}}
'''
                content = plugin_management + content
                
                with open(settings_gradle, 'w', encoding='utf-8') as f:
                    f.write(content)
                
                test_mode = os.environ.get('TEST', '').strip()
                if not test_mode:
                    warn(f"Adding {repo_url} repository to settings.gradle")
                else:
                    cmd(f"## Adding {repo_url} repository to settings.gradle")
        except Exception:
            pass
    
    # Add to build.gradle
    build_gradle = Path('build.gradle')
    if build_gradle.exists():
        try:
            with open(build_gradle, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if repo_url not in content:
                pattern = r'(repositories\s*\{)'
                replacement = f'\\g<1>\n    maven {{ url "{repo_url}" }}'
                content = re.sub(pattern, replacement, content)
                
                with open(build_gradle, 'w', encoding='utf-8') as f:
                    f.write(content)
                
                test_mode = os.environ.get('TEST', '').strip()
                if not test_mode:
                    warn(f"Adding {repo_url} repository to build.gradle")
                else:
                    cmd(f"## Adding {repo_url} repository to build.gradle")
        except Exception:
            pass
