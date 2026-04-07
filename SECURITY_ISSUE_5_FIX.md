# Security Setup Guide - Critical Issue #5: Server-Side Authentication

## Overview

**Critical Issue #5** addresses a fundamental authentication vulnerability where the application relied on client-side sessionStorage for authorization decisions. This allowed attackers to escalate privileges by tampering with browser storage.

**Status**: ✅ **FIXED** - Server-side authorization validation implemented

---

## The Vulnerability: Before Fix

### Problems Identified:

1. **Unsafe sessionStorage Storage**
   ```typescript
   // VULNERABLE: Stored in plain sessionStorage
   sessionStorage.setItem("currentEmployee", JSON.stringify({ 
     id, name, role, permissions 
   }));
   ```
   - Attackers could open DevTools and modify role/permissions
   - XSS attacks could read/modify all data
   - Data persists until logout

2. **Client-Side-Only Authorization**
   ```typescript
   // VULNERABLE: Checked against untrusted sessionStorage
   const role = (employee?.role || "").toLowerCase();
   const hasPerm = isAdmin || !!employee?.permissions?.[requiredKey];
   ```
   - No server validation before granting access
   - Modified sessionStorage bypassed all checks
   - ProtectedRoute component could be fooled

3. **No Server Endpoint Authorization**
   - Backend routes had no role/permission checks
   - Anyone with auth token could access any endpoint
   - Multi-tenant isolation not enforced

4. **Separate Employee Auth System**
   - Employee login system not tied to Supabase Auth
   - No integration between owner and employee sessions
   - Difficult to enforce consistent security

5. **No Cross-Clinic Isolation**
   - User at Clinic A could modify clinic ID to access Clinic B
   - No server-side verification of clinic ownership
   - Multi-tenant data could leak

---

## The Solution: After Fix

### Architecture Changes

```
┌─────────────────────────────────────────────────────────┐
│                  MEDCORE Frontend                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ ProtectedRoute (enhanced)                         │  │
│  │ - Server-side auth re-validation on every route   │  │
│  │ - Server validates employee permissions           │  │
│  │ - Prevents privilege escalation                   │  │
│  └──────────────────────────────────────────────────┘  │
│                         ↓                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │ EmployeeContext (reduced reliance on storage)     │  │
│  │ - Only stores minimal employee ID/name            │  │
│  │ - NO permissions stored in sessionStorage         │  │
│  │ - All auth decisions validated server-side        │  │
│  └──────────────────────────────────────────────────┘  │
│                         ↓                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │ auth-validation.ts (NEW)                         │  │
│  │ - Helper functions for server auth calls          │  │
│  │ - validateEmployeeAuthorization()                 │  │
│  │ - validateClinicAccess()                          │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
           ↓ HTTPS/TLS only ↓
┌─────────────────────────────────────────────────────────┐
│              MEDCORE Backend (server.ts)                │
│  ┌──────────────────────────────────────────────────┐  │
│  │ NEW Endpoints (Issue #5)                         │  │
│  │  1. POST /auth/validate-employee-permission      │  │
│  │     - Verifies clinic ownership (CRITICAL)       │  │
│  │     - Checks employee is active                  │  │
│  │     - Validates role & permission from DB        │  │
│  │     - Returns: valid, clinicMatch, permMatch     │  │
│  │                                                   │  │
│  │  2. POST /auth/validate-clinic-access            │  │
│  │     - Prevents cross-clinic access               │  │
│  │     - Verifies user owns clinic                  │  │
│  │                                                   │  │
│  │  3. Enhanced Admin Login (from Issue #4)         │  │
│  │     - Server-side password verification          │  │
│  │     - No hardcoded credentials                   │  │
│  └──────────────────────────────────────────────────┘  │
│                         ↓                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Supabase Database (SOURCE OF TRUTH)              │  │
│  │ - admin_credentials (clinic verification)        │  │
│  │ - clinic_employees (employee permissions)        │  │
│  │ - Row Level Security (RLS) policies              │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## Implementation Details

### 1. New Authorization Helpers: `src/lib/auth-validation.ts`

Provides server-side validation functions:

```typescript
// Validate employee has required permission
const result = await validateEmployeeAuthorization(backendUrl, {
  userId: user.id,
  employeeId: employee.id,
  clinicId: clinic.id,
  requiredPermission: "editBills", // Optional
});

if (!result.valid) {
  // Access denied - server says no
  return <Navigate to="/employee-login" />;
}

