# 🖥️ K3s CPU Monitoring SOP
## Standard Operating Procedure for K3s Cluster CPU Health Management

### 📋 **Quick Health Check (Daily - 2 minutes)**

#### 1. **Access Dashboards**
```bash
# Ensure port forwarding is active
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
```
- **Grafana**: http://localhost:3000 (admin/prom-operator)
- **CPU Dashboard**: http://localhost:3000/d/64f79418-167d-46fc-ac7e-5e23ceacf4bd

#### 2. **Critical Metrics Check**
| Metric | Healthy Range | Warning | Critical |
|--------|---------------|---------|----------|
| **API Server CPU** | <50% | 50-75% | >90% |
| **Node CPU** | <60% | 60-80% | >90% |
| **Load Average (1m)** | <2.0 | 2.0-4.0 | >4.0 |
| **Blocked Processes** | 0 | 1-5 | >5 |
| **Services Up** | 10/10 | 8-9/10 | <8/10 |

### 🚨 **Alert Response Procedures**

#### **High CPU Usage (>80%)**
```bash
# 1. Check top CPU consumers
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top nodes

# 2. Scale down non-critical workloads
kubectl scale deployment <app-name> --replicas=1 -n <namespace>

# 3. Monitor recovery in dashboard
```

#### **High Load Average (>4.0)**
```bash
# 1. Check system processes
kubectl get pods -n monitoring
kubectl describe node

# 2. Restart if needed
kubectl rollout restart deployment -n monitoring
```

#### **Services Down**
```bash
# 1. Check pod status
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# 2. Restart failed components
kubectl delete pod <pod-name> -n monitoring

# 3. Verify recovery
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring
```

### 🔧 **Weekly Maintenance (15 minutes)**

#### **System Cleanup**
```bash
# 1. Clean unused resources
kubectl delete pods --field-selector=status.phase=Succeeded --all-namespaces
kubectl delete pods --field-selector=status.phase=Failed --all-namespaces

# 2. Check cluster resources
kubectl describe nodes | grep -A 5 "Allocated resources"
```

#### **Metrics Validation**
```bash
# 1. Verify Prometheus connectivity
curl -s http://localhost:9090/api/v1/query?query=up | jq '.data.result | length'

# 2. Check data retention
kubectl exec -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -- du -sh /prometheus
```

### 🛠️ **Troubleshooting Commands**

#### **Service Not Responding**
```bash
# Check port forwarding
ps aux | grep "kubectl port-forward"

# Re-establish connections
pkill -f "kubectl port-forward"
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &
```

#### **Dashboard Not Loading**
```bash
# 1. Verify Grafana pod
kubectl logs -n monitoring deployment/prometheus-grafana -f

# 2. Reset Grafana
kubectl rollout restart deployment/prometheus-grafana -n monitoring
kubectl wait --for=condition=available deployment/prometheus-grafana -n monitoring
```

#### **Missing Metrics**
```bash
# 1. Check service monitors
kubectl get servicemonitor -n monitoring

# 2. Verify targets in Prometheus
# Go to: http://localhost:9090/targets

# 3. Restart Prometheus if needed
kubectl delete pod prometheus-prometheus-kube-prometheus-prometheus-0 -n monitoring
```

### 📞 **Emergency Procedures**

#### **Cluster Unresponsive**
```bash
# 1. Check Docker Desktop
docker ps | grep k3s

# 2. Restart K3s container
docker restart k3s-server-1

# 3. Wait for services (5-10 minutes)
kubectl wait --for=condition=ready pod --all -n monitoring --timeout=600s
```

#### **Complete Recovery**
```bash
# Full restart sequence
./teardown.sh
./setup.sh

# Verify dashboard access
echo "Dashboard: http://localhost:3000/d/64f79418-167d-46fc-ac7e-5e23ceacf4bd"
```

### 📊 **Performance Baselines**

#### **Normal Operating Values**
- **API Server CPU**: 5-15%
- **Node CPU**: 20-40%
- **Load Average**: 0.5-1.5
- **Memory Usage**: <70%
- **Response Time**: <100ms

#### **Capacity Planning**
- **Scale Up Trigger**: CPU >70% for 15+ minutes
- **Scale Down Trigger**: CPU <20% for 30+ minutes
- **Resource Limits**: Set container limits to prevent resource starvation

### 📝 **Log Locations**
```bash
# K3s logs
docker logs k3s-server-1

# Monitoring logs
kubectl logs -n monitoring deployment/prometheus-grafana
kubectl logs -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0
```

### 🔄 **Backup & Recovery**
```bash
# Export dashboards
curl -u admin:prom-operator "http://localhost:3000/api/search?type=dash-db" | jq > dashboard-backup.json

# Export Prometheus config
kubectl get prometheusrule -n monitoring -o yaml > prometheus-rules-backup.yaml
```

---
**SOP Version**: 1.0  
**Last Updated**: $(date)  
**Contact**: System Administrator  
**Review Frequency**: Monthly 