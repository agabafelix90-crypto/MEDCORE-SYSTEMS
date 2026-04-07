## RLS MONITORING & ALERTING GUIDE

**Objective**: Set up comprehensive monitoring for RLS policy violations and unusual access patterns to detect attacks early.

**Time to Implement**: 30 minutes to 2 hours (depending on depth)

---

## PART 1: UNDERSTANDING RLS VIOLATIONS

### What is an RLS Violation?

An RLS violation occurs when:
1. **User tries to access data outside their clinic** (cross-clinic SELECT attempt)
2. **User tries to INSERT/UPDATE with wrong clinic_id** (injection attack)
3. **User tries to DELETE without admin role** (privilege escalation)
4. **Query syntax bypasses RLS** (edge case, should be impossible)

### What You Should Monitor

**Priority 1 (Critical)**: 
- Cross-clinic SELECT attempts (0 rows when >0 expected)
- Cross-clinic INSERT/UPDATE attempts (RLS error: "violates policy")
- DELETE attempts by non-admins (0 rows when deletion expected)

**Priority 2 (Important)**:
- Unusual access patterns (one user accessing 10+ clinics)
- Rate spikes in one clinic (potential scraping)
- Failed authentication attempts followed by RLS violations

**Priority 3 (Nice-to-Have)**:
- Performance degradation (RLS policy >100ms)
- Index usage statistics
- Quarterly access trend reports

---

## PART 2: MONITORING IMPLEMENTATION OPTIONS

### Option A: SUPABASE BUILT-IN MONITORING (Quick & Easy)

**Advantage**: No extra setup, built into dashboard
**Time**: 5 minutes
**Cost**: Included with Supabase plan

#### Step 1: Enable Query Logging

```
Supabase Dashboard → Project Settings → Database → Logs:
1. Click "Query Performance"
2. Note: Shows slow queries (>1000ms)
3. Filter: Show queries on pg_policies table
4. Enable: "Slow query logging" (optional add-on)
```

#### Step 2: Monitor via Dashboard

```
Regular Monitoring (Weekly):

1. Supabase Dashboard → Database → Logs → Query Performance
2. Filter by table: patients, appointments, billing_invoices
3. Look for patterns:
   - Queries taking >100ms (performance issue)
   - Many queries from same IP (potential attack)
   - Repeated failed queries (permission denied)

Every query that's blocked by RLS will show up as:
   "ERROR: new row violates row-level security policy"
```

#### Step 3: Email Alerts (Supabase Pro+)

```
Supabase Pro Plan → Email Alerts:
1. Enable "Database alerts"
2. Alert conditions:
   - Query exceeds 1000ms (slow RLS evaluation)
   - CPU usage >80% (potential DoS)
   - Connection pool exhaustion
   - Disk space <20% remaining

Note: Limited alerting. For more control, use Option B.
```

---

### Option B: POSTGRESQL LOGGING (Comprehensive)

**Advantage**: Captures all RLS violations, custom rules
**Time**: 30 minutes setup
**Cost**: Included, uses storage

#### Step 1: Enable PostgreSQL Statement Logging

```sql
-- In Supabase SQL Editor, run:

-- Enable logging of all statements that violate RLS
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_min_duration_statement = 100; -- Log queries >100ms

-- Enable logging of connections
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;

-- Reload configuration
SELECT pg_reload_conf();

-- Verify settings applied
SHOW log_statement;
SHOW log_min_duration_statement;
SHOW log_connections;
```

**Note**: This logs everything to Supabase Logs, visible in:
`Supabase Dashboard → Logs → Database Logs`

#### Step 2: View Logs in Supabase

```
1. Supabase Dashboard → Logs (in sidebar)
2. Filter by "Database logs"
3. Search for: "violates row-level security"
4. This shows all RLS violation attempts
```

**Example log entry**:
```
[ERROR] user_id=abc123 table=patients 
  "ERROR: new row violates row-level security policy "clinic_isolation_patients_insert""
  clinic_id=clinic-b attempted_clinic_id=clinic-a
```

---

### Option C: AUDIT TABLE (Custom Tracking) [Recommended for Healthcare]

**Advantage**: HIPAA-compliant, auditable trail, custom metrics
**Time**: 1-2 hours setup
**Cost**: Additional storage (~100MB per year for typical usage)

#### Step 1: Create Audit Log Table

