# K3s + Prometheus + Grafana Setup for Mac OS

This directory contains scripts for setting up and tearing down a complete Kubernetes monitoring stack on MAcOS, designed for experimenting with Prometheus MCP servers.

## Quick Start

### Setup
```bash
./setup.sh
```

### Teardown
```bash
./teardown.sh
```

## What Gets Installed

- **K3s**: Lightweight Kubernetes distribution
- **Prometheus**: Metrics collection and monitoring
- **Grafana**: Visualization dashboards  
- **AlertManager**: Alert routing and management
- **Helm**: Kubernetes package manager

## Files

- `setup.sh` - Main installation script
- `teardown.sh` - Complete removal script  
- `k3s-monitoring/` - Monitoring stack configuration files

## Integration with Prometheus MCP Server

After running `setup.sh`, you'll get a complete mcp.json configuration snippet that looks like:

```json
{
  "mcpServers": {
    "prometheus": {
      "command": "docker",
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
        "PROMETHEUS_URL": "http://localhost:xxxx"
      }
    },
    "grafana": {
      "command": "docker",
      "transport": "stdio",
      "args": [
        "run",
        "--rm",
        "-i",
        "--network=host",
        "-e",
        "GRAFANA_URL",
        "-e", 
        "GRAFANA_API_KEY",
        "docker.io/mcp/grafana",
        "-transport",
        "stdio"
      ],
      "env": {
        "GRAFANA_URL": "http://localhost:xxxx",
        "GRAFANA_API_KEY": "xxxx"
      }
    }
  }
```

## Experiment Safely

This is designed for experimentation:
- **Setup**: Creates isolated K3s cluster with monitoring
- **Teardown**: Completely removes everything and returns to clean state
- **Repeatable**: Run setup → experiment → teardown → repeat

## Requirements

- At least 4GB RAM recommended
- Internet connection for downloads

## Scripts Details

### setup.sh
- Installs K3s with custom configuration
- Sets up Prometheus + Grafana via Helm
- Configures NodePort access for container integration
- Outputs ready-to-use mcp.json configuration

### teardown.sh  
- Stops all services and containers
- Removes K3s completely
- Cleans up configuration files (with backups)
- Resets network configuration
- Optional Helm removal
- Returns system to pre-installation state


## Security Notes

- Default passwords are used (change for production)
- NodePort services expose monitoring on all interfaces  
- Designed for development/testing environments
- SELinux may require attention on some setups 
