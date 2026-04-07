# MEDCORE Authentication & Authorization Security Audit Report
**Date:** April 3, 2026  
**Severity Level:** CRITICAL - Multiple High-Risk Vulnerabilities Detected

---

## Executive Summary

This security audit identified **7 critical vulnerabilities** in the MEDCORE healthcare management system's authentication and authorization mechanisms. These vulnerabilities expose patient data, employee records, financial information, and system integrity to unauthorized access and manipulation.

**Immediate Action Required:** All identified issues should be remediated before production deployment or any handling of real patient data.

---

## Vulnerability Summary Table

| # | Vulnerability | Severity | Type | File(s) | Line(s) |
|---|---|---|---|---|---|
| 1 | Hardcoded Default Administrator PIN | **CRITICAL** | Hardcoded Credentials | EmployeeLoginPage.tsx | 270, 585 |
| 2 | OTP Code Exposed in Browser Console | **CRITICAL** | Information Disclosure | EmployeeLoginPage.tsx | 228 |
| 3 | Weak Password Requirements (6 chars) | **HIGH** | Weak Password Policy | RegisterPage.tsx | 78, 231 |
| 4 | Client-Side Only Permission Validation | **HIGH** | Authorization Bypass | DashboardLayout.tsx, ProtectedRoute.tsx | 58, Various |
| 5 | Employee Data Stored in SessionStorage | **HIGH** | Insecure Session Management | EmployeeContext.tsx | 25, 45 |
| 6 | Client-Side OTP Validation Only | **HIGH** | Authentication Bypass | EmployeeLoginPage.tsx | 235-242 |
| 7 | Missing Permission Checks on DB Operations | **MEDIUM** | Insecure Data Access | SettingsPage.tsx, Various | Multiple |

---

## DETAILED VULNERABILITY ANALYSIS

### 1. HARDCODED DEFAULT ADMINISTRATOR PIN "12345" 🔴 CRITICAL

**Severity:** CRITICAL  
**Type:** Hardcoded Credentials / Weak Authentication