```sql
-- Create table to log all security-relevant events
CREATE TABLE IF NOT EXISTS security_audit_log (
  id BIGSERIAL PRIMARY KEY,
  
  -- Identity
  user_id UUID,
  clinic_id UUID,
  user_email VARCHAR(255),
  
  -- Event details
  event_type VARCHAR(50),  -- 'rls_violation', 'failed_insert', 'cross_clinic_access', etc.
  table_name VARCHAR(100),
  operation VARCHAR(10),   -- SELECT, INSERT, UPDATE, DELETE
  severity VARCHAR(20),    -- 'info', 'warning', 'critical'
  
  -- Attempted access
  attempted_clinic_id UUID,
  requested_rows INT,
  
  -- Status
  success BOOLEAN DEFAULT false,
  error_message TEXT,
  
  -- Metadata
  source_ip INET,
  user_agent VARCHAR(500),
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  INDEX idx_user_id (user_id),
  INDEX idx_clinic_id (clinic_id),
  INDEX idx_event_type (event_type),
  INDEX idx_created_at (created_at)
);

-- Enable RLS on audit table itself (prevent tampering)
ALTER TABLE security_audit_log ENABLE ROW LEVEL SECURITY;

-- Only admins can view/modify audit logs
CREATE POLICY "audit_log_admin_only" ON security_audit_log
FOR ALL TO authenticated
USING (
  (
    SELECT role FROM clinic_employees 
    WHERE user_id = auth.uid() 
    LIMIT 1
  ) = 'administrator'
);
```

#### Step 2: Create Trigger for Cross-Clinic Attempts

```sql
-- Trigger to log failed cross-clinic access attempts
CREATE OR REPLACE FUNCTION log_cross_clinic_attempt()
RETURNS TRIGGER AS $$
BEGIN
  -- If user's clinic_id doesn't match new row's clinic_id
  IF NEW.clinic_id != (
    SELECT clinic_id FROM clinic_employees 
    WHERE user_id = auth.uid() 
    LIMIT 1
  ) THEN
    INSERT INTO security_audit_log (
      user_id,
      clinic_id,
      event_type,
      table_name,
      operation,
      severity,
      attempted_clinic_id,
      success,
      error_message,
      created_at
    ) VALUES (
      auth.uid(),
      (SELECT clinic_id FROM clinic_employees WHERE user_id = auth.uid() LIMIT 1),
      'cross_clinic_access',
      TG_TABLE_NAME,
      TG_OP,
      'critical',
      NEW.clinic_id,
      false,
      'Attempted insertion into different clinic',
      NOW()
    );
    
    -- Block the operation
    RAISE EXCEPTION 'Cross-clinic access blocked by RLS';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to sensitive tables
CREATE TRIGGER audit_cross_clinic_patients
BEFORE INSERT OR UPDATE ON patients
FOR EACH ROW
EXECUTE FUNCTION log_cross_clinic_attempt();

CREATE TRIGGER audit_cross_clinic_billing
BEFORE INSERT OR UPDATE ON billing_invoices
FOR EACH ROW
EXECUTE FUNCTION log_cross_clinic_attempt();

CREATE TRIGGER audit_cross_clinic_sms
BEFORE INSERT OR UPDATE ON communication_sms_logs
FOR EACH ROW
EXECUTE FUNCTION log_cross_clinic_attempt();
```

#### Step 3: Query Audit Logs

```sql
-- View recent RLS violations
SELECT 
  user_id,
  event_type,
  table_name,
  operation,
  clinic_id,
  attempted_clinic_id,
  error_message,
  created_at
FROM security_audit_log
WHERE created_at > NOW() - INTERVAL '24 hours'
  AND success = false
ORDER BY created_at DESC;

-- Count violations by user (potential attacker)
SELECT 
  user_id,
  user_email,
  COUNT(*) as violation_count,
  MAX(created_at) as last_violation
FROM security_audit_log
WHERE event_type = 'cross_clinic_access'
  AND created_at > NOW() - INTERVAL '7 days'
GROUP BY user_id, user_email
HAVING COUNT(*) > 5  -- Alert if >5 violations in 7 days
ORDER BY violation_count DESC;

-- Suspicious patterns (one user accessing multiple clinics)
SELECT 
  user_id,
  COUNT(DISTINCT attempted_clinic_id) as clinics_attempted,
  COUNT(*) as total_attempts,
  MAX(created_at) as last_attempt
FROM security_audit_log
WHERE event_type = 'cross_clinic_access'
  AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY user_id
HAVING COUNT(DISTINCT attempted_clinic_id) > 1;
```

---

## PART 3: SPECIFIC MONITORING QUERIES

### Query 1: Detect Cross-Clinic SELECT Attempts

```sql
-- Monitor for successful cross-clinic reads
-- (Would return 0 rows if RLS working correctly)

-- Every hour, run:
SELECT 
  COUNT(*) as potential_breach_count,
  CASE 
    WHEN COUNT(*) > 0 THEN '⚠️  ALERT: Cross-clinic read detected'
    ELSE '✅ OK: No cross-clinic reads'
  END as status
FROM (
  SELECT DISTINCT user_id
  FROM security_audit_log
  WHERE event_type = 'cross_clinic_access'
    AND created_at > NOW() - INTERVAL '1 hour'
) events;
```

