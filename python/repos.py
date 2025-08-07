"""
Repository definitions and configurations for PiT tests.
This module contains the preset and demo definitions that were in repos.sh
"""

# Preset configurations for start.vaadin.com generated projects
PRESETS = [
    "latest-java",
    "latest-java-top", 
    "latest-java_partial-auth",
    "flow-crm-tutorial",
    "react",
    "react-crm-tutorial", 
    "react-tutorial",
    "test-hybrid-react",
    "default",
    "latest-java_partial-auth_partial-prerelease",
    "archetype-hotswap",
    "archetype-jetty",
    "archetype-spring",
    "vaadin-quarkus",
    "hilla-react-cli",
    "initializer-vaadin-maven-react",
    "initializer-vaadin-maven-flow",
    "initializer-vaadin-gradle-react",
    "initializer-vaadin-gradle-flow",
    "collaboration"
]

# Demo projects available in GitHub repositories
DEMOS = [
    "control-center",
    "skeleton-starter-flow",
    "skeleton-starter-flow-spring",
    "skeleton-starter-hilla-react",
    "skeleton-starter-hilla-react-gradle",
    "skeleton-starter-flow-cdi",
    "skeleton-starter-hilla-lit",
    "skeleton-starter-hilla-lit-gradle",
    "skeleton-starter-kotlin-spring",
    "business-app-starter-flow",
    "base-starter-spring-gradle",
    "base-starter-flow-quarkus",
    "base-starter-gradle",
    "flow-crm-tutorial",
    "hilla-crm-tutorial",
    "hilla-quickstart-tutorial",
    "hilla-basics-tutorial",
    "flow-quickstart-tutorial",
    "addon-template",
    "npm-addon-template",
    "client-server-addon-template",
    "spreadsheet-demo",
    "vaadin-form-example",
    "vaadin-rest-example"
]

# All available starters (combination of presets and demos)
ALL_STARTERS = PRESETS + DEMOS

def get_default_starters():
    """Return default list of starters (non-empty items)."""
    return [s for s in ALL_STARTERS if s.strip()]

def filter_starters(starter_list: str, exclude_patterns: list = None) -> list:
    """
    Filter starters based on inclusion/exclusion patterns.
    
    Args:
        starter_list: Comma-separated list of starters
        exclude_patterns: List of patterns to exclude (starting with '!')
    
    Returns:
        List of valid starter names
    """
    if not starter_list:
        return get_default_starters()
    
    starters = [s.strip() for s in starter_list.split(',') if s.strip()]
    
    # Process exclusions
    if exclude_patterns:
        for pattern in exclude_patterns:
            if pattern.startswith('!'):
                exclude_name = pattern[1:]
                starters = [s for s in starters if s != exclude_name]
    
    # Validate against known starters
    valid_starters = []
    for starter in starters:
        base_name = starter.split(':')[0]  # Handle repo:branch format
        if base_name in PRESETS or base_name in DEMOS:
            valid_starters.append(starter)
    
    return valid_starters

def is_preset(name: str) -> bool:
    """Check if a given name is a preset."""
    return name.split(':')[0] in PRESETS

def is_demo(name: str) -> bool:
    """Check if a given name is a demo."""
    return name.split(':')[0] in DEMOS