// Validate clinic ownership
const hasAccess = await validateClinicAccess(
  backendUrl,
  userId,
  clinicId
);
```

### 2. Enhanced ProtectedRoute: `src/components/ProtectedRoute.tsx`

**Before**: Only checked sessionStorage
**After**: Server re-validates on every route access

```typescript
useEffect(() => {
  const validateAuth = async () => {
    // Step 1: Validate clinic access (prevent cross-clinic escalation)
    const clinicValid = await validateClinicAccess(
      backendUrl,
      user.id,
      clinic.id,
      user.id
    );

    if (!clinicValid) {
      setAuthError("You do not have access to this clinic");
      setAuthValid(false);
      return;
    }

    // Step 2: Validate employee permission
    const result = await validateEmployeeAuthorization(backendUrl, {
      userId: user.id,
      employeeId: employee.id,
      clinicId: clinic.id,
      requiredPermission: routePermissionMap[location.pathname],
    });

    setAuthValid(result.valid);
  };
}, [user, employee, location.pathname]); // Re-validate on route change
```

### 3. Reduced sessionStorage Footprint: `src/contexts/EmployeeContext.tsx`

**Before**: Stored full employee object with permissions
**After**: Only stores minimal data (ID, name, role)

```typescript
const setEmployee = (emp: EmployeeSession | null) => {
  setEmployeeState(emp);
  if (emp) {
    // SECURITY: Only store minimal required data
    sessionStorage.setItem("currentEmployee", JSON.stringify({
      id: emp.id,
      name: emp.name,
      role: emp.role,
      // NOTE: permissions NOT stored - always fetch from server
    }));
  }
};
```

### 4. Secure Logout: `src/lib/secure-logout.ts`

**New** comprehensive logout that clears all traces:

```typescript
async function secureLogout(options?: SecureLogoutOptions): Promise<void> {
  // Step 1: Sign out from Supabase
  await supabase.auth.signOut({ scope: "local" });

  // Step 2: Clear ALL sessionStorage (employee, tokens, OTP data)
  sessionStorage.removeItem("currentEmployee");
  sessionStorage.removeItem("otpSessionId");
  sessionStorage.removeItem("pendingOtpVerification");
  // ... etc

  // Step 3: Clear localStorage
  localStorage.removeItem("clinic_id");
  localStorage.removeItem("user_id");
  // ... etc

  // Step 4: Clear browser cache
  const cacheNames = await caches.keys();
  await Promise.all(cacheNames.map(name => caches.delete(name)));

  // Step 5: Redirect to login
  window.location.href = "/login";
}
```

### 5. Server-Side Authorization Endpoints

**New endpoints in `backend/server.ts`:**

#### POST /auth/validate-employee-permission

```typescript
// Request
{
  userId: "user-123",
  employeeId: "emp-456",
  clinicId: "clinic-789",
  requiredPermission: "editBills", // Optional
  requiredRole: ["doctor", "administrator"] // Optional
}

// Response - SERVER IS SOURCE OF TRUTH
{
  valid: true,
  clinicMatch: true,        // CRITICAL: Clinic ownership verified
  permissionMatch: true,     // Role/permission from database
  employee: {
    id: "emp-456",
    role: "administrator",
    permissions: { ... }
  }
}
```

Flow:
1. ✅ Verify clinic ownership (prevent cross-clinic access)
2. ✅ Retrieve employee from Supabase (not sessionStorage!)
3. ✅ Check employee is active
4. ✅ Validate role/permission against database
5. ✅ Return authoritative answer

#### POST /auth/validate-clinic-access

```typescript
// Request
{
  userId: "user-123",
  clinicId: "clinic-789"
}

// Response
{
  valid: true  // User owns this clinic
}
```

---

## Security Benefits

| Vulnerability | Before | After | Benefit |
|---|---|---|---|
| sessionStorage manipulation | ❌ No validation | ✅ Server re-validates | Attacker cannot escalate privileges |
| Cross-clinic access | ❌ No server check | ✅ Server verifies ownership | Multi-tenant isolation enforced |
| XSS exposure | ❌ Permissions in storage | ✅ Not stored client-side | XSS doesn't leak permissions |
| Stale permissions | ❌ Cached in browser | ✅ Fetched on re-auth | Permission changes take effect immediately |
| Privilege escalation | ❌ Client-side only | ✅ Server enforces | Tampering has no effect |

---

## Testing Checklist

### 1. Tamper with sessionStorage
```javascript
// In browser console
JSON.parse(sessionStorage.getItem('currentEmployee'))
// Modify role to 'administrator'
sessionStorage.setItem('currentEmployee', 
  JSON.stringify({ id: 'x', name: 'x', role: 'administrator' }));
