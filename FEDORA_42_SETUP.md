# K3s Prometheus & Grafana Setup for Fedora 42

Updated setup guide for running K3s with Prometheus and Grafana monitoring on Fedora 42.

## Prerequisites

- Fedora 42 system with sudo access
- At least 4GB RAM recommended
- Internet connection for downloading packages and container images

## Running the Setup

```bash
cd k3s-prom-graf-setup
chmod +x setup.sh
./setup.sh
```

## After Installation

### Access Grafana
```bash
# Option 1: Port forwarding (recommended for testing)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Option 2: NodePort (if you need external access)
kubectl patch svc prometheus-grafana -n monitoring -p '{"spec":{"type":"NodePort"}}'
kubectl get svc -n monitoring prometheus-grafana
```

Default Grafana credentials:
- Username: `admin`
- Password: `prom-operator`

### Access Prometheus
```bash
# Option 1: Port forwarding
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Option 2: NodePort
kubectl patch svc prometheus-kube-prometheus-prometheus -n monitoring -p '{"spec":{"type":"NodePort"}}'
```

### Access AlertManager
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
```

## Troubleshooting

### If k3s installation fails
```bash
# Check if k3s is running
sudo systemctl status k3s

# View k3s logs
sudo journalctl -u k3s
```

### If kubectl commands fail
```bash
# Ensure kubeconfig is set up
export KUBECONFIG=$HOME/.kube/config
# Or add to ~/.bashrc:
echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc
```

### If pods are not starting
```bash
# Check pod status
kubectl get pods -n monitoring

# Check specific pod logs
kubectl logs -n monitoring <pod-name>

# Check node resources
kubectl describe nodes
```

### SELinux issues (if applicable)
Fedora 42 has SELinux enabled by default. If you encounter permission issues:
```bash
# Check SELinux status
sestatus

# If needed, set SELinux to permissive for testing (not recommended for production)
sudo setenforce 0
```

## Customization

### Email Alerts
Edit `k3s-monitoring/kube-prometheus-stack-values.yaml`:
1. Replace `youremail@gmail.com` with your email
2. Configure SMTP settings for your email provider
3. Re-run helm upgrade:
```bash
cd k3s-monitoring
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --values kube-prometheus-stack-values.yaml
```

### Storage
The default configuration uses:
- 10Gi for Prometheus data (3 day retention)
- 1Gi for AlertManager data

Adjust in the values file if needed.

## Additional Monitoring

The setup includes configuration for:
- Traefik monitoring (if you enable traefik in k3s)
- Blackbox exporter for endpoint monitoring
- Node exporter for system metrics

To add Traefik monitoring:
```bash
cd k3s-monitoring
kubectl apply -f traefik-servicemonitor.yaml
kubectl apply -f traefik-dashboard.yaml
kubectl apply -f traefik-prometheusrule.yaml
```

## Integration with your Prometheus MCP Server

Once this monitoring stack is running, you can:

1. Configure your Prometheus MCP server to connect to: `http://localhost:9090` (or the NodePort)
2. Use the Grafana dashboards at: `http://localhost:3000` (or the NodePort)
3. Access metrics via kubectl port-forward or NodePort services

## Security Notes

- Default passwords should be changed in production
- Consider using ingress with TLS for external access
- NodePort services expose ports on all interfaces - use firewall rules as needed
- The current setup is designed for development/testing - production deployments need additional security hardening 