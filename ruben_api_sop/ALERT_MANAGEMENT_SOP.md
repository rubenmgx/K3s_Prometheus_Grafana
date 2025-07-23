# 🚨 Alert Management SOP
## Standard Operating Procedure for Ruben API Alert Response & Management

### 📊 **Alert Dashboard Overview**

**Alert Dashboard**: http://localhost:3000/d/ruben-alerts-dashboard/ruben-alerts  
**Main Dashboard**: http://localhost:3000/d/ruben-api-errors/ruben-test  
**Purpose**: Alert-specific response procedures and alert lifecycle management

---

## 🎯 **Alert Categories & Response Matrix**

### **📋 Alert Inventory (14 Types)**

| Alert Name | Severity | Threshold | Duration | Response Time |
|------------|----------|-----------|----------|---------------|
| `RubenAPIErrorRateCritical` | Critical | >1.0 req/s | 2m | Immediate |
| `RubenAPIErrorRateHigh` | Warning | >0.5 req/s | 5m | 5 minutes |
| `RubenAPIErrorPercentageCritical` | Critical | >10% | 3m | Immediate |
| `RubenAPIErrorPercentageHigh` | Warning | >5% | 5m | 10 minutes |
| `RubenAPI5xxErrorsCritical` | Critical | >0.2 req/s | 1m | Immediate |
| `RubenAPI5xxErrorsWarning` | Warning | >0.05 req/s | 3m | 5 minutes |
| `RubenAPIAuthErrorsCritical` | Critical | >0.5 req/s | 2m | Immediate |
| `RubenAPIAuthErrorsWarning` | Warning | >0.2 req/s | 5m | 10 minutes |
| `RubenAPIClientErrorsHigh` | Warning | >0.5 req/s | 5m | 15 minutes |
| `RubenAPIErrorLatencyHigh` | Warning | P95 >5s | 5m | 10 minutes |
| `RubenAPIErrorLatencyCritical` | Critical | P99 >10s | 3m | Immediate |
| `RubenAPIServerDown` | Critical | up==0 | 1m | Immediate |
| `RubenAPIMethodErrorsHigh` | Warning | >0.3 req/s | 5m | 15 minutes |
| `RubenAPIResourceErrorsHigh` | Warning | >0.2 req/s | 5m | 15 minutes |

---

## 🚨 **Critical Alert Response Procedures**

### **🔥 RubenAPIErrorRateCritical**
**Trigger**: Total error rate >1.0 req/s for 2 minutes

#### **Immediate Actions (0-2 minutes)**
```bash
# 1. Quick assessment
kubectl cluster-info
kubectl get nodes --no-headers | grep -v Ready || echo "Node issues detected"

# 2. API server health check
kubectl get pods -n kube-system -l component=kube-apiserver
kubectl logs -n kube-system -l component=kube-apiserver --tail=20 --since=5m

# 3. Check error breakdown
curl -s "http://localhost:9090/api/v1/query?query=sum(rate(apiserver_request_total{code!~\"2..\",job=\"apiserver\"}[5m]))by(code)"
```

#### **Investigation Steps (2-10 minutes)**
```bash
# 4. Resource exhaustion check
kubectl top nodes
kubectl top pods -n kube-system -l component=kube-apiserver

# 5. etcd connectivity
kubectl get pods -n kube-system -l component=etcd
kubectl exec -n kube-system -l component=etcd -- etcdctl endpoint health

# 6. Recent changes
kubectl get events --sort-by='.lastTimestamp' --field-selector type=Warning | head -10
```

---

### **🔥 RubenAPIErrorPercentageCritical**
**Trigger**: Error percentage >10% for 3 minutes

