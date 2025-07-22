# 📁 Ruben API Error Monitoring SOPs

This folder contains comprehensive Standard Operating Procedures for monitoring and managing Kubernetes API server errors using the "Ruben test" Grafana dashboard.

## 📋 **Contents Overview**

### **📖 Core Documentation**

| File | Purpose | Usage |
|------|---------|-------|
| **`API_ERROR_MONITORING_SOP.md`** | Complete operational procedures | Primary reference for incidents |
| **`DASHBOARD_QUICK_REFERENCE.md`** | Dashboard usage guide | Quick troubleshooting actions |
| **`api-error-alerts.yaml`** | Prometheus alert rules | Deploy to enable automated alerts |

---

## 🎯 **Quick Start Guide**

### **1. Access Dashboard**
```bash
# Ensure Grafana is running
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &

# Open dashboard
open http://localhost:3000/d/ruben-api-errors/ruben-test
```

### **2. Daily Monitoring (5 minutes)**
1. Check **🚨 Total API Error Rate** - should be green (<0.1 req/s)
2. Monitor **📊 API Error Percentage** - should be <1%
3. Verify **💥 5xx Internal Errors** - should be 0
4. Review **🔐 Authentication Errors** - watch for spikes

### **3. Alert Setup**
```bash
# Deploy alert rules
kubectl apply -f ruben_api_sop/api-error-alerts.yaml

# Verify alerts are loaded
kubectl get prometheusrule -n monitoring
```

---

## 🚨 **Emergency Procedures**

### **Critical Error Response (Red Dashboard)**
```bash
# 1. Immediate health check
kubectl cluster-info
kubectl get nodes

# 2. API server status  
kubectl get pods -n kube-system | grep kube-apiserver
kubectl logs -n kube-system <kube-apiserver-pod> --tail=50

# 3. Check recent events
kubectl get events --sort-by='.lastTimestamp' | head -10
```

### **Quick Recovery**
```bash
# API server restart (if needed)
kubectl delete pod -n kube-system <kube-apiserver-pod>

# Verify recovery
kubectl wait --for=condition=ready pod -l component=kube-apiserver -n kube-system
```

---

## 📊 **Thresholds Summary**

| Metric | Normal | Warning | Critical |
|--------|---------|---------|----------|
| **Total Error Rate** | <0.1 req/s | 0.1-0.5 req/s | >1.0 req/s |
| **Error Percentage** | <1% | 1-5% | >10% |
| **5xx Errors** | 0 req/s | 0.05-0.1 req/s | >0.2 req/s |
| **Auth Errors** | <0.1 req/s | 0.1-0.2 req/s | >0.5 req/s |
| **Response Latency P95** | <1s | 1-5s | >5s |

---

## 🛠️ **File Usage Guide**

### **📘 For Daily Operations**
- **Start with**: `DASHBOARD_QUICK_REFERENCE.md`
- **Purpose**: Quick dashboard interpretation and immediate actions
- **Time**: 2-5 minutes

### **📚 For Incident Response**
- **Use**: `API_ERROR_MONITORING_SOP.md`
- **Purpose**: Complete troubleshooting procedures and escalation
- **Time**: 15-60 minutes depending on severity

### **⚙️ For Alert Configuration**
- **Deploy**: `api-error-alerts.yaml`
- **Purpose**: Automated monitoring and notifications
- **Setup**: One-time deployment

---

## 🔄 **Maintenance Schedule**

### **Daily (5 minutes)**
- Check dashboard status indicators
- Verify error rates are within normal ranges
- Review any overnight alerts

### **Weekly (15 minutes)**  
- Review error trends and patterns
- Check alert rule effectiveness
- Update thresholds if needed

### **Monthly (30 minutes)**
- Review and update SOPs
- Test alert rules and escalation procedures
- Performance optimization review

---

## 📞 **Escalation Matrix**

| Scenario | Time | Action | Contact |
|----------|------|---------|---------|
| **Error rate >1.0 req/s** | 0-5 min | Self-troubleshoot | - |
| **Sustained high errors** | 15 min | Team Lead | Internal team |
| **API server failure** | 30 min | Platform Team | Platform escalation |
| **Security incidents** | Immediate | Security Team | Security hotline |

---

## 🔗 **Related Resources**

### **Dashboard Links**
- **Ruben Test Dashboard**: http://localhost:3000/d/ruben-api-errors/ruben-test
- **Grafana Home**: http://localhost:3000
- **Prometheus**: http://localhost:9090

### **External Documentation**
- [Kubernetes API Server Troubleshooting](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-cluster/)
- [Prometheus Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)

---

## 📝 **Version Information**

- **Dashboard Version**: 1.0
- **SOP Version**: 1.0
- **Last Updated**: $(date)
- **Maintained By**: Ruben API Monitoring Team
- **Review Frequency**: Monthly

---

## 🤝 **Contributing**

To update these SOPs:

1. **Test changes** in non-production environment
2. **Update version numbers** in affected files
3. **Document changes** in commit messages
4. **Review with team** before deployment

### **Quick Edit Commands**
```bash
# Edit main SOP
vim ruben_api_sop/API_ERROR_MONITORING_SOP.md

# Edit quick reference
vim ruben_api_sop/DASHBOARD_QUICK_REFERENCE.md

# Update alert rules
vim ruben_api_sop/api-error-alerts.yaml
kubectl apply -f ruben_api_sop/api-error-alerts.yaml
```

---

**📖 Start with `DASHBOARD_QUICK_REFERENCE.md` for immediate dashboard usage!** 