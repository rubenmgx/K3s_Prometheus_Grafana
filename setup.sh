#!/bin/bash

TEST_DIR=$HOME/spre-ai-hackathon-experiment/k3s-prom-graf
K3S_CONTAINER_NAME="k3s-container"

mkdir -p "$TEST_DIR/etcd-snapshots"
mkdir -p "$TEST_DIR/etcd-backups"

echo "--- K3s Installation via Docker Desktop ---"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker Desktop is not running or not accessible. Please start Docker Desktop and try again."
    exit 1
fi
echo "✅ Docker Desktop is running."

# Stop and remove any existing k3s container
echo "Stopping and removing any old k3s container (if exists)..."
docker ps -a --filter "name=${K3S_CONTAINER_NAME}" --format "{{.ID}}" | xargs -r docker stop | xargs -r docker rm

# Run k3s server in a Docker container
echo "Starting k3s server in a Docker container..."
docker run -d --privileged \
    --name ${K3S_CONTAINER_NAME} \
    -p 6443:6443 \
    rancher/k3s:v1.27.7-k3s1 server \
    --disable traefik \
    --write-kubeconfig-mode 644
K3S_CONTAINER_ID=$(docker ps -aq --filter "name=${K3S_CONTAINER_NAME}")
echo "K3s container started with ID: ${K3S_CONTAINER_ID}"

# Wait for k3s to be ready and extract kubeconfig
echo "Waiting for k3s container to be ready and extracting kubeconfig (approx. 30-60 seconds)..."
ATTEMPTS=0
MAX_ATTEMPTS=20 # 20 * 3 seconds = 60 seconds
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    if docker exec ${K3S_CONTAINER_NAME} test -f /etc/rancher/k3s/k3s.yaml; then
        echo "K3s kubeconfig found in container."
        break
    fi
    echo "Waiting for k3s.yaml... (Attempt $((ATTEMPTS+1))/$MAX_ATTEMPTS)"
    sleep 3
    ATTEMPTS=$((ATTEMPTS+1))
done

# If the loop finished without finding the file, it means it genuinely failed inside the container
if [ $ATTEMPTS -eq $MAX_ATTEMPTS ]; then
    echo "❌ K3s kubeconfig not found in container after multiple attempts. K3s might not have started correctly."
    echo "   Check container logs: docker logs ${K3S_CONTAINER_NAME}"
    exit 1
fi


# Set up kubeconfig for current user
echo "Configuring kubectl access..."
mkdir -p "$HOME/.kube"

# Copy kubeconfig from the container to the host
docker cp ${K3S_CONTAINER_NAME}:/etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"

# Adjust the server IP in the kubeconfig from the container's internal IP to localhost
# This is crucial so kubectl on your host can reach the container via the published port (6443)
if [ -f "$HOME/.kube/config" ]; then
    echo "Adjusting kubeconfig server address to localhost:6443..."
    # Use different sed syntax for macOS vs Linux
    sed -i '' 's/server: https:\/\/127.0.0.1:6443/server: https:\/\/localhost:6443/' "$HOME/.kube/config" || \
    sed -i 's/server: https:\/\/0.0.0.0:6443/server: https:\/\/localhost:6443/' "$HOME/.kube/config" # For Linux/other sed versions
    sudo chown "$USER:staff" "$HOME/.kube/config" || sudo chown "$USER" "$HOME/.kube/config"
    chmod 600 "$HOME/.kube/config"
    export KUBECONFIG="$HOME/.kube/config"
    echo "Kubeconfig configured successfully for kubectl."
else
    echo "❌ Failed to copy kubeconfig from container. Check Docker permissions or container status."
    exit 1
fi

# Install Helm using Homebrew (preferred method for macOS)
echo "Installing Helm via Homebrew..."
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Please install Homebrew: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi
brew install helm

# Handle common kubectl configuration issues
echo "Checking kubectl aliases..."
if alias kubectl 2>/dev/null | grep -q minikube; then
    echo "⚠️  Warning: kubectl is aliased to minikube. Removing alias for this session."
    unalias kubectl 2>/dev/null || true
fi

# Verify kubectl is working with k3s
echo "Testing kubectl connectivity..."
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "❌ kubectl connectivity test failed. Please check:"
    echo "   1. Run: export KUBECONFIG=$HOME/.kube/config (or the correct path)"
    echo "   2. Ensure k3s container is running: docker ps -a --filter name=${K3S_CONTAINER_NAME}"
    echo "   3. Check k3s container logs for errors: docker logs ${K3S_CONTAINER_NAME}"
    echo "   4. Ensure the kubeconfig file ($HOME/.kube/config) exists and has valid content (check for 'localhost:6443')."
    exit 1