#### **Immediate Actions (0-3 minutes)**
```bash
# 1. Calculate current percentage
TOTAL_RATE=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(apiserver_request_total{job=\"apiserver\"}[5m]))" | jq -r '.data.result[0].value[1]')
ERROR_RATE=$(curl -s "http://localhost:9090/api/v1/query?query=sum(rate(apiserver_request_total{code!~\"2..\",job=\"apiserver\"}[5m]))" | jq -r '.data.result[0].value[1]')
echo "Error percentage: $(echo "scale=2; ($ERROR_RATE/$TOTAL_RATE)*100" | bc)%"

# 2. Identify primary error types
kubectl logs -n kube-system -l component=kube-apiserver --tail=50 | grep -E "HTTP [4-5][0-9][0-9]" | sort | uniq -c | sort -nr
```

---

### **🔥 RubenAPI5xxErrorsCritical**
**Trigger**: 5xx errors >0.2 req/s for 1 minute

#### **Immediate Actions (0-1 minute)**
```bash
# 1. 5xx errors indicate server-side failures - highest priority
echo "CRITICAL: Server-side errors detected"

# 2. Check API server internal errors
kubectl logs -n kube-system -l component=kube-apiserver --tail=30 | grep -E "(error|Error|ERROR)"

# 3. etcd connection check
kubectl exec -n kube-system -l component=etcd -- etcdctl --endpoints=localhost:2379 endpoint health
```

#### **Root Cause Analysis**
```bash
# 4. Check for common 5xx causes
kubectl describe pod -n kube-system -l component=kube-apiserver | grep -A5 -B5 "Events:"
kubectl get events -n kube-system --field-selector reason=Failed

# 5. Resource pressure check
kubectl describe nodes | grep -A5 "Allocated resources"
```

---

### **🔥 RubenAPIServerDown**
**Trigger**: API server unreachable for 1 minute

#### **Emergency Procedures (0-1 minute)**
```bash
# 1. Immediate availability check
kubectl version --request-timeout=10s || echo "API server unreachable"

# 2. Check API server pod status
kubectl get pods -n kube-system -l component=kube-apiserver --ignore-not-found

# 3. If using K3s in Docker
docker ps | grep k3s-server || echo "K3s container down"
docker logs k3s-server-1 --tail=20 --since=5m
```

#### **Recovery Actions**
```bash
# 4. Restart API server (if pod exists but failing)
kubectl delete pod -n kube-system -l component=kube-apiserver

# 5. Restart K3s container (if container issue)
docker restart k3s-server-1

# 6. Wait and verify
sleep 30
kubectl cluster-info
```

---

## ⚠️ **Warning Alert Response Procedures**

### **🟡 RubenAPIAuthErrorsCritical/Warning**
**Triggers**: Auth errors >0.5 req/s (critical) or >0.2 req/s (warning)

#### **Security Assessment**
```bash
# 1. Count recent authentication failures
AUTH_FAILURES=$(kubectl logs -n kube-system -l component=kube-apiserver --since=10m | grep -c "401\|403\|Unauthorized\|Forbidden")
echo "Auth failures in last 10m: $AUTH_FAILURES"

# 2. Check for patterns (brute force attempts)
kubectl logs -n kube-system -l component=kube-apiserver --since=10m | grep -E "401|403" | awk '{print $1}' | sort | uniq -c | sort -nr | head -5

# 3. Review recent certificate requests
kubectl get certificatesigningrequests | grep Pending

# 4. Check service account usage
kubectl get serviceaccounts --all-namespaces | grep -v default
```

#### **Security Incident Response**
```bash
# 5. If sustained high auth errors (>0.5 req/s for >5 min)
echo "SECURITY INCIDENT: Possible brute force attack"

# 6. Block suspicious clients (if identifiable)
kubectl logs -n kube-system -l component=kube-apiserver --since=15m | grep -E "401|403" | grep -oE "remote IP [0-9.]+" | sort | uniq -c | sort -nr

# 7. Review RBAC bindings
kubectl get clusterrolebindings | grep -v "system:"
```

---

### **🟡 RubenAPIClientErrorsHigh**
**Trigger**: Client errors >0.5 req/s for 5 minutes