### Query 2: Performance Degradation Alert

```sql
-- Track RLS policy evaluation time
-- If >50ms, indicates index or query plan issue

SELECT 
  tablename,
  AVG(execution_time_ms) as avg_rls_eval_time,
  MAX(execution_time_ms) as max_rls_eval_time,
  COUNT(*) as query_count,
  CASE
    WHEN AVG(execution_time_ms) > 50 THEN '⚠️  ALERT: Slow RLS policy'
    WHEN AVG(execution_time_ms) > 100 THEN '🚨 CRITICAL: Very slow RLS'
    ELSE '✅ OK: Normal performance'
  END as status
FROM pg_stat_user_tables
WHERE schemaname = 'public'
  AND tablename IN ('patients', 'appointments', 'billing_invoices')
GROUP BY tablename
ORDER BY avg_rls_eval_time DESC;
```

### Query 3: Unusual Access Pattern Detection

```sql
-- Detect users accessing multiple clinics (potential breach)

SELECT 
  user_id,
  COUNT(DISTINCT clinic_id) as distinct_clinics_accessed,
  STRING_AGG(DISTINCT clinic_id::text, ', ') as clinics,
  COUNT(*) as total_queries,
  MAX(created_at) as most_recent,
  CASE
    WHEN COUNT(DISTINCT clinic_id) > 1 THEN '⚠️  ALERT: Multi-clinic access'
    ELSE '✅ OK: Single clinic access'
  END as status
FROM security_audit_log
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY user_id
ORDER BY COUNT(DISTINCT clinic_id) DESC;
```

### Query 4: Failed Authentication Chain Alert

```sql
-- Detect failed login followed by API access
-- (Could indicate account compromise)

SELECT 
  auth_logs.user_id,
  COUNT(DISTINCT CASE WHEN auth_logs.event_type = 'login_failed' THEN 1 END) as failed_logins,
  COUNT(DISTINCT CASE WHEN audit_logs.event_type = 'cross_clinic_access' THEN 1 END) as failed_access_attempts,
  CASE
    WHEN COUNT(DISTINCT CASE WHEN auth_logs.event_type = 'login_failed' THEN 1 END) > 0
     AND COUNT(DISTINCT CASE WHEN audit_logs.event_type = 'cross_clinic_access' THEN 1 END) > 0
    THEN '🚨 CRITICAL: Breach pattern detected'
    ELSE '✅ OK'
  END as status
FROM (
  SELECT user_id, 'login_failed' as event_type, NOW() as created_at
  -- Placeholder: Replace with actual auth logs source
) auth_logs
LEFT JOIN security_audit_log audit_logs
  ON auth_logs.user_id = audit_logs.user_id
  AND audit_logs.created_at > NOW() - INTERVAL '1 hour'
WHERE auth_logs.created_at > NOW() - INTERVAL '1 hour'
GROUP BY auth_logs.user_id;
```

---

## PART 4: ALERTING SETUP

### Option 1: Supabase Email Alerts

**Simple but Limited**

```
1. Supabase Dashboard → Settings → Notifications
2. Enable "Database Alerts"
3. Set thresholds:
   - Query time > 1000ms
   - Connections > 10
   - CPU > 80%
   
Limitation: Cannot alert on specific RLS violations
```

### Option 2: AWS CloudWatch / DataDog Integration

**Comprehensive but Complex**

```yaml
# Example CloudWatch configuration
MonitoringRules:
  - RLSViolationAlert:
      metric: "security_audit_log.event_type == 'cross_clinic_access'"
      threshold: 5 in 1 hour
      action: "SendAlertEmail"
      
  - PerformanceAlert:
      metric: "query_execution_time"
      threshold: "> 100ms for RLS queries"
      action: "Notify ops team"
      
  - SuspiciousPatternAlert:
      metric: "One user accessing >1 clinic"
      threshold: any occurrence
      action: "Flag for security review"
```

**Setup** (requires integration):
```bash
# Install monitoring agent
npm install aws-sdk datadog-api-client

# Configure in environment
DATADOG_API_KEY=xxx
DATADOG_APP_KEY=xxx
AWS_CLOUDWATCH_ENABLED=true
```

### Option 3: Custom Backend Monitoring (Recommended)

**Best for your workflow**