**Location:**
- [src/pages/EmployeeLoginPage.tsx](src/pages/EmployeeLoginPage.tsx#L270)
- [src/pages/EmployeeLoginPage.tsx](src/pages/EmployeeLoginPage.tsx#L585)
- [src/pages/OnboardingTour.tsx](src/pages/OnboardingTour.tsx#L25)
- [src/components/OnboardingTour.tsx](src/components/OnboardingTour.tsx#L25)

**Vulnerable Code:**
```typescript
// Line 270 in EmployeeLoginPage.tsx
if (securityCode.trim() !== "12345") {
  setErrorMsg("Administrator PIN is currently 12345. Enter correct PIN to continue or change password in Settings.");
  // ...
}

// Line 585 display to users
<p className="text-xs mt-1">PIN: <strong>12345</strong> (change in Settings)</p>
```

**Problem:**
- The default administrator PIN is hardcoded as "12345" across multiple files
- This PIN is exposed in UI messages, making it discoverable
- Results in trivial admin account compromise
- Any user with access to the system can become an administrator

**Impact:**
- ✓ Unauthorized administrative access
- ✓ Ability to create/modify/delete employee accounts
- ✓ Ability to escalate privileges of any employee
- ✓ Access to all clinic data, patient records, and financial information

**Proof of Concept:**
```
1. Navigate to /employee-login
2. Select "Administrator" role
3. Enter PIN: 12345
4. Gain full system administrative access
```

**Remediation:**
```typescript
// Generate a random PIN on first run
// Store securely in Firestore encrypted field
// Force immediate change on first login
// Require 8+ alphanumeric characters (not just digits)

// backend/auth-service.ts
const generateSecurePin = (): string => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let pin = '';
  for (let i = 0; i < 10; i++) {
    pin += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return pin;
};
```

---

### 2. OTP CODE EXPOSED IN BROWSER CONSOLE 🔴 CRITICAL

**Severity:** CRITICAL  
**Type:** Information Disclosure (Debugging Code in Production)

**Location:**
- [src/pages/EmployeeLoginPage.tsx](src/pages/EmployeeLoginPage.tsx#L228)

**Vulnerable Code:**
```typescript
// Line 228 - SECURITY RISK: OTP exposed in console logs
console.info(`OTP for employee ${employeeRecord.full_name}: ${code}`);
```

**Problem:**
- One-Time Passwords are logged to the browser console
- Browser dev tools (F12) make this easily accessible to anyone
- Console logs are visible in:
  - Browser history/cache
  - Browser dev tools
  - Network request logs (sometimes)
  - Error reporting services (if integrated)

**Impact:**
- ✓ OTP codes can be intercepted from console logs
- ✓ Bypasses two-factor authentication entirely
- ✓ Anyone with browser access can view current OTP codes
- ✓ If error reporting is enabled, OTPs may be sent to third-party services

**Real Attack Scenario:**
```
1. Attacker gains temporary access to clinic computer (employee's desk)
2. Presses F12 to open dev tools
3. Sees recent OTP codes in console
4. Uses OTP to impersonate employee and access sensitive functions
5. No audit trail of who actually performed the action
```

**Remediation:**
```typescript
// Remove console.info entirely - never log OTPs
// Line 228 should be deleted

// If debugging is needed, use a secure method:
// - Log to Firebase only (server-side)
// - Include timestamp and session ID
// - Never include the actual OTP code
// - Only for authorized admins

const auditOtpGeneration = async (employeeId: string, employeeName: string) => {
  // Audit only that OTP was generated, not the code itself
  await addDoc(collection(db, "audit_logs"), {
    action: "otp_generated",
    employee_id: employeeId,
    employee_name: employeeName,
    timestamp: new Date().toISOString(),
    // Do NOT include the actual OTP code
  });
};
```

---

### 3. WEAK PASSWORD REQUIREMENTS (Minimum 6 Characters) 🔴 HIGH

**Severity:** HIGH  
**Type:** Weak Password Policy

**Location:**
- [src/pages/RegisterPage.tsx](src/pages/RegisterPage.tsx#L78)
- [src/pages/RegisterPage.tsx](src/pages/RegisterPage.tsx#L231)

**Vulnerable Code:**
```typescript
// Line 78 - Registration form validation
if (formData.password.length < 6) return "Password must be at least 6 characters";

// Line 231 - Additional check
if (formData.password.length < 6) {
  toast({ title: "Password must be at least 6 characters", variant: "destructive" });
  return;
}
```

**Problem:**
- Passwords can be as short as 6 characters
- No complexity requirements (uppercase, numbers, symbols)
- Vulnerable to brute-force attacks
- Far below NIST and healthcare industry standards (minimum 12+ chars)
- HIPAA requires "strong passwords" - 6 chars doesn't qualify

**Example Weak Passwords Accepted:**
```
✓ "123456" (numeric only)
✓ "abcdef" (lowercase only)
✓ "passwd" (simple dictionary word)
✓ "qwerty" (keyboard pattern)
```

**Remediation:**
```typescript
// src/lib/password-validator.ts
const validatePassword = (password: string): { isValid: boolean; errors: string[] } => {
  const errors: string[] = [];
  
  if (password.length < 12) {
    errors.push("Password must be at least 12 characters long");
  }
  if (!/[A-Z]/.test(password)) {
    errors.push("Password must contain uppercase letters");
  }
  if (!/[a-z]/.test(password)) {
    errors.push("Password must contain lowercase letters");
  }
  if (!/[0-9]/.test(password)) {
    errors.push("Password must contain numbers");
  }
  if (!/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
    errors.push("Password must contain special characters");
  }
  
  return { isValid: errors.length === 0, errors };
};

// In RegisterPage.tsx
const validationResult = validatePassword(formData.password);
if (!validationResult.isValid) {
  return validationResult.errors.join("\n");
}
```

---

### 4. CLIENT-SIDE ONLY PERMISSION VALIDATION 🔴 HIGH

**Severity:** HIGH  
**Type:** Authorization Bypass / No Server-Side Validation

**Location:**
- [src/components/DashboardLayout.tsx](src/components/DashboardLayout.tsx#L58)
- [src/lib/employee-auth.ts](src/lib/employee-auth.ts#L49-71)

**Vulnerable Code:**
```typescript
// DashboardLayout.tsx line 58 - Client-side only check
useEffect(() => {
  if (!canAccessRoute(currentEmployee, location.pathname)) {
    navigate("/dashboard", { replace: true });
  }
}, [currentEmployee, location.pathname, navigate]);

// employee-auth.ts - Client-side permission verification
export const canAccessRoute = (
  currentEmployee: EmployeeSession | null,
  pathname: string,
): boolean => {
  if (!currentEmployee) return true;
  if (currentEmployee.role?.toLowerCase() === "administrator") return true;
  const key = routePermissionMap[pathname];
  if (!key) return true;
  return !!currentEmployee.permissions?.[key];
};
```

**Problem:**
- All permission checks happen ONLY on the client-side
- No server-side validation before delivering sensitive data
- Firestore rules exist but aren't consistently enforced through Cloud Functions
- Permissions are stored in sessionStorage and can be modified

**Attack Vector 1: Modify Permissions in Browser:**
```javascript
// Attacker opens browser console and runs:
const modifiedEmployee = {
  id: "current-emp",
  name: "Attacker",
  role: "administrator",
  permissions: { 
    editBills: true, 
    dispensary: true, 
    viewReports: true 
  }
};
window.sessionStorage.setItem("currentEmployee", JSON.stringify(modifiedEmployee));
// Now attacker has access to all protected routes
```

**Attack Vector 2: Direct API Calls Bypass UI Checks:**
```javascript
// Attacker bypasses permission checks entirely
const response = await fetch('/api/billing/items', {
  headers: { 'Authorization': 'Bearer <token>' }
});

// No server validates if employee has "editBills" permission
const billData = await response.json();
// Access denied by Firestore rules, BUT rules aren't comprehensive
```

**Impact:**
- ✓ Non-admin employees can escalate privileges
- ✓ Unpermitted users access sensitive modules
- ✓ Billing module accessible without permission
- ✓ Patient data accessible to unauthorized staff

**Remediation:**
```typescript
// Create server-side permission middleware
// backend/middleware/auth.ts
const checkEmployeePermission = async (
  req: Request,
  requiredPermission: string
): Promise<boolean> => {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return false;
  
  // Verify token server-side
  const decoded = await admin.auth().verifyIdToken(token);
  const employeeId = decoded.uid;
  
  // CRITICAL: Query from Firestore to validate permissions
  // Cannot trust client-side claims
  const empDoc = await admin
    .firestore()
    .collection("clinic_employees")
    .doc(employeeId)
    .get();
  
  if (!empDoc.exists) return false;
  
  const data = empDoc.data();
  if (data?.role === "administrator") return true;
  
  return data?.permissions?.[requiredPermission] === true;
};

// In Express routes
app.get("/api/billing/items", 
  async (req: Request, res: Response) => {
    if (!await checkEmployeePermission(req, "editBills")) {
      return res.status(403).json({ error: "Insufficient permissions" });
    }
    // Proceed with request
  }
);
```

---

### 5. EMPLOYEE SESSION DATA STORED IN SESSIONSTORAGE 🔴 HIGH

**Severity:** HIGH  
**Type:** Insecure Session Management

**Location:**
- [src/contexts/EmployeeContext.tsx](src/contexts/EmployeeContext.tsx#L25)
- [src/contexts/EmployeeContext.tsx](src/contexts/EmployeeContext.tsx#L45)

**Vulnerable Code:**
```typescript
// EmployeeContext.tsx lines 25, 45, 47
export const EmployeeProvider = ({ children }: { children: ReactNode }) => {
  useEffect(() => {
    try {
      const stored = sessionStorage.getItem("currentEmployee");
      if (stored) {
        setEmployeeState(JSON.parse(stored));
      }
    } catch {
      setEmployeeState(null);
    }
  }, []);

  const setEmployee = (emp: EmployeeSession | null) => {
    setEmployeeState(emp);
    if (emp) {
      sessionStorage.setItem("currentEmployee", JSON.stringify(emp));
    } else {
      sessionStorage.removeItem("currentEmployee");
    }
  };
};
```

**Problem:**
- Employee session data (ID, name, role, permissions) stored in sessionStorage
- SessionStorage is readable by any JavaScript running on the page
- Can be modified by browser console
- Not protected by HTTPOnly flag (that's only for cookies)
- Persists across page refreshes

**Security Issues:**
1. **XSS Vulnerability:** Any XSS vulnerability can expose employee data
2. **Modification:** As shown in vulnerability #4, data can be modified
3. **Third-Party Script Injection:** Ads, analytics, or compromised libraries can read this
4. **No Encryption:** User role and permissions visible in plain text

**Proof of Concept - Change Own Role to Admin:**
```javascript
// In browser console on any page of the app
const emp = JSON.parse(sessionStorage.getItem("currentEmployee"));
emp.role = "administrator";
emp.permissions = { 
  editBills: true, 
  dispensary: true, 
  viewReports: true,
  manageSalary: true,
  // ... add all permissions
};
sessionStorage.setItem("currentEmployee", JSON.stringify(emp));

// Refresh page - now you appear as admin
location.reload();
```

**Remediation:**
```typescript
// Remove from sessionStorage entirely
// Use secure HTTP-only session cookies instead
// (handled by Supabase/Firebase automatically)

// EmployeeContext.tsx - CORRECTED VERSION
export const EmployeeProvider = ({ children }: { children: ReactNode }) => {
  const [employee, setEmployeeState] = useState<EmployeeSession | null>(null);
  const { user, session } = useAuth(); // Use Supabase session

  // On mount, only fetch required data from server
  useEffect(() => {
    if (!user?.id) {
      setEmployeeState(null);
      return;
    }

    const fetchEmployeeData = async () => {
      try {
        // Fetch from server endpoint with token validation
        const response = await fetch("/api/employee/profile", {
          headers: {
            "Authorization": `Bearer ${session?.access_token}`
          }
        });
        
        if (!response.ok) {
          setEmployeeState(null);
          return;
        }
        
        const data = await response.json();
        setEmployeeState(data);
      } catch (error) {
        console.error("Failed to fetch employee data:", error);
        setEmployeeState(null);
      }
    };

    fetchEmployeeData();
  }, [user?.id, session?.access_token]);

  // Don't store in sessionStorage at all
  // Employee data is stateful in React memory only
  // Survives page refresh via Supabase session
};
```

---

### 6. CLIENT-SIDE OTP VALIDATION ONLY 🔴 HIGH

**Severity:** HIGH  
**Type:** Authentication Bypass / No Server-Side Validation

**Location:**
- [src/pages/EmployeeLoginPage.tsx](src/pages/EmployeeLoginPage.tsx#L235-242)

**Vulnerable Code:**
```typescript
// EmployeeLoginPage.tsx lines 235-242
const verifyOtpCode = async () => {
  if (!pendingEmployee) {
    setErrorMsg("No pending OTP session. Start login again.");
    return;
  }

  if (!enteredOtp || enteredOtp.trim() === "") {
    setErrorMsg("Enter the OTP code.");
    return;
  }

  if (enteredOtp.trim() !== generatedOtp) { // ← CLIENT-SIDE ONLY!
    setErrorMsg("Incorrect OTP code. Please try again.");
    return;
  }

  if (otpExpiryAt && new Date() > otpExpiryAt) { // ← CLIENT-SIDE ONLY!
    setErrorMsg("OTP expired. Resend code and try again.");
    return;
  }

  await completeLogin(pendingEmployee, pendingTargetPath, "otp_verified");
};
```

**Problem:**
- OTP verification happens entirely on the client
- No server-side validation of the OTP
- `generatedOtp` variable can be inspected in browser memory
- Browser console already revealed the OTP (see vulnerability #2)
- Attacker can call `completeLogin()` directly via console

**Attack Scenario:**
```javascript
// Step 1: Attacker inspects OTP in console (vulnerability #2)
// Sees: "OTP for employee John Doe: 428591"

// Step 2: Attacker uses OTP in form
// But OTP verification is client-side only

// Step 3: Even simpler - force complete login bypassing OTP
// In browser console:
const sessionEmployee = {
  id: "target-employee-id",
  name: "Target Employee",
  role: "cashier",
  permissions: { cashier: true }
};
window.sessionStorage.setItem("currentEmployee", JSON.stringify(sessionEmployee));
// Automatically logged in, completely bypassing OTP

// Step 4: Access sensitive modules
// Navigate to /dashboard/billing without OTP verification
```

**Remediation:**
```typescript
// backend/auth-routes.ts
import admin from "firebase-admin";

app.post("/auth/verify-otp", async (req: Request, res: Response) => {
  const { userId, employeeId, enteredOtp } = req.body;
  const token = req.headers.authorization?.split(" ")[1];
  
  if (!token) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  try {
    // Verify the token
    const decoded = await admin.auth().verifyIdToken(token);
    
    if (decoded.uid !== userId) {
      return res.status(403).json({ error: "Token mismatch" });
    }

    // CRITICAL: Fetch OTP from Firestore server-side
    const empDoc = await admin
      .firestore()
      .collection("clinic_employees")
      .doc(employeeId)
      .get();

    if (!empDoc.exists) {
      return res.status(404).json({ error: "Employee not found" });
    }

    const data = empDoc.data();
    const storedOtp = data?.latest_otp;
    const otpExpiry = data?.latest_otp_expires_at;

    // Validate OTP server-side
    if (storedOtp !== enteredOtp) {
      return res.status(403).json({ error: "Invalid OTP" });
    }

    if (new Date(otpExpiry) < new Date()) {
      return res.status(403).json({ error: "OTP expired" });
    }

    // Clear OTP after successful verification
    await admin
      .firestore()
      .collection("clinic_employees")
      .doc(employeeId)
      .update({
        latest_otp: admin.firestore.FieldValue.delete(),
        latest_otp_expires_at: admin.firestore.FieldValue.delete(),
      });

    // Return success - client can now proceed with session
    return res.status(200).json({ 
      success: true,
      message: "OTP verified successfully"
    });

  } catch (error) {
    console.error("OTP verification error (server):", error);
    return res.status(500).json({ error: "Server error" });
  }
});

// Frontend: EmployeeLoginPage.tsx
const verifyOtpCode = async () => {
  // Input validation
  if (!enteredOtp) {
    setErrorMsg("Enter the OTP code.");
    return;
  }

  setLoading(true);
  try {
    // Fetch server-side verification
    const response = await fetch("/auth/verify-otp", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${session?.access_token}`
      },
      body: JSON.stringify({
        userId: user?.id,
        employeeId: pendingEmployee?.id,
        enteredOtp: enteredOtp.trim()
      })
    });

    if (!response.ok) {
      const error = await response.json();
      setErrorMsg(error.error || "OTP verification failed");
      return;
    }

    // Only after server confirms, complete login
    await completeLogin(pendingEmployee, pendingTargetPath, "otp_verified");
  } catch (error) {
    console.error("OTP verification error:", error);
    setErrorMsg("An error occurred. Please try again.");
  } finally {
    setLoading(false);
  }
};
```

---

### 7. MISSING PERMISSION CHECKS ON DATABASE OPERATIONS 🟡 MEDIUM

**Severity:** MEDIUM  
**Type:** Insecure Direct Object References (IDOR) / Missing Authorization

**Location:**
- [src/pages/SettingsPage.tsx](src/pages/SettingsPage.tsx#L434-459) - `savePermissions()`
- [src/pages/BillingPage.tsx](src/pages/BillingPage.tsx#L29-45) - Billing queries
- [src/pages/EmployeeLoginPage.tsx](src/pages/EmployeeLoginPage.tsx#L343-386) - Login queries

**Problem:**
While Firestore rules do include some permission checks, they're not comprehensively enforced during all operations. The client-side logic trusts user input for filtering and doesn't validate that the user owns the data being accessed.

**Example from SettingsPage.tsx:**
```typescript
// Line 434-459 - savePermissions
const savePermissions = async () => {
  if (!permTarget || !user) return;

  try {
    const empRef = doc(db, "clinic_employees", permTarget.id);
    const updateBody: any = { permissions: permState };
    
    // ISSUE: No validation that current user owns this employee record
    // Relies only on Firestore rules
    await updateDoc(empRef, updateBody);
    
    // ... rest of code
  } catch (error) {
    // Error handling
  }
};
```

**Attack Scenario:**
1. Attacker logs in as regular employee
2. Obtains valid Supabase session token
3. Constructs direct Firestore update request to modify another employee's permissions
4. Firestore rules should prevent this, but code doesn't double-check client-side

**Mitigation Status:**
- ✅ **Good:** Firestore rules do check `owner_id` on most operations
- ⚠️ **Concern:** Rules are complex and could have gaps
- ⚠️ **Concern:** No server-side validation layer

**Recommended Fix:**
```typescript
// Add server-side permission validation
const savePermissions = async () => {
  if (!permTarget || !user) return;

  try {
    // Verify ownership server-side before update
    const response = await fetch("/api/employees/permissions", {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${session?.access_token}`
      },
      body: JSON.stringify({
        employeeId: permTarget.id,
        permissions: permState
      })
    });

    if (!response.ok) {
      const error = await response.json();
      toast({ title: "Error", description: error.message, variant: "destructive" });
      return;
    }

    const updated = employees.map(e =>
      e.id === permTarget.id ? { ...e, permissions: permState } : e
    );
    setEmployees(updated);
    toast({ title: "Permissions Updated" });
  } catch (error) {
    toast({ title: "Error", description: "Failed to update permissions", variant: "destructive" });
  }
};
```

---

## Summary of Recommendations

### IMMEDIATE ACTIONS (Do Before Production):

1. **Remove Hardcoded PIN "12345"**
   - Generate random 10-char alphanumeric PIN on first run
   - Force change on first login
   - Don't display in UI

2. **Remove console.info OTP Logging**
   - Delete line 228 from EmployeeLoginPage.tsx
   - Never log OTP codes anywhere
   - Audit OTP generation only

3. **Implement Server-Side Permission Validation**
   - Move all permission checks to backend
   - Use Cloud Functions to validate permissions before data access
   - Don't trust client-side permission state

4. **Remove SessionStorage-Based Sessions**
   - Rely on HTTP-only session cookies from Supabase/Firebase
   - Don't store employee data in sessionStorage
   - Fetch employee data from server on demand

5. **Implement Server-Side OTP Verification**
   - Create `/auth/verify-otp` endpoint
   - Validate OTP on backend before granting access
   - Clear OTP after successful verification

### SHORT-TERM (Within 1 week):

6. **Enforce Strong Password Policy**
   - Minimum 12 characters
   - Require uppercase, lowercase, numbers, and symbols
   - Implement password strength meter
   - Check against common passwords/breaches

7. **Comprehensive Permission Validation Layer**
   - Create backend middleware for all protected endpoints
   - Validate employee owns/has access to requested data
   - Log all permission denials to audit trail

---

## Files That Require Changes

```
CRITICAL:
- src/pages/EmployeeLoginPage.tsx (remove PIN hardcoding, console.info, add server OTP)
- src/pages/RegisterPage.tsx (strengthen password validation)
- src/lib/employee-auth.ts (implement server-side checks)
- backend/server.ts (add permission validation endpoints)

HIGH PRIORITY:
- src/contexts/EmployeeContext.tsx (remove sessionStorage)
- src/components/DashboardLayout.tsx (add real-time server checks)
- src/lib/firebase.ts (add security utilities)

CONFIGURATION:
- firestore.rules (review and expand)
- backend/.env (ensure secure key storage)
```

---

## Compliance Notes

### HIPAA Implications
- Patient data access is not adequately protected (violations of 45 CFR § 164.312(a)(2))
- Audit logs are not tamper-proof (violations of 45 CFR § 164.312(b))
- Passwords don't meet minimum complexity (violations of 45 CFR § 164.308(a)(5)(ii)(I))

### GDPR Implications
- Unauthorized access puts personal data at risk
- Session management is not secure
- Audit trail is insufficient for data processing accountability (violations of GDPR Article 32)

---

## Testing Recommendations

### Manual Testing:
1. ✓ Attempt to change sessionStorage employee role to "admin"
2. ✓ Try to access billing page without permission
3. ✓ Check browser console for OTP codes
4. ✓ Test account takeover with PIN "12345"
5. ✓ Attempt direct Firestore read/write of other clinic's data

### Automated Testing:
1. Write unit tests for password validation
2. Write integration tests for permission checks
3. Write end-to-end tests for complete login flow
4. Implement automated security scanning (SAST)

---

## References

- [OWASP Top 10 2021](https://owasp.org/www-project-top-ten/)
- [NIST Password Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html)
- [Firebase Security Best Practices](https://firebase.google.com/docs/rules)
- [Supabase Security](https://supabase.com/docs/guides/auth/security)

---

**Report Status:** FINAL  
**Reviewed By:** Security Audit  
**Next Review:** After remediation complete
