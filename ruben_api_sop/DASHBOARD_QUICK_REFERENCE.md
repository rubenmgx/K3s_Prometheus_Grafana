# 📊 Ruben Test Dashboard - Quick Reference Guide

## 🎯 **Dashboard Access**
- **URL**: http://localhost:3000/d/ruben-api-errors/ruben-test
- **Credentials**: admin / prom-operator
- **Refresh Rate**: 30 seconds (automatic)
- **Time Range**: Last 1 hour (adjustable)

---

## 📋 **Panel Overview & Actions**

### **Row 1: Critical Status Indicators**

#### **🚨 Total API Error Rate**
```
Purpose: Overall API server error health
Normal: Green (<0.1 req/s)
Warning: Yellow (0.1-0.5 req/s) → Monitor for 15 min
Critical: Red (>1.0 req/s) → Immediate action required
```
**Quick Action**: If red, check API server logs immediately

#### **📊 API Error Percentage**
```
Purpose: Error rate as percentage of total requests
Normal: Green (<1%)
Warning: Yellow (1-5%) → Investigate error types
Critical: Red (>10%) → Escalate to incident
```
**Quick Action**: If >5%, check error breakdown by status code

---

### **Row 2: Error Analysis**

#### **🔥 API Error Rate by Status Code**
```
Key Insights:
- Red lines (5xx): Server errors - highest priority
- Orange lines (4xx): Client errors - config issues
- Trend: Look for spikes or sustained increases
```
**Quick Action**: Focus on 5xx errors first

---

### **Row 3: Error Breakdown**

#### **🎯 API Errors by HTTP Method**
```
Common Patterns:
- GET errors: Usually permissions/resource missing
- POST/PUT errors: RBAC or validation failures  
- DELETE errors: Permission or dependency issues
- WATCH errors: Client disconnections
```

#### **🗂️ API Errors by Resource Type**
```
Priority Resources:
- pods: Most common - check deployments
- services: Network/endpoint issues
- secrets/configmaps: Permission problems
- nodes: Cluster health issues
```

---

### **Row 4: Error Severity Indicators**

#### **💥 5xx Internal Errors**
```
Severity: CRITICAL
Target: 0 req/s
Any value requires immediate investigation
Common causes: etcd issues, resource exhaustion
```

#### **🔐 Authentication Errors (401/403)**
```
Severity: SECURITY
Target: <0.1 req/s
Monitor for: Brute force attempts, misconfigured clients
Red threshold: >0.5 req/s
```

#### **👤 Client Errors (4xx)**
```
Severity: MEDIUM
Target: <0.1 req/s
Common causes: Misconfigured clients, deprecated APIs
Red threshold: >0.5 req/s
```

---

### **Row 5: Performance Impact**

#### **⏱️ Error Response Latency (P95/P99)**
```
P95 Thresholds:
- Green: <1s
- Yellow: 1-5s  
- Red: >5s

P99 Thresholds:
- Green: <2s
- Yellow: 2-10s
- Red: >10s
```
**Quick Action**: High latency may indicate resource contention

---

### **Row 6: Error Summary**

#### **📋 Error Summary Table**
```
Features:
- Real-time current error rates
- Auto-sorted by error rate (highest first)
- Color-coded cells (red = high error rate)
- Instant overview of all error types
```

---

## ⚡ **Quick Troubleshooting Actions**

### **🔴 If Dashboard Shows Critical Errors**

```bash
# 1. Quick cluster health check
kubectl cluster-info
kubectl get nodes

# 2. API server status
kubectl get pods -n kube-system | grep kube-apiserver

# 3. Recent logs
kubectl logs -n kube-system <kube-apiserver-pod> --tail=20
```

### **🟡 If Dashboard Shows Warnings**

```bash
# 1. Error pattern analysis
kubectl logs -n kube-system <kube-apiserver-pod> | grep -E "40[0-9]|50[0-9]" | tail -10

# 2. Resource check
kubectl top nodes
kubectl top pods -n kube-system
```

### **🔐 If Authentication Errors Spike**

```bash
# 1. Check for auth failures
kubectl logs -n kube-system <kube-apiserver-pod> | grep -i "unauthorized\|forbidden"

# 2. Count recent failures
kubectl logs -n kube-system <kube-apiserver-pod> | grep "401\|403" | wc -l
```

---

## 🎛️ **Dashboard Controls**

### **Time Range Controls**
- **Last 5m**: Quick troubleshooting
- **Last 1h**: Default monitoring  
- **Last 6h**: Trend analysis
- **Last 24h**: Historical review
- **Custom**: Specific incident timeframe

### **Refresh Controls**
- **30s**: Default auto-refresh
- **1m**: Light monitoring
- **5m**: Background monitoring
- **Off**: Manual refresh only

### **Panel Actions**
- **Click legend**: Hide/show specific metrics
- **Drag zoom**: Focus on time period
- **Panel menu**: View raw data, inspect query
- **Full screen**: Detailed analysis

---

## 🔍 **Panel Query Reference**

### **Error Rate Queries**
```promql
# Total error rate
sum(rate(apiserver_request_total{code!~"2..",job="apiserver"}[5m]))

# Error percentage  
(sum(rate(apiserver_request_total{code!~"2..",job="apiserver"}[5m])) / sum(rate(apiserver_request_total{job="apiserver"}[5m]))) * 100

# 5xx errors only
sum(rate(apiserver_request_total{code=~"5..",job="apiserver"}[5m]))
```

### **Latency Queries**
```promql
# P95 latency for errors
histogram_quantile(0.95, sum(rate(apiserver_request_duration_seconds_bucket{code!~"2..",job="apiserver"}[5m])) by (code, le))

# P99 latency for errors  
histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds_bucket{code!~"2..",job="apiserver"}[5m])) by (code, le))
```

---

## 📱 **Mobile/Quick Access**

### **Essential Checks (30 seconds)**
1. **🚨 Total Error Rate**: Should be green
2. **📊 Error Percentage**: Should be <1%
3. **💥 5xx Errors**: Should be 0
4. **🔐 Auth Errors**: Should be minimal

### **Emergency Numbers**
- **Dashboard URL**: http://localhost:3000/d/ruben-api-errors/ruben-test
- **Direct Grafana**: http://localhost:3000
- **Prometheus**: http://localhost:9090

---

## 🔧 **Customization Tips**

### **Add Custom Alerts**
```yaml
# Add to Prometheus alerts
- alert: HighAPIErrorRate
  expr: sum(rate(apiserver_request_total{code!~"2..",job="apiserver"}[5m])) > 1.0
  for: 5m
  annotations:
    summary: "API server error rate is high"
```

### **Export Dashboard**
```bash
# Save current dashboard
curl -u admin:prom-operator "http://localhost:3000/api/dashboards/uid/ruben-api-errors" > dashboard-backup.json
```

---

**Quick Reference Version**: 1.0  
**Last Updated**: $(date)  
**For**: Ruben Test API Error Dashboard 