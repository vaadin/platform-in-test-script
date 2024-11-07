#!/bin/bash

# Load necessary libraries
. `dirname $0`/../repos.sh
. `dirname $0`/lib/lib-args.sh
. `dirname $0`/lib/lib-start.sh
. `dirname $0`/lib/lib-demos.sh
. `dirname $0`/lib/lib-utils.sh
. `dirname $0`/lib/lib-validate.sh

# Default configuration
NAMESPACE="control-center"
RELEASE_NAME="control-center"
HELM_REPO="oci://docker.io/vaadin/control-center"
SERVICE_PORT=8000
TIMEOUT=600  # Timeout in seconds
PORT_HTTP=80
PORT_HTTPS=443

# Function to install Docker if not installed
installDocker() {
  if ! command -v docker &> /dev/null; then
    log "Docker is not installed. Installing Docker..."
    OS=$(uname -s)
    case $OS in
      Linux)
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        ;;
      Darwin)
        brew install --cask docker
        ;;
      MINGW*|CYGWIN*)
        choco install docker-desktop
        ;;
      *)
        log "Unsupported OS: $OS. Please install Docker manually."
        exit 1
        ;;
    esac
    log "Docker installed successfully."
  else
    log "Docker is already installed."
  fi
}

# Function to start Docker
startDocker() {
  if ! pgrep -x "dockerd" > /dev/null; then
    log "Starting Docker..."
    open -a Docker || sudo systemctl start docker

    # Wait for Docker to be ready
    SECONDS=0
    until docker info > /dev/null 2>&1; do
      if [ "$SECONDS" -ge "$TIMEOUT" ]; then
        log "Error: Docker did not start within $TIMEOUT seconds."
        exit 1
      fi
      log "Waiting for Docker to start..."
      sleep 2
    done

    log "Docker started successfully."
  else
    log "Docker is already running."
  fi
}

# Function to install Minikube if not installed
installMinikube() {
  if ! command -v minikube &> /dev/null; then
    log "Minikube is not installed. Installing Minikube..."
    OS=$(uname -s)
    case $OS in
      Linux)
        curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube /usr/local/bin/
        rm minikube
        ;;
      Darwin)
        brew install minikube
        ;;
      MINGW*|CYGWIN*)
        choco install minikube
        ;;
      *)
        log "Unsupported OS: $OS. Please install Minikube manually."
        exit 1
        ;;
    esac
    log "Minikube installed successfully."
  else
    log "Minikube is already installed."
  fi
}

# Function to install and start Minikube if not installed
startMinikube() {
  log "Starting Minikube..."
  minikube delete
  minikube start || exit 1
  log "Minikube started successfully."
  # Run minikube tunnel in the background
  echo "Starting minikube tunnel in the background..."
  nohup minikube tunnel &> minikube_tunnel.log &
  
  # Capture the process ID to monitor if needed
  tunnel_pid=$!
  echo "minikube tunnel started with PID $tunnel_pid"
}

# Configure kubectl to use the Minikube context
configureKubectl() {
  log "Configuring kubectl context for Minikube..."
  minikube update-context
  if [ $? -ne 0 ]; then
    log "⛔ Failed to configure kubectl context for Minikube."
    exit 1
  fi
  log "kubectl context configured for Minikube."
}

# Function to install Helm if not installed
installHelm() {
  if ! command -v helm &> /dev/null; then
    log "Helm is not installed. Installing Helm..."
    OS=$(uname -s)
    case $OS in
      Linux)
        curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
        ;;
      Darwin)
        brew install helm
        ;;
      MINGW*|CYGWIN*)
        choco install kubernetes-helm
        ;;
      *)
        log "Unsupported OS: $OS. Please install Helm manually."
        exit 1
        ;;
    esac
    log "Helm installed successfully."
  else
    log "Helm is already installed."
  fi
}


# Function to install Vaadin Control Center using Helm
installControlCenter() {
  helm install $RELEASE_NAME $HELM_REPO \
    -n $NAMESPACE --create-namespace \
    --set serviceAccount.clusterAdmin=true \
    --set service.type=LoadBalancer --set service.port=$SERVICE_PORT \
    --wait --debug
}

# Function to check if the Control Center service is up
checkControlCenter() {
  log "Checking if Vaadin Control Center is accessible..."
  checkPort $SERVICE_PORT 60 && echo "Port $SERVICE_PORT is available" || return 1
  SERVICE_IP=$(kubectl get svc -n $NAMESPACE $RELEASE_NAME -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if echo "$SERVICE_IP" | grep -q "error"; then
      log "Error fetching service IP: $SERVICE_IP"
      return 1
    fi
    if [ -z "$SERVICE_IP" ]; then
      log "Control Center service IP is not yet available on http://$SERVICE_IP:$SERVICE_PORT"
      return 1
    fi
  checkHttpServlet "http://$SERVICE_IP:$SERVICE_PORT/" "/dev/stdout" || return 1
}

# Function to uninstall existing control-center release if it exists
uninstallExistingRelease() {
  log "Uninstalling Vaadin Control Center"
  if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
    log "Found existing Helm release '$RELEASE_NAME'. Uninstalling..."
    kubectl delete ns $RELEASE_NAME --ignore-not-found
    kubectl delete ns ingress-nginx --ignore-not-found
    if [ $? -eq 0 ]; then
      log "Successfully uninstalled existing release '$RELEASE_NAME'."
    else
      log "Failed to uninstall existing release '$RELEASE_NAME'."
      exit 1
    fi
  else
    log "No existing release with name '$RELEASE_NAME' found."
  fi
}

availablePorts(){
 # Check if the port is already taken by other app
  [ -n "$TEST" ] || checkBusyPort "$SERVICE_PORT" || exit 1
  [ -n "$TEST" ] || checkBusyPort "$PORT_HTTP" || exit 1
  [ -n "$TEST" ] || checkBusyPort "$PORT_HTTPS" || exit 1
  
}
# Function to stop and delete the whole minikube cluster
stopMinikube() {
  minikube stop
  minikube delete
}


# Main function
main() {
  _start=$(date +%s)

  log "===================== Running Vaadin Control Center Test ============================"

  # Install and start Docker if it's not already installed and running
  installDocker
  startDocker

  # Install and start Minikube if it's not already installed and running
  installMinikube
  startMinikube
  
  # Configure kubectl context for Minikube
  configureKubectl
  
  # Install Helm if it's not already installed
  installHelm
  
  # Are ports available for the installation
  availablePorts
  # Install Vaadin Control Center
  installControlCenter

  # Check if Control Center is up
  MAX_RETRIES=5
  CONTROL_CENTER_UP=false
  
  for ((i=1; i<=MAX_RETRIES; i++)); do
    if [ "$CONTROL_CENTER_UP" = false ]; then
      S=$(checkControlCenter)  # Capture the output of checkControlCenter
      log "control center result: $S" 
      if checkControlCenter; then
        log "Vaadin Control Center is running successfully."
        CONTROL_CENTER_UP=true
      else
        log "Attempt $i: Vaadin Control Center is not accessible yet. Retrying in 10 seconds..."
        sleep 10
      fi
    else
      break
    fi
  done

  # Run Playwright tests here (add your Playwright test commands)

  # Uninstall Control Center after tests
  uninstallExistingRelease

  # Stop and delete minikube cluster
  stopMinikube

  # Report the elapsed time
  _end=$(date +%s)
  log "Tests completed in $(($_end - $_start)) seconds."
}

# Main execution
main