#### **Client Analysis**
```bash
# 1. Identify failing clients and reasons
kubectl logs -n kube-system -l component=kube-apiserver --since=10m | grep "40[0-9]" | head -10

# 2. Check for deprecated API usage
kubectl logs -n kube-system -l component=kube-apiserver --since=10m | grep -i "deprecated"

# 3. Resource quota exceeded
kubectl describe quota --all-namespaces | grep -A3 "Resource Quotas"

# 4. Common 4xx error analysis
kubectl logs -n kube-system -l component=kube-apiserver --since=10m | grep -oE "HTTP 4[0-9][0-9]" | sort | uniq -c
```

---

### **🟡 RubenAPIErrorLatencyHigh/Critical**
**Triggers**: P95 >5s (warning) or P99 >10s (critical)

#### **Performance Investigation**
```bash
# 1. Check current latency metrics
curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95, sum(rate(apiserver_request_duration_seconds_bucket{job=\"apiserver\"}[5m])) by (le))"

# 2. Resource contention check
kubectl top nodes
kubectl top pods -n kube-system

# 3. etcd performance
kubectl exec -n kube-system -l component=etcd -- etcdctl --write-out=table endpoint status

# 4. API server resource usage
kubectl describe pod -n kube-system -l component=kube-apiserver | grep -A10 "Requests:"
```

---

## 🔄 **Alert Lifecycle Management**

### **Alert Acknowledgment Process**

#### **1. Initial Response (Within SLA)**
```bash
# Mark alert as acknowledged (example with annotation)
kubectl annotate alert <alert-name> acknowledged="$(date)" acknowledged-by="$USER"

# Document initial assessment
echo "Alert: <alert-name> - Initial assessment: <findings>" >> /tmp/alert-log-$(date +%Y%m%d).txt
```

#### **2. Investigation Documentation**
```markdown
## Alert Investigation Log

**Alert**: <AlertName>
**Time**: $(date)
**Severity**: <Critical/Warning>
**Investigator**: $USER

### Initial Assessment
- Current metric value: X
- Trigger threshold: Y
- Duration: Z minutes

### Investigation Steps
1. [Step 1 and findings]
2. [Step 2 and findings]
3. [Step 3 and findings]

### Root Cause
[Description of root cause]

### Resolution
[Actions taken to resolve]

### Prevention
[Measures to prevent recurrence]
```

### **Alert Escalation Matrix**

| Time Since Alert | Critical Alerts | Warning Alerts | Action Required |
|------------------|-----------------|----------------|-----------------|
| **0-5 minutes** | Self-investigate | Monitor trends | Initial response |
| **5-15 minutes** | Team lead notification | Self-investigate | Detailed analysis |
| **15-30 minutes** | Platform team escalation | Team lead notification | Escalation procedures |
| **30+ minutes** | Emergency response | Platform team escalation | Crisis management |

### **Alert Resolution Procedures**

#### **Successful Resolution**
```bash
# 1. Verify metric has returned to normal
curl -s "http://localhost:9090/api/v1/query?query=<alert-expression>"

# 2. Document resolution
echo "Alert <alert-name> resolved at $(date) - Root cause: <description>" >> /tmp/alert-resolutions.log

# 3. Post-incident review (for critical alerts)
# Schedule within 24-48 hours
```

#### **False Positive Handling**
```bash
# 1. Mark as false positive
kubectl label alert <alert-name> false-positive="true" reason="<explanation>"

# 2. Consider threshold adjustment
echo "Alert <alert-name> - Consider threshold review: <current> -> <suggested>" >> /tmp/alert-tuning.log
```

---

## 📊 **Alert Correlation Analysis**

### **Common Alert Combinations**

#### **Scenario 1: API Server Overload**
```
Firing Alerts:
- RubenAPIErrorRateCritical
- RubenAPIErrorLatencyHigh
- RubenAPI5xxErrorsCritical

Response: Focus on resource scaling and load reduction
```

