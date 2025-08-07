#!/usr/bin/env python3
"""
Patch utilities for Platform Integration Test (PiT).
Migrated from scripts/pit/lib/lib-patch*.sh files.
Provides version-specific patches and application-specific workarounds.
"""

import os
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Optional, Dict, List, Tuple
import logging

# Use basic subprocess and system functions to avoid import issues
import subprocess
import platform

logger = logging.getLogger(__name__)

class PatchManager:
    """Manages version-specific patches and application-specific workarounds."""
    
    def __init__(self):
        # Java version downgrade mappings
        self.java_version_downgrades = {
            '23': '21',
            '22': '21', 
            '21': '17',
            '20': '17',
            '19': '17',
            '18': '17',
            '17': '11',
            '16': '11',
            '15': '11',
            '14': '11',
            '13': '11',
            '12': '11',
            '11': '8'
        }
        
        # Version-specific patches
        self.version_patches = {
            '24.4': self._apply_v24_4_patches,
            '24.5': self._apply_v24_5_patches,
            '23.3': self._apply_v23_3_patches,
            '23.2': self._apply_v23_2_patches,
            '14.11': self._apply_v14_11_patches
        }
    
    def apply_patches(self, app_name: str, version: str) -> bool:
        """
        Apply all relevant patches for the given app and version.
        
        Args:
            app_name: Name of the application/starter
            version: Platform version (e.g., '24.4', '23.3')
            
        Returns:
            True if patches applied successfully, False otherwise
        """
        try:
            logger.info(f"Applying patches for {app_name} version {version}")
            
            # Apply version-specific patches
            if version in self.version_patches:
                if not self.version_patches[version](app_name):
                    logger.error(f"Failed to apply version patches for {version}")
                    return False
            
            # Apply app-specific patches
            if not self._apply_app_specific_patches(app_name, version):
                logger.error(f"Failed to apply app-specific patches for {app_name}")
                return False
            
            # Apply Java version downgrade if needed
            if not self._apply_java_downgrade(app_name, version):
                logger.error(f"Failed to apply Java downgrade for {app_name}")
                return False
            
            logger.info(f"Successfully applied all patches for {app_name} version {version}")
            return True
            
        except Exception as e:
            logger.error(f"Error applying patches for {app_name} version {version}: {e}")
            return False
    
    def _apply_v24_4_patches(self, app_name: str) -> bool:
        """Apply patches specific to version 24.4."""
        try:
            # Replace deprecated Spring Boot version property
            if self._file_exists('pom.xml'):
                self._replace_in_file(
                    'pom.xml',
                    '<spring-boot.version>',
                    '<spring.boot.version>'
                )
            
            # Update Quarkus version for compatibility
            if 'quarkus' in app_name.lower():
                self._update_quarkus_version()
            
            return True
        except Exception as e:
            logger.error(f"Error applying v24.4 patches: {e}")
            return False
    
    def _apply_v24_5_patches(self, app_name: str) -> bool:
        """Apply patches specific to version 24.5."""
        try:
            # Update React Router dependencies
            if 'react' in app_name.lower():
                self._update_react_router()
            
            # Fix TypeScript configuration
            if self._file_exists('tsconfig.json'):
                self._fix_typescript_config()
            
            return True
        except Exception as e:
            logger.error(f"Error applying v24.5 patches: {e}")
            return False
    
    def _apply_v23_3_patches(self, app_name: str) -> bool:
        """Apply patches specific to version 23.3."""
        try:
            # Fix CDI issues
            if 'cdi' in app_name.lower():
                self._fix_cdi_configuration()
            
            # Update Spring Security configuration
            if self._contains_spring_security():
                self._update_spring_security_config()
            
            return True
        except Exception as e:
            logger.error(f"Error applying v23.3 patches: {e}")
            return False
    
    def _apply_v23_2_patches(self, app_name: str) -> bool:
        """Apply patches specific to version 23.2."""
        try:
            # Fix Gradle wrapper issues
            if self._file_exists('build.gradle'):
                self._fix_gradle_wrapper()
            
            return True
        except Exception as e:
            logger.error(f"Error applying v23.2 patches: {e}")
            return False
    
    def _apply_v14_11_patches(self, app_name: str) -> bool:
        """Apply patches specific to version 14.11."""
        try:
            # Legacy Flow compatibility
            self._apply_legacy_flow_patches()
            
            return True
        except Exception as e:
            logger.error(f"Error applying v14.11 patches: {e}")
            return False
    
    def _apply_app_specific_patches(self, app_name: str, version: str) -> bool:
        """Apply patches specific to individual applications."""
        try:
            # Chat starter specific patches
            if app_name == 'chat':
                return self._patch_chat_starter(version)
            
            # Bookstore specific patches
            elif app_name == 'bookstore':
                return self._patch_bookstore_starter(version)
            
            # Skeleton starter patches
            elif 'skeleton' in app_name:
                return self._patch_skeleton_starter(version)
            
            # Base starter patches
            elif 'base-starter' in app_name:
                return self._patch_base_starter(version)
            
            # React starter patches
            elif 'react' in app_name:
                return self._patch_react_starter(version)
            
            # Default: no app-specific patches needed
            return True
            
        except Exception as e:
            logger.error(f"Error applying app-specific patches for {app_name}: {e}")
            return False
    
    def _patch_chat_starter(self, version: str) -> bool:
        """Apply patches specific to chat starter."""
        try:
            # Fix WebSocket configuration for newer versions
            if self._version_gte(version, '24.0'):
                self._replace_in_file(
                    'src/main/java/com/vaadin/demo/chat/ChatView.java',
                    '@Push(PushMode.MANUAL)',
                    '@Push'
                )
            
            return True
        except Exception as e:
            logger.error(f"Error patching chat starter: {e}")
            return False
    
    def _patch_bookstore_starter(self, version: str) -> bool:
        """Apply patches specific to bookstore starter."""
        try:
            # Update database configuration for H2 compatibility
            if self._file_exists('src/main/resources/application.properties'):
                self._replace_in_file(
                    'src/main/resources/application.properties',
                    'spring.h2.console.enabled=true',
                    'spring.h2.console.enabled=false'
                )
            
            return True
        except Exception as e:
            logger.error(f"Error patching bookstore starter: {e}")
            return False
    
    def _patch_skeleton_starter(self, version: str) -> bool:
        """Apply patches specific to skeleton starter."""
        try:
            # Remove problematic dependencies
            if self._file_exists('pom.xml'):
                self._remove_dependency('com.vaadin', 'vaadin-testbench')
            
            return True
        except Exception as e:
            logger.error(f"Error patching skeleton starter: {e}")
            return False
    
    def _patch_base_starter(self, version: str) -> bool:
        """Apply patches specific to base starter."""
        try:
            # Fix Quarkus specific issues
            if 'quarkus' in os.getcwd():
                self._fix_quarkus_native_build()
            
            return True
        except Exception as e:
            logger.error(f"Error patching base starter: {e}")
            return False
    
    def _patch_react_starter(self, version: str) -> bool:
        """Apply patches specific to React starter."""
        try:
            # Update package.json dependencies
            if self._file_exists('package.json'):
                self._update_react_dependencies()
            
            return True
        except Exception as e:
            logger.error(f"Error patching React starter: {e}")
            return False
    
    def _apply_java_downgrade(self, app_name: str, version: str) -> bool:
        """Apply Java version downgrade if needed."""
        try:
            # Get current Java version
            java_version = self._get_java_version()
            if not java_version:
                return True  # No Java version detected, skip
            
            # Check if downgrade is needed
            if java_version in self.java_version_downgrades:
                target_version = self.java_version_downgrades[java_version]
                logger.info(f"Downgrading Java from {java_version} to {target_version}")
                
                # Update pom.xml
                if self._file_exists('pom.xml'):
                    self._update_java_version_in_pom(target_version)
                
                # Update build.gradle
                if self._file_exists('build.gradle'):
                    self._update_java_version_in_gradle(target_version)
            
            return True
        except Exception as e:
            logger.error(f"Error applying Java downgrade: {e}")
            return False
    
    def _get_java_version(self) -> Optional[str]:
        """Get the major Java version from pom.xml or build.gradle."""
        try:
            # Check pom.xml first
            if self._file_exists('pom.xml'):
                tree = ET.parse('pom.xml')
                root = tree.getroot()
                
                # Find Maven properties
                properties = root.find('.//properties')
                if properties is not None:
                    for prop in properties:
                        if 'java.version' in prop.tag or 'maven.compiler.target' in prop.tag:
                            version = prop.text.strip()
                            return self._extract_major_version(version)
            
            # Check build.gradle
            if self._file_exists('build.gradle'):
                with open('build.gradle', 'r') as f:
                    content = f.read()
                    
                # Look for Java version in various formats
                patterns = [
                    r'targetCompatibility\s*=\s*["\']?(\d+)',
                    r'sourceCompatibility\s*=\s*["\']?(\d+)',
                    r'jvmTarget\s*=\s*["\']?(\d+)'
                ]
                
                for pattern in patterns:
                    match = re.search(pattern, content)
                    if match:
                        return match.group(1)
            
            return None
        except Exception as e:
            logger.error(f"Error getting Java version: {e}")
            return None
    
    def _extract_major_version(self, version: str) -> str:
        """Extract major version number from version string."""
        # Handle formats like "1.8", "11", "17.0.1", etc.
        if version.startswith('1.'):
            return version.split('.')[1]  # "1.8" -> "8"
        else:
            return version.split('.')[0]  # "17.0.1" -> "17"
    
    def _update_java_version_in_pom(self, target_version: str) -> bool:
        """Update Java version in pom.xml."""
        try:
            tree = ET.parse('pom.xml')
            root = tree.getroot()
            
            # Update properties
            properties = root.find('.//properties')
            if properties is not None:
                for prop in properties:
                    if any(tag in prop.tag for tag in ['java.version', 'maven.compiler.source', 'maven.compiler.target']):
                        prop.text = target_version
            
            # Write back to file
            tree.write('pom.xml', encoding='utf-8', xml_declaration=True)
            logger.info(f"Updated Java version to {target_version} in pom.xml")
            return True
        except Exception as e:
            logger.error(f"Error updating Java version in pom.xml: {e}")
            return False
    
    def _update_java_version_in_gradle(self, target_version: str) -> bool:
        """Update Java version in build.gradle."""
        try:
            with open('build.gradle', 'r') as f:
                content = f.read()
            
            # Update various Java version settings
            patterns_replacements = [
                (r'(targetCompatibility\s*=\s*)["\']?\d+["\']?', f'\\g<1>"{target_version}"'),
                (r'(sourceCompatibility\s*=\s*)["\']?\d+["\']?', f'\\g<1>"{target_version}"'),
                (r'(jvmTarget\s*=\s*)["\']?\d+["\']?', f'\\g<1>"{target_version}"')
            ]
            
            for pattern, replacement in patterns_replacements:
                content = re.sub(pattern, replacement, content)
            
            with open('build.gradle', 'w') as f:
                f.write(content)
            
            logger.info(f"Updated Java version to {target_version} in build.gradle")
            return True
        except Exception as e:
            logger.error(f"Error updating Java version in build.gradle: {e}")
            return False
    
    # Helper methods
    
    def _file_exists(self, filepath: str) -> bool:
        """Check if file exists."""
        return Path(filepath).exists()
    
    def _replace_in_file(self, filepath: str, old_text: str, new_text: str) -> bool:
        """Replace text in file."""
        try:
            if not self._file_exists(filepath):
                return False
            
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if old_text in content:
                content = content.replace(old_text, new_text)
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                logger.debug(f"Replaced '{old_text}' with '{new_text}' in {filepath}")
                return True
            
            return False
        except Exception as e:
            logger.error(f"Error replacing text in {filepath}: {e}")
            return False
    
    def _version_gte(self, version1: str, version2: str) -> bool:
        """Check if version1 >= version2."""
        try:
            v1_parts = [int(x) for x in version1.split('.')]
            v2_parts = [int(x) for x in version2.split('.')]
            
            # Pad with zeros to make same length
            max_len = max(len(v1_parts), len(v2_parts))
            v1_parts.extend([0] * (max_len - len(v1_parts)))
            v2_parts.extend([0] * (max_len - len(v2_parts)))
            
            return v1_parts >= v2_parts
        except Exception:
            return False
    
    def _contains_spring_security(self) -> bool:
        """Check if project contains Spring Security dependencies."""
        try:
            if self._file_exists('pom.xml'):
                with open('pom.xml', 'r') as f:
                    content = f.read()
                    return 'spring-security' in content
            
            if self._file_exists('build.gradle'):
                with open('build.gradle', 'r') as f:
                    content = f.read()
                    return 'spring-security' in content
            
            return False
        except Exception:
            return False
    
    def _remove_dependency(self, group_id: str, artifact_id: str) -> bool:
        """Remove Maven dependency from pom.xml."""
        try:
            if not self._file_exists('pom.xml'):
                return False
            
            tree = ET.parse('pom.xml')
            root = tree.getroot()
            
            # Find and remove dependency
            dependencies = root.findall('.//dependency')
            for dep in dependencies:
                group = dep.find('groupId')
                artifact = dep.find('artifactId')
                
                if (group is not None and group.text == group_id and
                    artifact is not None and artifact.text == artifact_id):
                    parent = dep.getparent()
                    parent.remove(dep)
                    break
            
            tree.write('pom.xml', encoding='utf-8', xml_declaration=True)
            return True
        except Exception as e:
            logger.error(f"Error removing dependency {group_id}:{artifact_id}: {e}")
            return False
    
    # Placeholder methods for additional patch functionality
    def _update_quarkus_version(self) -> bool:
        """Update Quarkus version for compatibility."""
        # Implementation would go here
        return True
    
    def _update_react_router(self) -> bool:
        """Update React Router dependencies."""
        # Implementation would go here
        return True
    
    def _fix_typescript_config(self) -> bool:
        """Fix TypeScript configuration."""
        # Implementation would go here
        return True
    
    def _fix_cdi_configuration(self) -> bool:
        """Fix CDI configuration issues."""
        # Implementation would go here
        return True
    
    def _update_spring_security_config(self) -> bool:
        """Update Spring Security configuration."""
        # Implementation would go here
        return True
    
    def _fix_gradle_wrapper(self) -> bool:
        """Fix Gradle wrapper issues."""
        # Implementation would go here
        return True
    
    def _apply_legacy_flow_patches(self) -> bool:
        """Apply legacy Flow compatibility patches."""
        # Implementation would go here
        return True
    
    def _fix_quarkus_native_build(self) -> bool:
        """Fix Quarkus native build issues."""
        # Implementation would go here
        return True
    
    def _update_react_dependencies(self) -> bool:
        """Update React dependencies in package.json."""
        # Implementation would go here
        return True

if __name__ == '__main__':
    # Example usage
    patch_manager = PatchManager()
    
    # Apply patches for a specific app and version
    success = patch_manager.apply_patches('chat', '24.4')
    print(f"Patch application {'succeeded' if success else 'failed'}")
