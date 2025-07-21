#!/bin/bash

TEST_DIR=$HOME/spre-ai-hackathon-experiment/k3s-prom-graf

mkdir -p $TEST_DIR/etcd-snapshots
mkdir -p $TEST_DIR/etcd-backups

# Install k3s server
curl -sfL https://get.k3s.io | sh -s server - \
        --cluster-init \
        --token "1234" \
        --write-kubeconfig-mode 644 \
        --disable traefik \
        --data-dir=$TEST_DIR/etcd-backups \
        --etcd-snapshot-retention=72 \
        --etcd-snapshot-dir=$TEST_DIR/etcd-snapshots \
        --etcd-snapshot-schedule-cron="*/3 * * * *"

alias k=kubectl # should be in .bashrc, but for now let's try to leave it here

# Install Helm using Fedora's native package manager (preferred method for Fedora)
sudo dnf install helm

# Handle common kubectl configuration issues
echo "Configuring kubectl access..."

# Check for minikube kubectl alias and warn user
if alias kubectl 2>/dev/null | grep -q minikube; then
    echo "⚠️  Warning: kubectl is aliased to minikube. Removing alias for this session."
    unalias kubectl 2>/dev/null || true
fi

# Set up kubeconfig for current user
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $USER:$USER $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config

# Verify kubectl is working with k3s
echo "Testing kubectl connectivity..."
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "❌ kubectl connectivity test failed. Please check:"
    echo "   1. Run: export KUBECONFIG=$HOME/.kube/config"
    echo "   2. Check if you have any kubectl aliases: alias kubectl"
    echo "   3. Ensure k3s is running: sudo systemctl status k3s"
    exit 1
fi

echo "✅ kubectl configured successfully"

# Create monitoring namespace
kubectl create namespace monitoring || true

# Use the current k3s-monitoring files from our local directory instead of cloning outdated repo
# The files are already in k3s-monitoring/ subdirectory
cd k3s-monitoring

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
HOST_IP=$(ip route get 1.1.1.1 | awk '{print $7}' | head -1)
PROMETHEUS_URL="http://${HOST_IP}:${PROMETHEUS_NODEPORT}"

# Detect container runtime for MCP configuration
if command -v docker >/dev/null 2>&1; then
    CONTAINER_RUNTIME="docker"
elif command -v podman >/dev/null 2>&1; then
    CONTAINER_RUNTIME="podman"
else
    CONTAINER_RUNTIME="docker"  # Default fallback
fi

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
echo "----------------------------------------"
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
        "--network=host",
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
echo "   • Using --network=host for container networking compatibility"
echo "   • Using localhost:${PROMETHEUS_NODEPORT} (works better in containers)"
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
echo "⚙️  To make kubectl work in new terminal sessions, run:"
echo "   echo 'export KUBECONFIG=\$HOME/.kube/config' >> ~/.bashrc"
echo ""
echo "📋 Other useful commands:"
echo "   kubectl get pods -n monitoring"
echo "   kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus"
echo ""
echo "🔧 Troubleshooting MCP connectivity issues:"
echo "   • If you get 'Connection refused' errors, ensure --network=host is used"
echo "   • Try 'podman' instead of 'docker' on Fedora/RHEL systems"
echo "   • Verify Prometheus is accessible: curl http://localhost:${PROMETHEUS_NODEPORT}/api/v1/query?query=up"
echo ""
echo "🚀 Your prometheus-mcp-server is now ready to connect!"
echo ""

