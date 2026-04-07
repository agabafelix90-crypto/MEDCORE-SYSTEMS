## Local E2E Testing Guide: Auth Flow & Clinic Isolation

This guide walks you through manual e2e testing of the authentication flow with clinic isolation before deploying to staging.

---

### Prerequisites

1. **Backend running**: `npm run dev` (or use your backend server)
2. **Frontend running**: `npm run dev` in separate terminal
3. **Two test employee accounts** in your database (different clinics)
   - Employee A: clinic_a_uuid, email: doctor.a@clinic-a.local
   - Employee B: clinic_b_uuid, email: doctor.b@clinic-b.local
4. **Have the app open in 2 browser windows** (or tabs) for comparative testing

---

### Test Scenario 1: OTP Request & Verification

**Goal**: Verify OTP flow returns clinic_id on success

#### Steps:

1. **Open app** at http://localhost:5173 (or your dev URL)
2. **Navigate to Employee Login** page
3. **Enter Employee A's email**: doctor.a@clinic-a.local
4. **Click "Send OTP"**
   - ✅ Expected: Success message "OTP sent to your email"
   - ✅ Expected: Session ID displayed or stored (check browser console)
5. **Open browser DevTools**: F12 → Network tab
6. **Observe the OTP request**:
   ```
   POST /auth/request-otp
   Body: { userId: "user-a-1", email: "doctor.a@clinic-a.local" }
   Response: { success: true, sessionId: "session-..." }
   ```
7. **For development**: Check server console for logged OTP (or email inbox if configured)
   - OTP example: `123456`

---

### Test Scenario 2: OTP Verification with Clinic_ID Return (**CRITICAL**)

**Goal**: Verify backend returns clinic_id after OTP verification

#### Steps:

1. **In DevTools Network tab**: Filter for `/auth/verify-otp`
2. **Enter the OTP** from your email/console
3. **Click "Verify OTP"**
4. **Inspect the response** in Network tab:
   ```json
   {
     "verified": true,
     "clinicId": "clinic-a-uuid",      ← ✅ CRITICAL: Must be present
     "employeeId": "emp-a-1",
     "role": "doctor",
     "name": "Dr. Alice"
   }
   ```
   - ✅ Expected: `clinicId` field is present
   - ✅ Expected: Employee ID, role, and name match expected values
5. **Check browser console** (DevTools → Console tab):
   - ✅ Expected: Auth context updated with clinic info
   - ✅ Expected: Session token stored in sessionStorage

---

### Test Scenario 3: Login Success & Dashboard Access

**Goal**: Verify you can access dashboard after successful OTP verification

#### Steps:

1. **After OTP verification**, page should redirect to dashboard
2. **Verify page loads**:
   - ✅ Expected: Sidebar shows clinic name "Clinic A"
   - ✅ Expected: Dashboard displays clinic-specific data
   - ✅ Expected: Patient list shows only Clinic A patients
3. **Check sessionStorage** (DevTools → Application → sessionStorage):
   - ✅ Expected: `auth_clinic_id` = "clinic-a-uuid"
   - ✅ Expected: Auth token is present

---

### Test Scenario 4: Cross-Clinic Access Attempt (RLS Simulation)

**Goal**: Verify clinic isolation - Employee A cannot access Clinic B data

#### Steps:

1. **While logged in as Employee A**, open browser console
2. **Manually try to fetch another clinic's data**:
   ```javascript
   // In browser console:
   const response = await fetch('/api/clinics/clinic-b-uuid/patients', {
     headers: { 'Authorization': `Bearer ${sessionStorage.getItem('auth_token')}` }
   });
   const data = await response.json();
   console.log(data);
   ```
3. **Expected outcomes** (once RLS deployed):
   - ✅ Expected: Network request returns 403 Forbidden OR
   - ✅ Expected: Empty data array (RLS policy blocks the rows)
   - ❌ Wrong: Data from Clinic B appears

4. **Alternative**: Use Network tab to verify
   - Try to navigate to Clinic B patient URL directly in address bar
   - ✅ Expected: Either redirect to Clinic A or 403 error
   - ❌ Wrong: Can view Clinic B data

---

### Test Scenario 5: Two-Clinic Parallel Testing

**Goal**: Verify different employees have isolated access

#### Setup:

- **Window/Tab 1**: Logged in as Employee A (Clinic A)
- **Window/Tab 2**: Logged in as Employee B (Clinic B)

#### Steps:

1. **In Tab 1 (Employee A)**:
   - Navigate to Patients page
   - ✅ See: Only Clinic A patients
   - Check sessionStorage: `clinic_id=clinic-a-uuid`

2. **In Tab 2 (Employee B)**:
   - Navigate to Patients page
   - ✅ See: Only Clinic B patients
   - ✅ See: No overlap with Tab 1 patients
   - Check sessionStorage: `clinic_id=clinic-b-uuid`

