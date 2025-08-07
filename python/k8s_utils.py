"""
Kubernetes utilities for Control Center deployment and management.
Converted from lib-k8s-cc.sh and related files.
"""

import os
import time
import subprocess
from pathlib import Path
from typing import Dict, Any, Optional, List, Tuple

from .system_utils import check_commands, check_port, get_pids
from .output_utils import log, err, warn, bold
from .process_utils import run_command, run_to_file
from .maven_utils import compute_mvn


class ControlCenterManager:
    """Manages Vaadin Control Center deployment in Kubernetes."""
    
    # Configuration constants
    CC_DOMAIN = os.environ.get('CC_DOMAIN', 'local.alcala.org')
    CC_CONTROL = f"control.{CC_DOMAIN}"
    CC_AUTH = f"auth.{CC_DOMAIN}"
    CC_EMAIL = f"admin@{CC_DOMAIN}"
    CC_NS = 'control-center'
    CC_TLS_A = 'cc-control-app-tls'
    CC_TLS_K = 'cc-control-login-tls'
    CC_ING_A = 'control-center'
    CC_ING_K = 'control-center-keycloak-ingress'
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.verbose = config.get('verbose', False)
        self.test_mode = config.get('test_mode', False)
        self.vendor = config.get('vendor', 'kind')
        self.cluster = config.get('cluster', 'pit')
        self.cc_version = config.get('cc_version')
        self.skip_helm = config.get('skip_helm', False)
        self.keep_cc = config.get('keep_cc', False)
        
        # Control Center tests to run
        self.cc_tests = os.environ.get('CC_TESTS', 
                                      'cc-setup.js cc-install-apps.js cc-identity-management.js cc-localization.js').split()
    
    def check_docker_running(self) -> bool:
        """Check if Docker is running."""
        try:
            subprocess.run(['docker', 'ps'], capture_output=True, check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            err("!! Docker is not running. Please start Docker and try again. !!")
            return False
    
    def check_current_version(self, version: Optional[str] = None) -> Optional[str]:
        """
        Check the appVersion of the CC helm chart.
        
        Args:
            version: CC version to check, or None for current
            
        Returns:
            Version string if found, None otherwise
        """
        cmd = "helm show all oci://docker.io/vaadin/control-center"
        if version and version != 'current':
            cmd += f" --version {version}"
        
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            if result.returncode != 0:
                err(f"No CC version found for {version}")
                return None
                
            for line in result.stdout.split('\n'):
                if line.startswith('appVersion'):
                    found_version = line.split()[1]
                    if version and version != 'current' and version != found_version:
                        err(f"Bad version found for {version} != {found_version}")
                        return None
                    return found_version
                    
            return None
            
        except Exception as e:
            err(f"Failed to check CC version: {e}")
            return None
    
    def compute_cc_version(self, platform_version: str) -> Optional[str]:
        """
        Given a platform version, determine the corresponding CC version.
        
        Args:
            platform_version: Platform version to check
            
        Returns:
            CC version string if found, None otherwise
        """
        if not platform_version or platform_version.endswith('-SNAPSHOT'):
            return platform_version
            
        try:
            # Try to get version from platform first
            from .vaadin_utils import get_version_from_platform
            cc_version = get_version_from_platform(platform_version, 'control.center')
            if cc_version:
                # Convert format like 1.3.beta1 to 1.3-beta1
                import re
                return re.sub(r'\.([a-z]+\d+)$', r'-\1', cc_version)
            
            # Fall back to git tag lookup
            subprocess.run(['git', 'fetch', '--tags', '-q'], capture_output=True)
            result = subprocess.run(['git', 'tag'], capture_output=True, text=True)
            
            for tag in sorted(result.stdout.strip().split('\n'), reverse=True):
                # Check the vaadin.components.version in this tag
                pom_content = subprocess.run(
                    ['git', 'show', f'{tag}:pom.xml'], 
                    capture_output=True, text=True
                )
                if pom_content.returncode == 0:
                    import re
                    match = re.search(r'<vaadin\.components\.version>(.*?)</vaadin\.components\.version>', 
                                    pom_content.stdout)
                    if match and match.group(1) == platform_version:
                        if not self.test_mode:
                            log(f"Platform {platform_version} has control-center CC {tag}")
                        return tag
                        
            return None
            
        except Exception as e:
            err(f"Failed to compute CC version for {platform_version}: {e}")
            return None
    
    def get_maven_version(self) -> Optional[str]:
        """Get the current project version from Maven."""
        try:
            mvn_cmd = compute_mvn()
            result = subprocess.run(
                f"{mvn_cmd} help:evaluate -Dexpression=project.version -q -DforceStdout",
                shell=True, capture_output=True, text=True
            )
            return result.stdout.strip() if result.returncode == 0 else None
        except Exception:
            return None
    
    def is_cc_installed(self) -> Tuple[bool, str]:
        """
        Check if Control Center is installed and return status info.
        
        Returns:
            Tuple of (is_installed, status_info)
        """
        try:
            result = subprocess.run(
                f"helm list -n {self.CC_NS}",
                shell=True, capture_output=True, text=True
            )
            
            if result.returncode != 0:
                return False, "Control-Center is not installed yet"
                
            lines = result.stdout.strip().split('\n')
            for line in lines[1:]:  # Skip header
                if line.strip():
                    parts = line.split()
                    if len(parts) >= 10:
                        status_info = f" · {parts[8]} · {parts[9]} · {parts[3]}"
                        log(f"Installed Control-Center is: {status_info}")
                        return True, status_info
                        
            log("Control-Center is not installed yet")
            return False, "Control-Center is not installed yet"
            
        except Exception as e:
            err(f"Failed to check CC installation: {e}")
            return False, "Failed to check installation"
    
    def has_cc_namespace(self) -> bool:
        """Check if the cluster has the CC namespace."""
        try:
            result = subprocess.run(
                'kubectl get ns',
                shell=True, capture_output=True, text=True
            )
            
            if result.returncode != 0:
                return False
                
            for line in result.stdout.split('\n'):
                if line.startswith(self.CC_NS + ' '):
                    return True
                    
            return False
            
        except Exception:
            return False
    
    def install_cc(self, version: str, is_snapshot: bool = False) -> bool:
        """
        Install Control Center with Helm.
        
        Args:
            version: CC version to install
            is_snapshot: Whether this is a snapshot version
            
        Returns:
            True if successful, False otherwise
        """
        log(f"** Installing Control Center {version} with Helm **")
        
        # Prepare arguments
        args = ""
        cc_key = os.environ.get('CC_KEY')
        cc_cert = os.environ.get('CC_CERT')
        
        if cc_key and cc_cert:
            args += f"--set app.tlsSecret={self.CC_TLS_A} --set keycloak.tlsSecret={self.CC_TLS_K}"
        
        # Configure for different deployment types
        do_reg_url = os.environ.get('DO_REG_URL')
        do_regst = os.environ.get('DO_REGST')
        
        if is_snapshot:
            args += f" charts/control-center --set app.image.tag=local --set keycloak.image.tag=local"
            if do_reg_url:
                args += f" --set app.image.repository={do_reg_url}/control-center-app"
                args += f" --set keycloak.image.repository={do_reg_url}/control-center-keycloak"
        elif version == 'current':
            args += " oci://docker.io/vaadin/control-center"
        else:
            args += f" oci://docker.io/vaadin/control-center --version {version}"
        
        # Skip installation if already running and skip-helm is set
        if self.skip_helm:
            result = subprocess.run('kubectl get pods 2>&1', shell=True, capture_output=True, text=True)
            if 'control-center-' in result.stdout:
                return True
        
        if not self.test_mode:
            log(f"Installing Control Center with version: {version}")
        
        debug_flag = '--debug' if self.verbose else ''
        
        # Construct helm command
        helm_cmd = (f"helm install control-center {args} "
                   f"-n {self.CC_NS} --create-namespace "
                   f"--set app.startupProbe.initialDelaySeconds=90 "
                   f"--set app.resources.limits.memory=1Gi "
                   f"--set app.resources.requests.memory=256Mi "
                   f"--set keycloak.startupProbe.initialDelaySeconds=70 "
                   f"--set keycloak.resources.limits.memory=1Gi "
                   f"--set keycloak.resources.requests.memory=256Mi "
                   f"--set domain={self.CC_DOMAIN} "
                   f"--set user.email={self.CC_EMAIL}")
        
        # Try installation
        if run_to_file(helm_cmd, f"helm-install-{version}-1.out", self.verbose) != 0:
            err("!! Error installing control-center with helm, trying a second time !!")
            self.uninstall_cc()
            log("sleeping 30 secs")
            time.sleep(30)
            if run_to_file(helm_cmd, f"helm-install-{version}-2.out", self.verbose) != 0:
                return False
        
        # Patch deployment if not current version
        if version != 'current':
            return self.patch_deployment(self.CC_NS)
            
        return True
    
    def patch_deployment(self, namespace: str) -> bool:
        """
        Patch deployment for local images.
        
        Args:
            namespace: Kubernetes namespace
            
        Returns:
            True if successful, False otherwise
        """
        do_regst = os.environ.get('DO_REGST')
        if not do_regst:
            return True
            
        try:
            for app in ['control-center-app', 'control-center-keycloak']:
                patch_cmd = (f"kubectl patch deployment {app} -n {namespace} "
                           f"--type=merge "
                           f"--patch='{{\"spec\":{{\"template\":{{\"spec\":{{\"imagePullSecrets\":[{{\"name\":\"{do_regst}\"}}]}}}}}}}}'")
                
                if run_command(f"Patching {app} deployment", patch_cmd) != 0:
                    return False
                    
            return True
            
        except Exception as e:
            err(f"Failed to patch deployment: {e}")
            return False
    
    def wait_for_cc(self, timeout: int = 900) -> bool:
        """
        Wait for Control Center to be ready.
        
        Args:
            timeout: Timeout in seconds
            
        Returns:
            True if CC is ready, False if timeout
        """
        if self.test_mode:
            return True
            
        log("Waiting for Control Center to be ready")
        elapsed = 0
        last = ""
        
        while elapsed < timeout:
            elapsed += 1
            
            try:
                result = subprocess.run(
                    f"kubectl get pods -n {self.CC_NS}",
                    shell=True, capture_output=True, text=True
                )
                
                if result.returncode != 0:
                    log("Control center not installed in k8s")
                    return False
                
                # Look for control-center pod status
                import re
                for line in result.stdout.split('\n'):
                    match = re.search(r'control-center-[0-9abcdef]+-\w+\s+(\S+)\s+(\S+)\s+(\S+)', line)
                    if match:
                        status = f"{match.group(1)} {match.group(2)} {match.group(3)}"
                        
                        if status.startswith("1/1") and "Running" in status:
                            log(f"Control Center up and running - Status: {status}")
                            return True
                        else:
                            if status != last:
                                if self.verbose and last:
                                    print()
                                log(f"Control center initializing - Status: {status}")
                            elif self.verbose:
                                print(".", end="", flush=True)
                            last = status
                            
                time.sleep(1)
                
            except Exception as e:
                warn(f"Error checking CC status: {e}")
                time.sleep(5)
        
        log(f"Timeout {timeout} sec. exceeded.")
        return False
    
    def uninstall_cc(self, wait: bool = True) -> bool:
        """
        Uninstall Control Center.
        
        Args:
            wait: Whether to wait for uninstallation to complete
            
        Returns:
            True if successful, False otherwise
        """
        if not self.has_cc_namespace():
            return True
            
        is_installed, status = self.is_cc_installed()
        if not is_installed:
            return True
            
        debug_flag = '--debug' if self.verbose else ''
        verbose_flag = '--v=10' if self.verbose else ''
        wait_flag = '--wait' if wait else '--wait=false'
        
        cmd = f"helm uninstall control-center {wait_flag} -n {self.CC_NS} {debug_flag}"
        
        if run_command(f"Uninstalling {status}", cmd) != 0:
            return False
            
        # Remove namespace if specified
        if wait:
            cmd = f"kubectl delete ns {self.CC_NS} {verbose_flag}"
            run_command(f"Removing namespace {self.CC_NS}", cmd)
            
        return True
    
    def install_tls(self) -> bool:
        """Install TLS certificates for Control Center."""
        if self.config.get('fast') and self.skip_helm:
            return True
            
        cc_key = os.environ.get('CC_KEY')
        cc_cert = os.environ.get('CC_CERT')
        
        if not cc_key or not cc_cert:
            log("No CC_KEY and CC_CERT provided, skipping TLS installation")
            return True
            
        if not self.test_mode:
            log(f"Installing TLS {self.CC_TLS_A} for {self.CC_CONTROL} and {self.CC_AUTH}")
        
        try:
            # Write certificate files
            cert_file = 'cc-tls.crt'
            key_file = 'cc-tls.key'
            pem_file = f'{self.CC_DOMAIN}.pem'
            
            with open(cert_file, 'w') as f:
                f.write(cc_cert)
            with open(key_file, 'w') as f:
                f.write(cc_key)
            with open(pem_file, 'w') as f:
                f.write(cc_cert + cc_key)
            
            # Remove old secrets if they exist
            for secret in [self.CC_TLS_A, self.CC_TLS_K]:
                subprocess.run(
                    f"kubectl get secret {secret} -n {self.CC_NS}",
                    shell=True, capture_output=True
                )
                if subprocess.run(
                    f"kubectl delete secret {secret} -n {self.CC_NS}",
                    shell=True, capture_output=True
                ).returncode == 0:
                    log(f"Removed existing secret {secret}")
            
            # Create new secrets
            for secret in [self.CC_TLS_A, self.CC_TLS_K]:
                cmd = f"kubectl -n {self.CC_NS} create secret tls {secret} --key '{key_file}' --cert '{cert_file}'"
                if run_command(f"Creating TLS secret {secret} in cluster", cmd) != 0:
                    return False
            
            # Clean up files
            for f in [cert_file, key_file, pem_file]:
                try:
                    os.remove(f)
                except OSError:
                    pass
            
            # Patch ingresses with new secrets
            for ing, secret in [(self.CC_ING_A, self.CC_TLS_A), (self.CC_ING_K, self.CC_TLS_K)]:
                host = self.CC_CONTROL if ing == self.CC_ING_A else self.CC_AUTH
                patch = f'{{"spec": {{"tls": [{{"hosts": ["{host}"],"secretName": "{secret}"}}]}}}}'
                cmd = f"kubectl patch ingress {ing} -n {self.CC_NS} --type=merge --patch '{patch}'"
                run_command(f"patching {secret}", cmd)
            
            if not self.test_mode:
                return self.reload_ingress()
                
            return True
            
        except Exception as e:
            err(f"Failed to install TLS: {e}")
            return False
    
    def reload_ingress(self) -> bool:
        """Reload ingress process after changing certificates."""
        if self.test_mode:
            return True
            
        try:
            result = subprocess.run(
                f"kubectl -n {self.CC_NS} get pods",
                shell=True, capture_output=True, text=True
            )
            
            for line in result.stdout.split('\n'):
                if 'control-center-ingress-nginx-controller' in line:
                    pod = line.split()[0]
                    cmd = f"kubectl exec {pod} -n {self.CC_NS} -- nginx -s reload"
                    if run_command(f"Reloading nginx in {pod}", cmd) != 0:
                        return False
                    break
            
            if not self.test_mode:
                time.sleep(3)
                
            return True
            
        except Exception as e:
            err(f"Failed to reload ingress: {e}")
            return False
    
    def check_tls(self) -> bool:
        """Check TLS certificates for all ingresses."""
        if self.config.get('skip_setup') or self.test_mode:
            return True
            
        log("Checking TLS certificates for all ingresses hosted in the cluster")
        
        try:
            result = subprocess.run(
                f"kubectl get ingresses -n {self.CC_NS}",
                shell=True, capture_output=True, text=True
            )
            
            for line in result.stdout.split('\n'):
                if 'nginx' in line:
                    ingress = line.split()[0]
                    self._get_tls_info(ingress)
                    
            return True
            
        except Exception as e:
            err(f"Failed to check TLS: {e}")
            return False
    
    def _get_tls_info(self, ingress: str) -> None:
        """Get TLS information for a specific ingress."""
        try:
            # Get host
            result = subprocess.run(
                f"kubectl get ingress {ingress} -n {self.CC_NS} -o jsonpath='{{.spec.rules[0].host}}'",
                shell=True, capture_output=True, text=True
            )
            host = result.stdout.strip()
            
            # Get TLS hosts
            result = subprocess.run(
                f"kubectl get ingress {ingress} -n {self.CC_NS} -o jsonpath='{{.spec.tls[*].hosts[*]}}'",
                shell=True, capture_output=True, text=True
            )
            tls_hosts = result.stdout.strip()
            
            # Get secret name
            result = subprocess.run(
                f"kubectl get ingress {ingress} -n {self.CC_NS} -o jsonpath='{{.spec.tls[*].secretName}}'",
                shell=True, capture_output=True, text=True
            )
            secret = result.stdout.strip()
            
            # Get certificate info
            cert_cmd = (f"kubectl get secret {secret} -n {self.CC_NS} "
                       f"-o go-template='{{{{ index .data \"tls.crt\" | base64decode }}}}' | "
                       f"openssl x509 -noout -issuer -subject -enddate")
            
            result = subprocess.run(cert_cmd, shell=True, capture_output=True, text=True)
            cert_info = result.stdout.replace('\n', ' ')
            
            log(f"TLS config for ingress: {ingress}, secret: {secret}")
            from .output_utils import dim
            dim(f" hosts: {tls_hosts} cert: {cert_info}")
            
        except Exception as e:
            warn(f"Failed to get TLS info for {ingress}: {e}")
    
    def show_temporary_password(self) -> None:
        """Show temporary user email and password."""
        try:
            result = subprocess.run(
                f"kubectl get secret control-center-init-user-secret -n {self.CC_NS} "
                f"-o jsonpath='{{.data.password}}' | base64 -d",
                shell=True, capture_output=True, text=True
            )
            
            if result.returncode == 0:
                password = result.stdout.strip()
                bold(f"Temporary login: {self.CC_EMAIL} / {password}")
                bold(f"Control Center URL: https://{self.CC_CONTROL}")
            else:
                warn("Could not retrieve temporary password")
                
        except Exception as e:
            warn(f"Failed to get temporary password: {e}")
    
    def download_logs(self) -> bool:
        """Download logs after a failure for CI artifacts."""
        if not self.has_cc_namespace():
            return False
            
        log("Saving deployment and pod logs")
        
        try:
            # Get pod logs
            result = subprocess.run(
                f"kubectl get pods -n {self.CC_NS}",
                shell=True, capture_output=True, text=True
            )
            
            for line in result.stdout.split('\n'):
                if line and not line.startswith('NAME') and not line.startswith('control-center'):
                    pod = line.split()[0]
                    run_to_file(f"kubectl logs {pod} -n {self.CC_NS}", f"pod-{pod}.out", self.verbose)
            
            # Get deployment logs
            result = subprocess.run(
                f"kubectl get deployments -n {self.CC_NS}",
                shell=True, capture_output=True, text=True
            )
            
            for line in result.stdout.split('\n'):
                if line and not line.startswith('NAME') and not line.startswith('control-center'):
                    deployment = line.split()[0]
                    run_to_file(f"kubectl describe deployment {deployment} -n {self.CC_NS}", 
                              f"deployment-{deployment}.out", self.verbose)
            
            return False  # Always return False since this is called after failure
            
        except Exception as e:
            err(f"Failed to download logs: {e}")
            return False
