# MCP Server Usage Notes & Parameter Reference

## Grafana MCP Server (`docker.io/mcp/grafana`)

### Critical Parameter Format Issues

#### ⚠️ `mcp_grafana_update_dashboard` - IMPORTANT PARAMETER STRUCTURE

**WRONG** (what seems logical but fails):
```json
{
  "dashboard": {
    "dashboard": { /* dashboard JSON */ }  // Double-wrapped - FAILS!
  }
}
```

**CORRECT** (what the Go source code expects):
```json
{
  "dashboard": { /* dashboard JSON directly */ },  // Raw dashboard object
  "overwrite": true,
  "message": "Description of changes",
  "folderUid": "optional-folder-uid"
}
```

#### Root Cause Analysis (2025-01-21)
- **Source**: `deps/mcp-grafana/tools/dashboard.go` 
- **Function**: `updateDashboard(ctx context.Context, args UpdateDashboardParams)`
- **Issue**: The `UpdateDashboardParams.Dashboard` field expects `map[string]interface{}` directly
- **Evidence**: Line in source: `Dashboard: args.Dashboard` - passes the field directly to Grafana API

### Other MCP Server Notes

#### Prometheus MCP Server (`ghcr.io/pab1it0/prometheus-mcp-server:latest`)
- **Status**: Working correctly
- **Parameters**: Standard PromQL query patterns work as expected

#### Configuration Reference (`~/.cursor/mcp.json`)
```json
{
  "grafana": {
    "command": "podman",
    "transport": "stdio",
    "args": [
      "run", "--rm", "-i", "--network=host",
      "-e", "GRAFANA_URL", "-e", "GRAFANA_API_KEY",
      "docker.io/mcp/grafana",
      "-transport", "stdio"  // Note: -transport, not -t
    ],
    "env": {
      "GRAFANA_URL": "http://localhost:32652",
      "GRAFANA_API_KEY": "glsa_..."
    }
  }
}
```

### Dashboard JSON Requirements (Grafana v11.4.0)

#### Mandatory Fields for All Panels:
- `"pluginVersion": "v11.4.0"`
- `"datasource": {"type": "prometheus", "uid": "prometheus"}` (both type AND uid)
- `"format": "time_series"` in targets
- Panel-specific `options` objects

#### Mandatory Top-Level Dashboard Fields:
- `"schemaVersion": 39` (must match Grafana version)
- `"templating": {"list": []}` (even if empty)
- `"timepicker": {"refresh_intervals": ["30s", "1m", "5m"]}`

#### Panel-Specific Requirements:
- **Stat panels**: Must have `"options": {"reduceOptions": {"calcs": ["lastNotNull"], "values": false}}`
- **Timeseries panels**: Need `"custom": {"drawStyle": "line", "lineWidth": 2, "fillOpacity": 10, "showPoints": "never"}` in fieldConfig
- **Table panels**: Require `"options": {"showHeader": true}`

### Debugging History
- **Date**: 2025-01-21
- **Issue**: Multiple failed `mcp_grafana_update_dashboard` calls with schema violations
- **Resolution**: Source code analysis revealed parameter structure mismatch
- **Success**: Dashboard creation worked immediately after parameter format correction

### Best Practices
1. **Always verify MCP tool parameter formats** by checking source code when available
2. **Don't assume parameter nesting** based on tool names
3. **Test with minimal examples first** before complex dashboards
4. **Keep this reference updated** when discovering new parameter patterns

---
*Last updated: 2025-01-21 after successful dashboard creation debugging* 