3. **Verify isolation**:
   - Patient Name in Tab 1: "John Doe" (Clinic A)
   - Patient Name in Tab 2: "Jane Smith" (Clinic B)
   - ✅ They are different people in different clinics

---

### Test Scenario 6: Protected Route Revalidation

**Goal**: Verify server-side revalidation on protected routes

#### Steps:

1. **Login successfully** as Employee A
2. **Navigate to dashboard**: ✅ Should load
3. **Open DevTools → Network tab**
4. **Click different app sections** (Appointments, Billing, Pharmacy, etc.)
5. **Observe each route**:
   - ✅ Expected: API calls include Authorization header
   - ✅ Expected: Backend verifies clinic_id matches sessionStorage
   - ✅ Expected: Data reflects only selected clinic

---

### Test Scenario 7: Session Timeout & Logout

**Goal**: Verify secure logout and session expiry

#### Steps:

1. **Login as Employee A**
2. **In DevTools → Application → sessionStorage**, delete `auth_token`
3. **Refresh page** (Ctrl+R)
   - ✅ Expected: Redirects to login page
   - ✅ Expected: No data persists
4. **Login again** and click "Logout"
   - ✅ Expected: Session cleared
   - ✅ Expected: Redirects to login page
   - ✅ Expected: sessionStorage cleaned up

---

### Test Scenario 8: Invalid OTP Attempts

**Goal**: Verify rate limiting and failed attempt handling

#### Steps:

1. **Request OTP** for Employee A
2. **Enter incorrect OTP 3 times**:
   - ✅ Expected: Error message "Incorrect OTP. Please try again."
   - ✅ Expected: Attempts remaining counter shown (5-1=4, 5-2=3, etc.)
3. **On 5th failed attempt**:
   - ✅ Expected: Error "Too many failed attempts. Request a new OTP."
   - ✅ Expected: Cannot submit more OTP attempts
4. **Request new OTP**: Should work (rate limit resets)

---

### Validation Checklist ✅

Before moving to staging, verify all:

- [ ] **OTP Request Works**: Employee receives/can generate OTP
- [ ] **OTP Verification Returns clinic_id**: Network tab shows all 5 fields
- [ ] **Dashboard Loads**: Shows clinic-specific data
- [ ] **Clinic A Employee Cannot See Clinic B Data**: Cross-clinic attempts blocked
- [ ] **Clinic B Employee Sees Different Data**: Parallel testing confirms isolation
- [ ] **Protected Routes Revalidate**: API includes auth headers
- [ ] **Logout Clears Session**: SessionStorage cleaned, redirects to login
- [ ] **Rate Limiting Works**: 5 failed OTP attempts blocked
- [ ] **SessionStorage Management**: No sensitive data exposed

---

### Troubleshooting

| Issue | Solution |
|-------|----------|
| OTP never arrives | Check backend console for errors; ensure email configured or check dev output |
| clinic_id missing in verify response | Check [backend/server.ts](../../backend/server.ts#L410) OTP endpoint implementation |
| Can see cross-clinic data | RLS not deployed yet to staging; this is expected until migration runs |
| 401 Unauthorized errors | Check Bearer token format in Authorization header |
| Session not persisting | Check sessionStorage not disabled in browser settings |
| Wrong clinic data displayed | Verify clinic_id is correctly set in AuthContext |

---

### For Staging Deployment

After all checks pass:

1. Follow [RLS_STAGING_DEPLOYMENT_GUIDE.md](../../RLS_STAGING_DEPLOYMENT_GUIDE.md)
2. Deploy RLS migration to staging Supabase
3. Run [RLS_VALIDATION_SCRIPT.sql](../../RLS_VALIDATION_SCRIPT.sql)
4. Re-run all scenarios above against staging
5. Special focus: **Test Scenario 4** (cross-clinic blocking) should now return 403/empty

---

### Network Tab Inspection Reference

**OTP Request**:
```
POST /auth/request-otp HTTP/1.1
Content-Type: application/json

{ "userId": "user-a-1", "email": "doctor.a@clinic-a.local" }

Response 200:
{ "success": true, "sessionId": "session-xyz", "message": "OTP sent" }
```

**OTP Verify**:
```
POST /auth/verify-otp HTTP/1.1
Content-Type: application/json

{ "userId": "user-a-1", "sessionId": "session-xyz", "otp": "123456" }

Response 200:
{
  "verified": true,
  "clinicId": "clinic-a-uuid",
  "employeeId": "emp-a-1",
  "role": "doctor",
  "name": "Dr. Alice"
}
```

**Protected Route (after login)**:
```
GET /api/patients HTTP/1.1
Authorization: Bearer eyJhbGc...

Response 200:
[
  { "id": "patient-1", "name": "John Doe", "clinic_id": "clinic-a-uuid" },
  { "id": "patient-2", "name": "Jane Smith", "clinic_id": "clinic-a-uuid" }
]
```

---

**Status**: Ready for staging deployment after all checks pass ✅