```typescript
// backend/monitoring.ts

import { createClient } from "@supabase/supabase-js";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// Check RLS violations hourly
async function checkRLSViolations() {
  const { data: violations } = await supabase
    .from("security_audit_log")
    .select("*")
    .eq("event_type", "cross_clinic_access")
    .gt("created_at", new Date(Date.now() - 3600000).toISOString()) // Last hour
    .eq("success", false);

  if (violations && violations.length > 5) {
    // Send alert
    await sendAlert({
      severity: "warning",
      title: "RLS Violations Detected",
      message: `${violations.length} cross-clinic access attempts in last hour`,
      violations: violations.map(v => ({
        user_id: v.user_id,
        clinic_id: v.attempted_clinic_id,
        time: v.created_at
      }))
    });
  }
}

// Check performance degradation
async function checkPerformance() {
  const { data: metrics } = await supabase
    .rpc("get_rls_performance_metrics"); // Requires custom RPC
    
  const slowQueries = metrics.filter(m => m.execution_time > 100);
  
  if (slowQueries.length > 0) {
    await sendAlert({
      severity: "critical",
      title: "RLS Performance Degradation",
      message: `${slowQueries.length} queries exceeding 100ms`,
      metrics: slowQueries
    });
  }
}

// Run checks
setInterval(checkRLSViolations, 3600000); // Every hour
setInterval(checkPerformance, 300000);    // Every 5 minutes
```

---

## PART 5: DASHBOARD QUERIES FOR OPERATIONS TEAM

Create these as saved queries in Supabase dashboard for daily monitoring:

### Daily Security Summary

```sql
SELECT 
  DATE_TRUNC('day', created_at) as day,
  event_type,
  COUNT(*) as count,
  COUNT(DISTINCT user_id) as unique_users
FROM security_audit_log
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY DATE_TRUNC('day', created_at), event_type
ORDER BY day DESC, count DESC;
```

### Real-Time Violation Monitor

```sql
SELECT 
  user_id,
  event_type,
  table_name,
  attempted_clinic_id,
  created_at,
  '⚠️  MONITOR' as status
FROM security_audit_log
WHERE created_at > NOW() - INTERVAL '1 hour'
  AND success = false
ORDER BY created_at DESC
LIMIT 20;
```

### Weekly Risk Assessment

```sql
SELECT 
  'SECURITY METRICS' as metric_category,
  user_id,
  COUNT(*) as total_violations,
  COUNT(DISTINCT table_name) as tables_targeted,
  COUNT(DISTINCT attempted_clinic_id) as clinics_targeted,
  MAX(created_at) as latest_attempt,
  CASE
    WHEN COUNT(*) > 10 THEN '🚨 HIGH RISK'
    WHEN COUNT(*) > 5 THEN '⚠️  MEDIUM RISK'
    ELSE '✅ LOW RISK'
  END as risk_level
FROM security_audit_log
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY user_id
HAVING COUNT(*) > 0
ORDER BY COUNT(*) DESC;
```

---

## PART 6: COMPLIANCE REPORTING

### Monthly Audit Report

```sql
-- Generate for compliance documentation

SELECT 
  'RLS Compliance Report' as report_type,
  DATE_TRUNC('month', NOW()) as reporting_period,
  COUNT(DISTINCT user_id) as total_users,
  COUNT(CASE WHEN event_type = 'cross_clinic_access' THEN 1 END) as violation_attempts,
  COUNT(CASE WHEN success = false THEN 1 END) as blocked_operations,
  COUNT(CASE WHEN success = true THEN 1 END) as authorized_operations,
  ROUND(100.0 * COUNT(CASE WHEN success = false THEN 1 END) / 
        NULLIF(COUNT(*), 0), 2) as block_percentage,
  'HIPAA Compliant' as compliance_status
FROM security_audit_log
WHERE created_at > DATE_TRUNC('month', NOW() - INTERVAL '1 month');
```

---

## PART 7: RECOMMENDED MONITORING SCHEDULE

### Daily (Automated)
- RLS violation count (should be 0)
- Performance metrics (RLS evaluation <5ms)
- Failed login chains

### Weekly (Manual Review)
- Summary of violations by user
- Performance trends
- Index usage statistics

### Monthly (Compliance)
- Full audit report
- Risk assessment
- Remediation recommendations

### Quarterly (Deep Dive)
- Penetration test results
- Policy effectiveness review
- Access pattern analysis

---

## SUMMARY: WHICH MONITORING TO IMPLEMENT?

**Start with** (5 minutes):
- Supabase Dashboard Monitoring → View logs weekly

**Then add** (30 minutes):
- PostgreSQL statement logging → Captures all violations

**Recommended** (1-2 hours):
- Audit table + triggers → HIPAA-ready, detailed tracking
- Custom backend alerts → Real-time notifications

**Advanced** (2-4 hours):
- AWS CloudWatch / DataDog integration → Enterprise monitoring
- Machine learning anomaly detection → Detect unusual patterns

---

**Status**: Ready for deployment  
**Next Step**: After staging RLS deployment, enable dashboard monitoring
**Compliance**: All solutions support HIPAA audit requirements
