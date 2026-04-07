# MEDCORE Security Audit Report - Critical Vulnerabilities
**Date**: April 3, 2026  
**Scope**: SQL Injection, Input Validation, IDOR, Supabase RLS

---

## EXECUTIVE SUMMARY

**🔴 CRITICAL**: Multiple **IDOR (Insecure Direct Object Reference)** vulnerabilities found where queries fetch ALL records without user/owner authorization checks, allowing users to access other clinics' sensitive data.

**Severity**: HIGH - Data leaks across clinic boundaries

---

## CRITICAL IDOR VULNERABILITIES

### 1. ❌ IDOR: SalesHistoryPage - All Sales/Expenses Access
**File**: [src/pages/SalesHistoryPage.tsx](src/pages/SalesHistoryPage.tsx#L37-L63)  
**Lines**: 37-63  
**Risk**: 🔴 HIGH - Financial data leakage across clinics

```typescript
// VULNERABLE CODE:
const { data: sales = [] } = useQuery({
  queryFn: async () => {
    const { data, error } = await supabase
      .from("pharmacy_sales")
      .select("*, pharmacy_sale_items(*)")
      .order("created_at", { ascending: false });
    // ❌ NO FILTER: All pharmacy sales from all clinics visible!
  },
});

const { data: expenses = [] } = useQuery({
  queryFn: async () => {
    const { data, error } = await supabase
      .from("sales_expenses")
      .select("*")
      .order("created_at", { ascending: false });
    // ❌ NO FILTER: All expenses from all clinics visible!
  },
});

const { data: billingPaid = [] } = useQuery({
  queryFn: async () => {
    const { data, error } = await supabase
      .from("billing_items")
      .select("*")
      .eq("status", "paid");
    // ❌ Only filters by status, not by owner!
  },
});
```

**Impact**: 
- User from Clinic A can see ALL sales/expenses from Clinic B, C, D, etc.
- Financial espionage between competitors
- HIPAA patient billing data exposed

**FIX**:
```typescript
.eq("sold_by", user?.id)          // For sales
.eq("user_id", user?.id)           // For expenses  
.eq("owner_id", user?.id)          // For billing items
```

---

### 2. ❌ IDOR: CommunicationPage - All SMS Logs Visible
**File**: [src/pages/CommunicationPage.tsx](src/pages/CommunicationPage.tsx#L35-L46)  
**Lines**: 35-46  
**Risk**: 🔴 HIGH - PHI leakage through SMS records

```typescript
// VULNERABLE:
const { data: smsLogs = [] } = useQuery({
  queryFn: async () => {
    const { data, error } = await supabase
      .from("sms_logs")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(100);
    // ❌ NO OWNER CHECK: Sees ALL clinic SMS messages!
  },
});
```

**Impact**:
- User A sees SMS messages sent by User B (different clinic)
- Patient phone numbers and appointment details leaked
- HIPAA violation

**FIX**: `.eq("sent_by", user?.id)`

---

### 3. ❌ IDOR: AppointmentsPage - All Clinic Appointments Visible
**File**: [src/pages/AppointmentsPage.tsx](src/pages/AppointmentsPage.tsx#L39-L60)  
**Lines**: 39-60  
**Risk**: 🔴 HIGH - PHI scheduling data leakage

```typescript
// VULNERABLE:
const { data: appointments = [] } = useQuery({
  queryFn: async () => {
    const { data, error } = await supabase
      .from("appointments")
      .select("*")
      .order("appointment_date", { ascending: true });
    // ❌ NO FILTER: All appointments from all clinics!
  },
});

const { data: patients = [] } = useQuery({
  queryFn: async () => {
    const { data, error } = await supabase
      .from("patients")
      .select("id, name, phone, age")
      .order("name");
    // ❌ NO FILTER: All patients from all clinics!
  },
});
```

**Impact**:
- Competitor sees all patient visit schedules
- Patient names and demographics exposed across clinics

**FIX**: 
```typescript
.eq("created_by", user?.id)   // Appointments
.eq("created_by", user?.id)   // Patients
```

---

### 4. ❌ IDOR: StockTrackingPage - All Inventory/Transfers Visible
**File**: [src/pages/StockTrackingPage.tsx](src/pages/StockTrackingPage.tsx#L25-L60)  
**Lines**: 25-60  
**Risk**: 🔴 HIGH - Supply chain intelligence leak

```typescript
// VULNERABLE:
const { data: inventory = [] } = useQuery({
  queryFn: async () => {
    const { data, error } = await supabase
      .from("pharmacy_inventory")
      .select("*")
      .order("drug_name");
    // ❌ NO FILTER: All drugs from all clinics!
  },
});

const { data: transfers = [] } = useQuery({
  queryFn: async () => {
    const { data, error } = await supabase
      .from("store_transfers")
      .select("*")
      .order("created_at", { ascending: false });
    // ❌ NO FILTER: All transfers from all clinics!
  },
});

const { data: saleItems = [] } = useQuery({
  queryFn: async () => {
    const { data, error } = await supabase
      .from("pharmacy_sale_items")
      .select("*")
      .order("created_at", { ascending: false });
    // ❌ NO FILTER: All sale items visible!
  },
});
```

**Impact**:
- Competitor knows drug inventory levels and purchase patterns
- Supply chain forecasting compromised
- Purchasing strategy exposed

**FIX**: 
```typescript
.eq("created_by", user?.id)    // Inventory
.eq("owner_id", user?.id)      // Transfers
// Link sale_items through sales table only
```

---

### 5. ⚠️ IDOR: SettingsPage - Subscription Approval Without Ownership Check
**File**: [src/pages/SettingsPage.tsx](src/pages/SettingsPage.tsx#L612-L642)  
**Lines**: 612-642  
**Risk**: 🔴 HIGH - Financial fraud via payment manipulation

```typescript
// VULNERABLE:
const approveManualPayment = async (paymentId: string) => {
  const { error } = await supabase
    .from("subscriptions")
    .update({
      payment_status: "active",
      verified_by: user?.id || null,
      verified_at: new Date().toISOString(),
    })
    .eq("id", paymentId);  // ❌ NO CHECK: Whose payment is this?
    
  // If attacker knows payment ID, they can approve it for other clinics!
};

const rejectManualPayment = async (paymentId: string) => {
  // Same vulnerability - no ownership verification
  const { error } = await supabase
    .from("subscriptions")
    .update({ payment_status: "rejected", verified_by: user?.id || null })
    .eq("id", paymentId);  // ❌ NO CHECK
};
```

**Impact**:
- Attackers can approve payments belonging to other users
- Can reject legitimate competitor payments
- Subscription hijacking/DoS

**FIX**: Verify payment ownership BEFORE update
```typescript
// 1. Fetch payment to verify ownership
const { data: payment } = await supabase
  .from("subscriptions")
  .select("id, user_id")
  .eq("id", paymentId)
  .eq("user_id", user?.id)  // ← OWNERSHIP CHECK
  .single();

if (!payment) {
  throw new Error("Unauthorized");
}

// 2. Then update with double-check
.eq("id", paymentId)
.eq("user_id", user?.id)  // ← SECOND CHECK
```

---

## MEDIUM SEVERITY ISSUES

### 6. ⚠️ Race Condition: Inventory Stock Deduction
**File**: [src/hooks/use-pharmacy-data.ts](src/hooks/use-pharmacy-data.ts#L175-L193)  
**Lines**: 175-193  
**Risk**: 🟡 MEDIUM - Data consistency, potential overselling

```typescript
// VULNERABLE:
for (const item of items) {
  // Step 1: Read current stock
  const { data: inv } = await supabase
    .from("pharmacy_inventory")
    .select("quantity_in_stock")
    .eq("id", item.inventory_id)
    .single();

  // ⚠️ RACE CONDITION: Between read and write, another sale could occur!
  
  // Step 2: Update stock
  if (inv) {
    await supabase
      .from("pharmacy_inventory")
      .update({ quantity_in_stock: Math.max(0, inv.quantity_in_stock - item.quantity) })
      .eq("id", item.inventory_id);
  }
}
```

**Impact**:
- Inventory can go negative if two sales occur simultaneously
- Financial records become inconsistent
- Drug quantities inaccurate

**FIX**: Use database-level atomic operations via RPC:
```typescript
const { error } = await supabase.rpc('deduct_inventory', {
  p_inventory_id: item.inventory_id,
  p_quantity: item.quantity,
});
```

---

### 7. ⚠️ Dead Code: Unused Authorization Call
**File**: [src/hooks/use-pharmacy-data.ts](src/hooks/use-pharmacy-data.ts#L170-L172)  
**Lines**: 170-172  
**Risk**: 🟡 LOW - Misleading code

```typescript
// VULNERABLE:
const { error: stockError } = await supabase.rpc("has_role", {
  _user_id: user?.id || "",
  _role: "admin",
}); 
// dummy call - we update stock manually  ← COMMENT ADMITS USELESSNESS!

// Stock updates proceed regardless of role!
```

**FIX**: Remove dead code or implement actual authorization

---

## QUERIES WITH PROPER AUTHORIZATION ✅

### BillingPage.tsx - SECURE
```typescript
// ✅ CORRECT: Filters by owner_id
.eq("owner_id", user.id)
```

### DiseaseStatisticsPage.tsx - SECURE  
```typescript
// ✅ CORRECT: Queries by owner_id
.eq("owner_id", user.id)
```

---

## FILE-BY-FILE SUMMARY

| File | Status | Issue |
|------|--------|-------|
| src/pages/SalesHistoryPage.tsx | ❌ VULNERABLE | 3 unfiltered queries |
| src/pages/CommunicationPage.tsx | ❌ VULNERABLE | SMS logs visible to all |
| src/pages/AppointmentsPage.tsx | ❌ VULNERABLE | All appointments visible |
| src/pages/StockTrackingPage.tsx | ❌ VULNERABLE | All inventory visible |
| src/pages/SettingsPage.tsx | ❌ VULNERABLE | No ownership check on payment approval |
| src/pages/BillingPage.tsx | ✅ SECURE | Proper owner filters |
| src/pages/DiseaseStatisticsPage.tsx | ✅ SECURE | Proper owner filters |
| src/hooks/use-pharmacy-data.ts | ⚠️ RISKY | Race condition + dead code |

---

## REMEDIATION CHECKLIST

- [ ] **SalesHistoryPage**: Add `.eq("sold_by", user?.id)` to sales query
- [ ] **SalesHistoryPage**: Add `.eq("user_id", user?.id)` to expenses query  
- [ ] **SalesHistoryPage**: Add `.eq("owner_id", user?.id)` to billing query
- [ ] **CommunicationPage**: Add `.eq("sent_by", user?.id)` to SMS logs
- [ ] **AppointmentsPage**: Add `.eq("created_by", user?.id)` to appointments
- [ ] **AppointmentsPage**: Add `.eq("created_by", user?.id)` to patients
- [ ] **StockTrackingPage**: Add `.eq("created_by", user?.id)` to inventory
- [ ] **StockTrackingPage**: Add `.eq("owner_id", user?.id)` to transfers
- [ ] **SettingsPage**: Add ownership verification in `approveManualPayment()`
- [ ] **SettingsPage**: Add ownership verification in `rejectManualPayment()`
- [ ] **use-pharmacy-data.ts**: Replace read-modify-write with RPC transaction
- [ ] **use-pharmacy-data.ts**: Remove dead code (dummy RPC call)

---

## KEY FINDINGS

✅ **Strong Points**:
- No SQL injection vulnerabilities found (using parameterized queries via Supabase SDK)
- Input validation implemented for phone numbers, amounts, message lengths
- RLS policies exist on many tables
- Rate limiting implemented for SMS/payments

❌ **Critical Gaps**:
- **Missing authorization checks on 5+ major pages**
- **Cross-clinic data leakage in financial records**
- **Patient PHI exposed without authorization**
- **Subscription payment manipulation possible**
- **Race condition in inventory management**

---

**PRIORITY**: Implement all 12 remediation steps  
**TIMELINE**: 2-3 hours of development work  
**IMPACT**: Close critical data leakage vulnerabilities affecting HIPAA/GDPR compliance
