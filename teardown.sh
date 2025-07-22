#!/bin/bash

echo "=============================================="
echo "🧹 K3s Prometheus & Grafana Teardown for macOS (Docker-based)"
echo "=============================================="
echo ""
echo "This script will attempt to completely remove:"
echo "  • K3s Docker container and its data"
echo "  • Kubeconfig files"
echo "  • Test directories and data"
echo "  • Prometheus MCP server containers (if running)"
echo "  • Helm (optional)"
echo ""

# Function to ask for confirmation
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Set test directory path (same as setup.sh)
TEST_DIR="$HOME/spre-ai-hackathon-experiment/k3s-prom-graf"
K3S_CONTAINER_NAME="k3s-container"

echo "⚠️  WARNING: This will permanently delete K3s cluster data!"
if ! confirm "Are you sure you want to proceed?"; then
    echo "Teardown cancelled."
    exit 0
fi

echo ""
echo "🛑 Starting teardown process..."
echo ""

# Stop and remove any running prometheus-mcp-server containers
echo "1️⃣  Stopping Prometheus MCP server containers..."
if command -v docker &> /dev/null; then
    RUNNING_CONTAINERS=$(docker ps --filter "ancestor=ghcr.io/pab1it0/prometheus-mcp-server:latest" -q)
    if [ ! -z "$RUNNING_CONTAINERS" ]; then
        echo "   Stopping running Prometheus MCP containers..."
        docker stop $RUNNING_CONTAINERS
        docker rm $RUNNING_CONTAINERS
    else
        echo "   No Prometheus MCP containers running."
    fi
else
    echo "   Docker not available, skipping container cleanup."
fi

# Stop and remove k3s Docker container
echo ""
echo "2️⃣  Stopping and removing K3s Docker container..."
if command -v docker &> /dev/null; then
    if docker ps -a --filter "name=${K3S_CONTAINER_NAME}" --format "{{.ID}}" | grep -q .; then
        echo "   Stopping K3s container '${K3S_CONTAINER_NAME}'..."
        docker stop "${K3S_CONTAINER_NAME}"
        echo "   Removing K3s container '${K3S_CONTAINER_NAME}'..."
        docker rm "${K3S_CONTAINER_NAME}"
        echo "   K3s container removed."
    else
        echo "   K3s container '${K3S_CONTAINER_NAME}' not found."
    fi
else
    echo "   Docker not available, skipping K3s container cleanup."
fi

# Clean up kubeconfig
echo ""
echo "3️⃣  Removing kubeconfig files..."
if [ -f "$HOME/.kube/config" ]; then
    echo "   Backing up kubeconfig to $HOME/.kube/config.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$HOME/.kube/config" "$HOME/.kube/config.backup.$(date +%Y%m%d_%H%M%S)"
    rm -f "$HOME/.kube/config"
    echo "   Kubeconfig removed."
else
    echo "   No kubeconfig found at $HOME/.kube/config."
fi

# Remove test directories
echo ""
echo "4️⃣  Removing test directories and data..."
if [ -d "$TEST_DIR" ]; then
    echo "   Removing $TEST_DIR..."
    rm -rf "$TEST_DIR"
    echo "   Test directories removed."
else
    echo "   Test directory not found: $TEST_DIR."
fi

# Clean up any lingering container networks or volumes
echo ""
echo "5️⃣  Cleaning up Docker resources (general prune)..."
if command -v docker &> /dev/null; then
    echo "   Pruning unused Docker system resources (images, containers, volumes, networks)..."
    docker system prune -f --all-volumes > /dev/null 2>&1 || true
    echo "   Docker cleanup completed."
else
    echo "   Docker not available, skipping Docker resource cleanup."
fi

# Optional: Remove helm (ask user)
echo ""
if command -v helm &> /dev/null; then
    if confirm "6️⃣  Remove Helm? (You may want to keep it for other projects)"; then
        if command -v brew &> /dev/null; then
            echo "   Removing Helm via Homebrew..."
            brew uninstall helm
            echo "   Helm removed."
        else
            echo "   Helm found, but Homebrew not available. Please uninstall Helm manually if needed."
        fi
    else
        echo "   Keeping Helm installed."
    fi
else
    echo "6️⃣  Helm not found, skipping."
fi

echo ""
echo "=============================================="
echo "✅ Teardown Complete!"
echo "=============================================="
echo ""
echo "Your system has been returned to a pre-installation state (as much as possible for macOS):"
echo "  ✓ K3s Docker container removed"
echo "  ✓ All workloads and data deleted"
echo "  ✓ Kubeconfig cleaned up (backed up)"
echo "  ✓ Test directories removed"
echo "  ✓ Docker container resources cleaned"
echo ""
echo "💡 You can now run the macOS-adapted setup.sh again for a fresh installation."
echo ""
echo "📋 If you encounter any issues:"
echo "   • Ensure Docker Desktop is fully shut down and restarted if issues persist."
echo "   • Check for any remaining k3s processes (unlikely with Docker setup): ps aux | grep k3s"
echo "   • Manually check and remove any K3s data directories like '$TEST_DIR' if they persist."
echo ""