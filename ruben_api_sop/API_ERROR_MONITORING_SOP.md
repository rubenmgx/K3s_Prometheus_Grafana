# 🚨 API Error Monitoring SOP
## Standard Operating Procedure for Kubernetes API Server Error Management

### 📊 **Dashboard Overview**

**Dashboard Name**: Ruben test  
**Dashboard URL**: http://localhost:3000/d/ruben-api-errors/ruben-test  
**Purpose**: Comprehensive monitoring of Kubernetes API server HTTP errors and performance issues

---

## 🎯 **Critical Thresholds & Alert Levels**

### **Error Rate Thresholds**
| Metric | Green (Normal) | Yellow (Warning) | Orange (High) | Red (Critical) |
|--------|----------------|------------------|---------------|----------------|
| **Total Error Rate** | <0.1 req/s | 0.1-0.5 req/s | 0.5-1.0 req/s | >1.0 req/s |
| **Error Percentage** | <1% | 1-5% | 5-10% | >10% |
| **5xx Internal Errors** | 0 req/s | 0.05-0.1 req/s | 0.1-0.2 req/s | >0.2 req/s |
| **Auth Errors (401/403)** | <0.1 req/s | 0.1-0.2 req/s | 0.2-0.5 req/s | >0.5 req/s |
| **Client Errors (4xx)** | <0.1 req/s | 0.1-0.3 req/s | 0.3-0.5 req/s | >0.5 req/s |

### **Response Time Thresholds**
| Metric | Green | Yellow | Red |
|--------|-------|--------|-----|
| **P95 Error Latency** | <1s | 1-5s | >5s |
| **P99 Error Latency** | <2s | 2-10s | >10s |

---

## 📋 **Daily Monitoring Checklist (5 minutes)**

### **1. Dashboard Access**
```bash
# Ensure Grafana is accessible
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
```
**Access**: http://localhost:3000/d/ruben-api-errors/ruben-test

### **2. Quick Health Assessment**
Check these panels in order:

#### **🚨 Total API Error Rate**
- **Target**: <0.1 req/s
- **Action if Yellow**: Monitor for 15 minutes
- **Action if Red**: Immediate investigation required

#### **📊 API Error Percentage** 
- **Target**: <1%
- **Action if >5%**: Check error breakdown by status code
- **Action if >10%**: Escalate to critical incident

#### **🔥 API Error Rate by Status Code**
- **Focus**: 5xx errors (server issues) vs 4xx errors (client issues)
- **Priority**: 5xx errors require immediate attention

#### **Critical Error Indicators**
- **💥 5xx Internal Errors**: Should be 0 - any value requires investigation
- **🔐 Authentication Errors**: Monitor for security breaches
- **👤 Client Errors**: May indicate misconfigured clients

---

## 🚨 **Error Response Procedures**

### **🔴 CRITICAL: Total Error Rate >1.0 req/s**

#### **Immediate Actions (0-5 minutes)**
```bash
# 1. Check API server pod status
kubectl get pods -n kube-system | grep kube-apiserver
kubectl describe pod -n kube-system <kube-apiserver-pod>

# 2. Check API server logs
kubectl logs -n kube-system <kube-apiserver-pod> --tail=50

# 3. Verify cluster connectivity
kubectl cluster-info
kubectl get nodes
```

#### **Investigation Steps (5-15 minutes)**
```bash
# 4. Check resource usage
kubectl top nodes
kubectl top pods -n kube-system

# 5. Verify etcd health
kubectl get pods -n kube-system | grep etcd
kubectl logs -n kube-system <etcd-pod> --tail=20

# 6. Check for recent deployments
kubectl get events --sort-by='.lastTimestamp' | head -20
```

### **🟡 WARNING: Error Percentage 1-5%**

