## Pre-Staging Validation Checklist

Run through this quick checklist before deploying to staging Supabase.

---

## Automated Tests ✅

**Command**: `npm run test src/test/e2e-auth-flow.test.ts`

- [ ] **Test Suite 1**: OTP Request Flow (3/3 tests pass)
- [ ] **Test Suite 2**: OTP Verification Flow (6/6 tests pass) ← CRITICAL
  - Verify clinic_id is returned in response
- [ ] **Test Suite 3**: Clinic Isolation & RLS (4/4 tests pass)
  - Verify cross-clinic attempts blocked
- [ ] **Test Suite 4**: Full Auth Flow Integration (2/2 tests pass)
- [ ] **Test Suite 5**: Security Edge Cases (2/2 tests pass)

**Expected**: All 17 tests pass ✅

---

## Manual App Testing (Local)

Follow [MANUAL_E2E_TESTING_GUIDE.md](./MANUAL_E2E_TESTING_GUIDE.md)

### Quick Path (30 minutes):

1. **Test Scenario 1**: OTP Request & Verification
   - [ ] OTP generated successfully
   - [ ] Verification succeeds

2. **Test Scenario 2**: clinic_id Return (**CRITICAL**)
   - [ ] Network tab shows `clinicId` in response
   - [ ] All 5 fields present: verified, clinicId, employeeId, role, name

3. **Test Scenario 3**: Dashboard Access
   - [ ] Dashboard loads with clinic data
   - [ ] Sidebar shows correct clinic name

4. **Test Scenario 5**: Parallel Login (Two Clinics)
   - [ ] Employee A sees only Clinic A data
   - [ ] Employee B sees only Clinic B data in different tab

5. **Test Scenario 6**: Protected Routes
   - [ ] API calls include Authorization header
   - [ ] Data returns only for user's clinic

---

## Backend Code Review

Verify backend is production-ready:

- [ ] [backend/server.ts](../../backend/server.ts)
  - [ ] OTP request endpoint (line ~310)
  - [ ] OTP verify endpoint returns clinic_id (line ~343-430)
  - [ ] Clinic_id fetch from clinic_employees table (line ~410)
  - [ ] Rate limiting on OTP endpoints (line ~300)
  - [ ] Error handling secure (no sensitive leaks)

- [ ] Rate Limiting
  - [ ] OTP request limited to 5/min per user
  - [ ] OTP verify limited to 5/min per user
  - [ ] Login attempts rate limited

---

## Build & lint

- [ ] `npm run build` exits with code 0 (no errors)
- [ ] `npm run lint` passes (or only warnings)
- [ ] No TypeScript errors on backend/server.ts

**Commands**:
```bash
npm run build
npm run lint
```

---

## Security Checks (Local)

Use browser DevTools (F12):

1. **Check sessionStorage** (not localStorage):
   - [ ] No auth token in localStorage (security issue)
   - [ ] `auth_clinic_id` present in sessionStorage after login
   - [ ] `auth_token` present in sessionStorage after login

2. **Check Network tab** for sensitive leaks:
   - [ ] OTP never exposed in URLs (only POST body)
   - [ ] clinic_id not exposed before OTP validation
   - [ ] Authorization header properly formatted "Bearer {token}"

3. **Check Console** for errors:
   - [ ] No 401/403 errors (unless testing cross-clinic)
   - [ ] No CORS warnings for same-origin calls
   - [ ] No sensitiveSensitive data logged

---

## Email/Messaging Setup (Optional for Dev)

If testing with real OTP delivery:

- [ ] Email service configured (Firebase, SendGrid, etc.)
- [ ] OTP emails arriving in inbox
- [ ] Email contains only OTP code (no clinic info)

If using console/log OTP (dev mode):
- [ ] Backend console shows generated OTP
- [ ] Check that OTP is marked as verified after use

---

## Permission & Data Setup

For realistic testing (optional):

- [ ] Two employees created in different clinics
  - Employee A: clinic_a_uuid
  - Employee B: clinic_b_uuid
- [ ] Each employee can request OTP
- [ ] Test data for each clinic (patients, appointments, billing)
- [ ] Each clinic's data is clearly different (for visual verification)

---

## Staging Supabase Preparation

Before deployment:

- [ ] Staging Supabase project created
  - [ ] New project (not production)
- [ ] Database schema matches production
  - [ ] Tables: clinic_employees, patients, appointments, billing_invoices, etc.
- [ ] Sample data loaded (or will be added during validation)
- [ ] SQL Editor accessible
- [ ] Backup created (if data exists)

---

## Go/No-Go Decision

### ✅ GO TO STAGING IF:
- All 17 automated tests pass
- All 5 manual test scenarios pass
- Build succeeds with no errors
- clinic_id returned in OTP verification response
- Cross-clinic access properly restricted (will be enforced by RLS once deployed)
- Backend error rates low (check logs)
- No security issues found in manual review
- Staging Supabase environment ready

### 🛑 DO NOT GO TO STAGING IF:
- Any test fails
- clinic_id not returned in OTP response
- Build errors or lint failures
- Security issues found (sensitive data exposed)
- Backend crashes or errors in logs
- Staging environment not ready

---

## Next Steps (After Go/No-Go Approved)

If ✅ **GO**:
1. Follow [RLS_STAGING_DEPLOYMENT_GUIDE.md](../../RLS_STAGING_DEPLOYMENT_GUIDE.md)
2. Deploy RLS migration to staging
3. Run [RLS_VALIDATION_SCRIPT.sql](../../RLS_VALIDATION_SCRIPT.sql)
4. Re-test scenarios 4 & 5 (cross-clinic should be blocked by RLS now)
5. Monitor staging for 24 hours
6. Schedule professional security audit

If 🛑 **NO-GO**:
1. Debug specific failures
2. Review error logs
3. Fix identified issues
4. Re-run checklist
5. Try again

---

## Estimated Duration

- **Automated tests**: 5 minutes
- **Manual local testing**: 30-45 minutes
- **Build & lint verification**: 10 minutes
- **Security review**: 15 minutes

**Total Pre-Staging Validation**: ~1 hour

---

**Last Updated**: April 3, 2026  
**Status**: Ready for pre-staging validation ✅
