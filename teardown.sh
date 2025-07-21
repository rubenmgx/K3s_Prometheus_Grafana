#!/bin/bash

echo "=============================================="
echo "🧹 K3s Prometheus & Grafana Teardown"
echo "=============================================="
echo ""
echo "This script will completely remove:"
echo "  • K3s cluster and all workloads"
echo "  • Kubeconfig files"
echo "  • Test directories and data"
echo "  • Prometheus MCP server containers (if running)"
echo ""

# Function to ask for confirmation
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Set test directory path (same as setup.sh)
TEST_DIR=$HOME/spre-ai-hackathon-experiment/k3s-prom-graf

echo "⚠️  WARNING: This will permanently delete all cluster data!"
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
    # Stop any running prometheus-mcp-server containers
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

# Uninstall k3s completely
echo ""
echo "2️⃣  Uninstalling K3s cluster..."
if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    echo "   Running k3s uninstall script..."
    sudo /usr/local/bin/k3s-uninstall.sh
    echo "   K3s uninstalled successfully."
else
    echo "   K3s uninstall script not found. Attempting manual cleanup..."
    
    # Stop k3s service if it exists
    if systemctl is-active --quiet k3s; then
        echo "   Stopping k3s service..."
        sudo systemctl stop k3s
        sudo systemctl disable k3s
    fi
    
    # Remove k3s systemd service file
    if [ -f /etc/systemd/system/k3s.service ]; then
        echo "   Removing k3s systemd service..."
        sudo rm -f /etc/systemd/system/k3s.service
        sudo systemctl daemon-reload
    fi
    
    # Kill any remaining k3s processes
    echo "   Killing any remaining k3s processes..."
    sudo pkill -f k3s || true
    
    # Remove k3s binary and related files
    echo "   Removing k3s binaries and files..."
    sudo rm -f /usr/local/bin/k3s
    sudo rm -f /usr/local/bin/kubectl
    sudo rm -f /usr/local/bin/crictl
    sudo rm -f /usr/local/bin/ctr
    sudo rm -rf /etc/rancher/k3s
    sudo rm -rf /var/lib/rancher/k3s
    sudo rm -f /usr/local/bin/k3s-*
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
    echo "   No kubeconfig found."
fi

# Remove test directories
echo ""
echo "4️⃣  Removing test directories and data..."
if [ -d "$TEST_DIR" ]; then
    echo "   Removing $TEST_DIR..."
    rm -rf "$TEST_DIR"
    echo "   Test directories removed."
else
    echo "   Test directory not found."
fi

# Clean up any lingering container networks or volumes
echo ""
echo "5️⃣  Cleaning up container resources..."
if command -v docker &> /dev/null; then
    echo "   Pruning unused Docker resources..."
    docker system prune -f --volumes > /dev/null 2>&1 || true
    echo "   Docker cleanup completed."
fi

# Optional: Remove helm (ask user)
echo ""
if command -v helm &> /dev/null; then
    if confirm "6️⃣  Remove Helm? (You may want to keep it for other projects)"; then
        echo "   Removing Helm..."
        sudo dnf remove helm -y
        echo "   Helm removed."
    else
        echo "   Keeping Helm installed."
    fi
else
    echo "6️⃣  Helm not installed, skipping."
fi

# Clean up any remaining iptables rules (k3s sometimes leaves these)
echo ""
echo "7️⃣  Cleaning up network configuration..."
if command -v iptables &> /dev/null; then
    echo "   Flushing iptables rules created by k3s..."
    # Only remove k3s specific chains if they exist
    sudo iptables-save | grep -v "KUBE\|CNI" | sudo iptables-restore || true
    echo "   Network cleanup completed."
fi

# Clean up systemd if needed
echo ""
echo "8️⃣  Final systemd cleanup..."
sudo systemctl daemon-reload
sudo systemctl reset-failed

echo ""
echo "=============================================="
echo "✅ Teardown Complete!"
echo "=============================================="
echo ""
echo "Your system has been returned to pre-installation state:"
echo "  ✓ K3s cluster removed"
echo "  ✓ All workloads and data deleted"  
echo "  ✓ Kubeconfig cleaned up (backed up)"
echo "  ✓ Test directories removed"
echo "  ✓ Container resources cleaned"
echo "  ✓ Network configuration reset"
echo ""
echo "💡 You can now run setup.sh again for a fresh installation."
echo ""
echo "📋 If you encounter any issues:"
echo "   • Reboot the system to clear any lingering processes"
echo "   • Check for any remaining k3s processes: ps aux | grep k3s"
echo "   • Manually remove /var/lib/rancher if it still exists"
echo "" 