#### **Scenario 2: Authentication Attack**
```
Firing Alerts:
- RubenAPIAuthErrorsCritical
- RubenAPIErrorPercentageHigh

Response: Security incident procedures
```

#### **Scenario 3: Client Configuration Issues**
```
Firing Alerts:
- RubenAPIClientErrorsHigh
- RubenAPIMethodErrorsHigh
- RubenAPIResourceErrorsHigh

Response: Client configuration review
```

### **Alert Correlation Commands**
```bash
# Check multiple related alerts
kubectl get alerts -l component=api-server --sort-by=.metadata.creationTimestamp

# Correlate with system events
kubectl get events --sort-by='.lastTimestamp' | head -10

# Check alert timing relationships
curl -s "http://localhost:9090/api/v1/query?query=ALERTS{alertname=~\"Ruben.*\", alertstate=\"firing\"}"
```

---

## 🔧 **Alert Tuning & Optimization**

### **Threshold Review Schedule**

#### **Weekly Review**
```bash
# Generate alert frequency report
curl -s "http://localhost:9090/api/v1/query?query=count by (alertname) (increase(ALERTS{alertname=~\"Ruben.*\"}[7d]))"

# Check false positive rate
grep "false-positive" /tmp/alert-log-$(date +%Y%m%d).txt | wc -l
```

#### **Monthly Threshold Optimization**
1. **High-frequency alerts** (>50 triggers/week): Consider increasing thresholds
2. **Never-firing alerts**: Consider decreasing thresholds  
3. **False positives** (>20%): Adjust thresholds or add conditions

### **Alert Silence Management**
```bash
# Temporary silence during maintenance
curl -X POST http://localhost:9093/api/v1/silences \
  -d '{
    "matchers": [{"name": "alertname", "value": "RubenAPI.*", "isRegex": true}],
    "startsAt": "'$(date -Iseconds)'",
    "endsAt": "'$(date -d '+2 hours' -Iseconds)'",
    "createdBy": "'$USER'",
    "comment": "Planned maintenance"
  }'

# List active silences
curl -s http://localhost:9093/api/v1/silences | jq '.data[] | select(.status.state=="active")'
```

---

## 📱 **Quick Reference Commands**

### **Alert Status Check**
```bash
# Current firing alerts
curl -s "http://localhost:9090/api/v1/alerts" | jq '.data.alerts[] | select(.state=="firing") | .labels.alertname'

# Alert dashboard quick access
open "http://localhost:3000/d/ruben-alerts-dashboard/ruben-alerts"

# Alert history (last 24h)
curl -s "http://localhost:9090/api/v1/query?query=increase(ALERTS{alertname=~\"Ruben.*\"}[24h])"
```

### **Emergency Contact Information**
```bash
# Alert management dashboard
echo "Alerts: http://localhost:3000/d/ruben-alerts-dashboard/ruben-alerts"

# Prometheus alerts page  
echo "Prometheus: http://localhost:9090/alerts"

# Main monitoring dashboard
echo "Monitoring: http://localhost:3000/d/ruben-api-errors/ruben-test"
```

---

## 📝 **Alert Response Checklist**

### **For Every Alert**
- [ ] Check alert dashboard: http://localhost:3000/d/ruben-alerts-dashboard/ruben-alerts
- [ ] Verify alert is not a false positive
- [ ] Follow specific alert procedure (above)
- [ ] Document investigation in log
- [ ] Escalate if not resolved within SLA
- [ ] Mark resolved when metrics return to normal

### **For Critical Alerts**
- [ ] Immediate response (within 2 minutes)
- [ ] Notify team lead if not resolved in 15 minutes
- [ ] Escalate to platform team if not resolved in 30 minutes
- [ ] Schedule post-incident review within 48 hours

---

**Alert Management SOP Version**: 1.0  
**Last Updated**: $(date)  
**Owner**: Ruben API Monitoring Team  
**Review Frequency**: Monthly  
**Emergency Contact**: Platform Team 