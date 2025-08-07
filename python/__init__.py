#!/usr/bin/env python3
"""
Platform Integration Test (PiT) Python utilities.

This package provides Python equivalents of the bash utilities used in the 
Vaadin platform integration testing framework.
"""

# Import main utility classes and functions
from .system_utils import (
    is_linux, is_mac, is_windows,
    check_commands, get_pids, kill_process,
    check_port, compute_absolute_path, download_file
)

from .output_utils import (
    log, bold, err, warn, cmd, dim,
    report_error, report_out_errors, ask,
    wait_for_user_with_bell, wait_for_user_manual_testing,
    print_time, print_versions
)

from .process_utils import (
    ProcessManager, process_manager,
    run_command, run_to_file, run_in_background_to_file,
    wait_until_message_in_file, wait_until_port,
    check_http_servlet, wait_until_frontend_compiled
)

from .maven_utils import (
    compute_mvn, compute_gradle, get_pom_files,
    get_current_property, change_maven_property, change_maven_block,
    get_maven_version, set_version, get_gradle_version, set_gradle_version,
    check_tsconfig_modified, check_bundle_not_created,
    check_no_spring_dependencies, check_vite_compilation_warnings,
    add_repo_to_pom, add_repo_to_gradle
)

from .java_utils import (
    compute_npm, install_jbr_runtime, install_jdk_runtime,
    set_java_path, unset_java_path, enable_jbr_autoreload,
    compute_java_major, upgrade_gradle, clean_m2,
    disable_launch_browser, enable_pnpm, enable_vite,
    set_property_in_file, is_headless
)

from .vaadin_utils import (
    remove_pro_key, restore_pro_key,
    get_version_from_platform, set_version_from_platform,
    set_flow_version, set_mpr_version, get_latest_hilla_version,
    compute_version, compute_property, compute_property_after_patch,
    get_mvn_dependency_version, set_mvn_dependency_version,
    get_repos_from_website, validate_token,
    add_prereleases, add_spring_release_repo, enable_snapshots
)

# Import new PiT modules
from . import repos
from . import pit_args  
from . import starter_utils
from . import k8s_utils
from . import pit_runner

# Note: patch_utils, playwright_utils, validation_utils, and utils 
# are imported directly by modules that need them to avoid circular dependencies


__version__ = "1.0.0"
__author__ = "Vaadin Platform Team"
__description__ = "Python utilities for Vaadin platform integration testing"


def cleanup_and_exit():
    """Cleanup function to be called on script exit."""
    process_manager.cleanup()
    from .java_utils import unset_java_path
    from .vaadin_utils import restore_pro_key
    
    restore_pro_key()
    unset_java_path()


# Register cleanup function
import atexit
atexit.register(cleanup_and_exit)