#### **Assessment Actions**
```bash
# 1. Identify error patterns from dashboard
# - Which status codes are most frequent?
# - Which HTTP methods are failing?
# - Which resources are affected?

# 2. Check specific error types
kubectl logs -n kube-system <kube-apiserver-pod> | grep "error\|ERROR" | tail -10

# 3. Monitor for trends
# - Is error rate increasing or stable?
# - Are errors concentrated in specific time periods?
```

### **🔐 SECURITY: Authentication Errors >0.2 req/s**

#### **Security Response**
```bash
# 1. Check for authentication failures
kubectl logs -n kube-system <kube-apiserver-pod> | grep -i "auth\|forbidden\|unauthorized"

# 2. Review recent certificate activity
kubectl get certificatesigningrequests

# 3. Check service account usage
kubectl get serviceaccounts --all-namespaces
kubectl get clusterrolebindings | grep -v system:

# 4. Monitor for brute force attempts
kubectl logs -n kube-system <kube-apiserver-pod> | grep "401\|403" | wc -l
```

---

## 🔍 **Detailed Investigation Procedures**

### **5xx Internal Server Errors**

#### **Root Cause Analysis**
```bash
# 1. Check API server configuration
kubectl describe pod -n kube-system <kube-apiserver-pod>

# 2. Verify etcd connectivity
kubectl exec -n kube-system <kube-apiserver-pod> -- /bin/sh -c "ps aux | grep etcd"

# 3. Check resource exhaustion
kubectl describe node <master-node>
kubectl top pod -n kube-system <kube-apiserver-pod>

# 4. Review admission controllers
kubectl logs -n kube-system <kube-apiserver-pod> | grep "admission"
```

#### **Common Causes & Solutions**
- **etcd connectivity issues**: Check etcd pod health and storage
- **Resource exhaustion**: Scale API server or add resources
- **Admission controller failures**: Review webhook configurations
- **Certificate issues**: Check API server certificates

### **4xx Client Errors**

#### **Analysis Steps**
```bash
# 1. Identify failing clients
kubectl logs -n kube-system <kube-apiserver-pod> | grep "40[0-9]" | head -20

# 2. Check RBAC permissions
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:<serviceaccount>

# 3. Verify resource quotas
kubectl describe quota --all-namespaces

# 4. Check API versions
kubectl api-versions
kubectl api-resources
```

---

## 📊 **Dashboard Usage Guide**

### **Panel Interpretation**

#### **🚨 Total API Error Rate**
- **Purpose**: Overall system health indicator
- **Normal**: Green background, <0.1 req/s
- **Alert**: Red background indicates critical issues

#### **🔥 API Error Rate by Status Code**
- **5xx Errors (Red line)**: Server-side issues - highest priority
- **4xx Errors (Orange line)**: Client-side issues - review configurations
- **Trend**: Look for spikes or sustained increases

#### **🎯 API Errors by HTTP Method**
- **GET errors**: Usually permission or resource issues
- **POST/PUT/DELETE errors**: Often RBAC or validation failures
- **WATCH errors**: May indicate client disconnections

#### **🗂️ API Errors by Resource Type**
- **pods**: Most common, check workload deployments
- **services**: Network configuration issues
- **secrets/configmaps**: Permission problems

#### **⏱️ Error Response Latency**
- **High latency**: May indicate resource contention
- **P99 >5s**: Critical performance issue
- **Compare**: Error latency vs normal request latency

#### **📋 Error Summary Table**
- **Real-time view**: Current error distribution
- **Color coding**: Red cells indicate high error rates
- **Sorting**: Automatically sorted by highest error rate

---

## 🔧 **Troubleshooting Commands**

### **API Server Health Check**
```bash
# Complete health assessment
kubectl get --raw='/readyz?verbose'
kubectl get --raw='/livez?verbose'
kubectl get --raw='/healthz?verbose'

# Component status
kubectl get componentstatuses

# API server endpoints
kubectl get endpoints kubernetes
```