// Refresh page
// Expected: ProtectedRoute calls backend, server denies access ✅
```

### 2. Test Role Changes
- Log in as cashier
- Try accessing /dashboard/doctor (requires doctor role)
- Expected: Access denied ✅

### 3. Test Cross-Clinic Access
- Create two clinic accounts
- Modify clinic ID in sessionStorage for Clinic A to access Clinic B
- Try navigating to /dashboard/billing
- Expected: Backend validates clinic ownership, denies access ✅

### 4. Test Secure Logout
- Log in as any role
- Click Logout
- Check sessionStorage: should be empty
- Check localStorage: sensitive data cleared
- Try navigating to /dashboard directly
- Expected: Redirected to /login ✅

### 5. Test Permission Caching
- Log in as employee with "editBills" permission
- Access /dashboard/billing (should work)
- From another admin account, remove "editBills" permission
- Refresh page
- Expected: Access denied (permission validated from server) ✅

### 6. Test OTP with Auth Validation
- Enable OTP in clinic settings
- Log in with OTP required
- Tamper with sessionStorage after OTP
- Expected: Protected routes still re-validate, cannot bypass

---

## Deployment Checklist

### Before Deploying:

- [ ] Run `npm run build` - no errors
- [ ] Run `npm run lint` - no errors  
- [ ] Run `npm run type-check` - no errors
- [ ] Test all scenarios in Testing Checklist
- [ ] Verify backend deployment (new endpoints available)
- [ ] Verify CORS configuration includes auth endpoint
- [ ] Verify Supabase is properly configured
- [ ] Run production build locally and test

### Environment Variables:

Ensure these are set in production:
```env
VITE_BACKEND_URL=https://your-api.example.com
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
NODE_ENV=production
```

### Post-Deployment:

- [ ] Monitor server logs for auth validation errors
- [ ] Check for any failed authorization attempts (may indicate bugs)
- [ ] Wait 1-2 hours for any real-time issues to surface
- [ ] Verify logout clears all data (spot check in private browser)

---

## Affected Components

### Modified Files:
- `src/contexts/AuthContext.tsx` - No changes (already good)
- `src/contexts/EmployeeContext.tsx` - ✅ Reduced sessionStorage
- `src/components/ProtectedRoute.tsx` - ✅ Added server validation
- `src/components/DashboardSidebar.tsx` - ✅ Added secure logout
- `backend/server.ts` - ✅ Added auth validation endpoints

### New Files:
- `src/lib/auth-validation.ts` - New helpers for server validation
- `src/lib/secure-logout.ts` - New secure logout functionality

### No Changes Required:
- `src/pages/EmployeeLoginPage.tsx` - Login flow unchanged
- `src/lib/employee-auth.ts` - Helpers still valid

---

## FAQ

**Q: Why not use Supabase Custom Claims?**
A: Custom claims are a better long-term solution, but require migrating employee data from Firestore to Supabase Auth. This is planned for Issue #6 (IDOR). For now, we query the database directly.

**Q: What if the backend is down?**
A: ProtectedRoute will show a loading spinner, then error message. User must wait for backend recovery. Better to have failures than security holes.

**Q: Can users still be offline?**
A: For now, app requires backend connectivity for every route. Offline support would require offline-capable tokens (JWT), which has tradeoffs. Evaluate for future release.

**Q: How do we handle session token expiry?**
A: Supabase session includes expiry. When expired, re-validation fails, user is redirected to login. This is automatic.

**Q: What about API endpoints accessed by JavaScript?**
A: Any JavaScript making API calls should validate server first. Place auth calls before data fetches. Alternatively, add auth header validation to all endpoints.

---

## Related Issues

- **Issue #4**: Admin PIN hardcoding (FIXED)
  - Enhanced admin login with server-side password verification
  - Bcrypt hashing for admin passwords

- **Issue #6**: IDOR / Multi-clinic data leaks  
  - Next: Will implement Row Level Security (RLS) on database
  - Will add per-request user_id/clinic_id checks in Supabase
  - Will enforce clinic isolation at database layer

- **Issue #1**: Exposed API Keys (FIXED)
- **Issue #2**: Hardcoded Keystore Password (FIXED)
- **Issue #3**: Insecure OTP (FIXED)

---

## Summary

**Critical Issue #5** is now FIXED with:

✅ Server-side authorization validation on every route  
✅ Clinic ownership verification (prevent cross-clinic access)  
✅ Reduced sessionStorage footprint (no permissions stored)  
✅ Secure logout clearing all sensitive data  
✅ New backend endpoints for auth validation  
✅ Comprehensive testing strategy  

The application now follows the principle: **"Never trust the client for authorization decisions."**