fi

echo "✅ kubectl configured successfully"

# Create monitoring namespace
kubectl create namespace monitoring || true

# Use the current k3s-monitoring files from our local directory instead of cloning outdated repo
# The files are already in k3s-monitoring/ subdirectory
cd k3s-monitoring || { echo "Error: k3s-monitoring directory not found. Please ensure it exists."; exit 1; }

# Add prometheus helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install current version of kube-prometheus-stack
# Note: Using --create-namespace and specifying namespace for better organization
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --values kube-prometheus-stack-values.yaml \
    --wait

echo "Waiting for Prometheus service to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s

# Automatically patch Prometheus service to NodePort for container access
echo "Configuring Prometheus for external access via NodePort..."
kubectl patch svc prometheus-kube-prometheus-prometheus -n monitoring -p '{"spec":{"type":"NodePort"}}'

# Wait a moment for the patch to take effect
sleep 5

# Get the NodePort details
PROMETHEUS_NODEPORT=$(kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
# Get host IP for macOS (Docker Desktop makes container localhost accessible)
HOST_IP="localhost"
PROMETHEUS_URL="http://${HOST_IP}:${PROMETHEUS_NODEPORT}"

# Detect container runtime for MCP configuration
CONTAINER_RUNTIME="docker" # Now we are explicitly using docker for k3s itself

# Also patch Grafana for convenience
kubectl patch svc prometheus-grafana -n monitoring -p '{"spec":{"type":"NodePort"}}'
GRAFANA_NODEPORT=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')

echo ""
echo "=============================================="
echo "🎉 Installation Complete!"
echo "=============================================="
echo ""
echo "📊 Prometheus URL: ${PROMETHEUS_URL}"
echo "📈 Grafana URL: http://${HOST_IP}:${GRAFANA_NODEPORT}"
echo "   └─ Username: admin"
echo "   └─ Password: prom-operator"
echo ""
echo "🔧 For your MCP server configuration (mcp.json), add this:"
echo "   (Detected container runtime: ${CONTAINER_RUNTIME})"
echo ""
cat << EOF
{
  "mcpServers": {
    "prometheus": {
      "command": "${CONTAINER_RUNTIME}",
      "transport": "stdio",
      "args": [
        "run",
        "-i",
        "--rm",
        "--network=host", # For Docker Desktop, this should allow connection to localhost ports
        "-e",
        "PROMETHEUS_URL",
        "ghcr.io/pab1it0/prometheus-mcp-server:latest"
      ],
      "env": {
        "PROMETHEUS_URL": "http://localhost:${PROMETHEUS_NODEPORT}"
      }
    }
  }
}
EOF
echo "----------------------------------------"
echo ""
echo "💡 Key configuration notes:"
echo "   • K3s is running inside a Docker container."
echo "   • Docker Desktop handles port forwarding, so 'localhost' is used."
echo "   • External access: ${PROMETHEUS_URL}"
echo "   • Restart Cursor/VS Code after updating mcp.json for changes to take effect"
echo ""
echo "📝 If you need authentication, add these environment variables:"
echo "   PROMETHEUS_USERNAME=your_username"
echo "   PROMETHEUS_PASSWORD=your_password"
echo "   (or PROMETHEUS_TOKEN=your_token for bearer auth)"
echo ""
echo "🔍 To verify Prometheus is working:"
echo "   curl http://localhost:${PROMETHEUS_NODEPORT}/api/v1/query?query=up"
echo "   curl ${PROMETHEUS_URL}/api/v1/query?query=up  # (external access)"
echo ""
echo "⚙️  To make kubectl work in new terminal sessions, add to ~/.zshrc or ~/.bash_profile:"
echo "   export KUBECONFIG=\$HOME/.kube/config"
echo ""
echo "📋 Other useful commands:"
echo "   kubectl get pods -n monitoring"
echo "   kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus"
echo "   docker logs ${K3S_CONTAINER_NAME}"
echo ""
echo "🔧 Troubleshooting MCP connectivity issues:"
echo "   • If 'Connection refused' errors: ensure Docker Desktop is running and healthy."
echo "   • Verify Prometheus is accessible: curl http://localhost:${PROMETHEUS_NODEPORT}/api/v1/query?query=up"
echo ""
echo "🚀 Your prometheus-mcp-server is now ready to connect!"
echo ""