### **Performance Analysis**
```bash
# Request analysis
kubectl logs -n kube-system <kube-apiserver-pod> | grep -E "latency|duration" | tail -10

# Resource monitoring
kubectl top pod -n kube-system --sort-by=cpu
kubectl top pod -n kube-system --sort-by=memory

# Connection monitoring
ss -tulpn | grep :6443
netstat -an | grep :6443 | wc -l
```

### **Error Pattern Analysis**
```bash
# Error frequency by hour
kubectl logs -n kube-system <kube-apiserver-pod> | grep -E "40[0-9]|50[0-9]" | awk '{print $1, $2}' | cut -d: -f1 | sort | uniq -c

# Most common error codes
kubectl logs -n kube-system <kube-apiserver-pod> | grep -oE "HTTP [0-9]{3}" | sort | uniq -c | sort -nr

# Client identification
kubectl logs -n kube-system <kube-apiserver-pod> | grep -E "40[0-9]|50[0-9]" | grep -oE "User-Agent:[^\"]*" | sort | uniq -c
```

---

## 📞 **Escalation Procedures**

### **Level 1: Self-Resolution (0-15 minutes)**
- Dashboard analysis
- Basic troubleshooting
- Log review
- Simple restarts

### **Level 2: Team Lead (15-30 minutes)**
- **Escalate if**: Error rate >1.0 req/s for >15 minutes
- **Escalate if**: Error percentage >10%
- **Escalate if**: Security incidents (auth errors >0.5 req/s)

### **Level 3: Platform Team (30+ minutes)**
- **Escalate if**: API server pod failures
- **Escalate if**: etcd connectivity issues
- **Escalate if**: Cluster-wide outages

### **Level 4: Emergency Response**
- **Escalate if**: Complete API server unavailability
- **Escalate if**: Data corruption suspected
- **Escalate if**: Security breach confirmed

---

## 🔄 **Recovery Procedures**

### **API Server Restart**
```bash
# 1. Graceful restart (preferred)
kubectl delete pod -n kube-system <kube-apiserver-pod>

# 2. Wait for pod recreation
kubectl wait --for=condition=ready pod -l component=kube-apiserver -n kube-system --timeout=300s

# 3. Verify functionality
kubectl cluster-info
kubectl get nodes
```

### **etcd Recovery**
```bash
# 1. Check etcd health
kubectl get pods -n kube-system -l component=etcd

# 2. If etcd pod failed
kubectl delete pod -n kube-system <etcd-pod>

# 3. Verify etcd cluster
kubectl exec -n kube-system <etcd-pod> -- etcdctl endpoint health
```

### **Full Cluster Recovery**
```bash
# If using K3s in Docker
docker restart k3s-server-1

# Wait for services
kubectl wait --for=condition=ready pod --all -n kube-system --timeout=600s

# Verify all services
kubectl get pods -n monitoring
kubectl get pods -n kube-system
```

---

## 📝 **Incident Documentation**

### **Incident Report Template**
```markdown
## API Error Incident Report

**Date/Time**: 
**Duration**: 
**Severity**: Critical/High/Medium/Low

### Summary
- Error rate reached: X req/s
- Error percentage: X%
- Primary affected services:

### Timeline
- HH:MM - Issue detected
- HH:MM - Investigation started  
- HH:MM - Root cause identified
- HH:MM - Resolution implemented
- HH:MM - Service restored

### Root Cause
[Detailed technical explanation]

### Resolution
[Steps taken to resolve]

### Prevention
[Measures to prevent recurrence]
```

---

## 📚 **Reference Links**

- **Dashboard**: http://localhost:3000/d/ruben-api-errors/ruben-test
- **Prometheus**: http://localhost:9090
- **K8s API Server Docs**: https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/
- **Troubleshooting Guide**: https://kubernetes.io/docs/tasks/debug-application-cluster/debug-cluster/

---

**SOP Version**: 1.0  
**Last Updated**: $(date)  
**Owner**: Ruben API Monitoring Team  
**Review Frequency**: Monthly  
**Emergency Contact**: Platform Team 