# Firestore Security Implementation

## Overview

This document outlines the Firestore security rules configured for the MediCore Healthcare System. These rules implement role-based access control and data validation to protect sensitive patient, employee, and clinic data.

## Security Model

### Default-Deny Approach
- **All access is denied by default** unless explicitly allowed by security rules
- Every collection has explicit permission rules
- No public access to any collection

### Authentication Requirement
- All data access requires Firebase Authentication
- Users must be authenticated via their clinic account
- Anonymous access is completely blocked

## Collections & Access Control

### 1. clinic_settings
**Purpose**: Store clinic configuration and settings
**Access**:
- READ: Clinic owner and authenticated clinic members
- WRITE: Clinic owner only
- CREATE: Clinic owner only
- DELETE: Denied

**Data Validation**:
- Validates name, address, phone, and admin force reset settings
- Prevents injection of unexpected fields

### 2. employees
**Purpose**: Store employee profiles and permissions
**Path**: `employees/{clinicId}/{employeeId}`
**Access**:
- READ: Employees can read own profile; clinic admins can read all
- WRITE: Clinic admins only
- CREATE: Clinic admins only with valid employee data
- UPDATE: Clinic admins only
- DELETE: Clinic owner only

**Security Features**:
- **Password protection**: Prevents password field from being stored in Firestore (passwords handled server-side only)
- **Role-based access**: Validates employee roles and permissions
- **Admin escalation prevention**: Only clinic owners/admins can modify employee records

### 3. patients
**Purpose**: Store patient records and medical information
**Path**: `patients/{clinicId}/{patientId}`
**Access**:
- READ: Authenticated clinic staff only
- WRITE: Authorized clinic staff only
- CREATE: Authorized clinic staff only
- UPDATE: Authorized clinic staff only
- DELETE: Clinic admins only

**Data Protection**:
- Validates name, age, gender, contact, and medical history
- Blocks sensitive fields like SSN
- Clinic-level data isolation

### 4. appointments
**Purpose**: Store appointment records
**Path**: `appointments/{clinicId}/{appointmentId}`
**Access**:
- READ: Clinic staff only
- WRITE: Authorized clinic staff only
- CREATE: Authorized clinic staff only
- UPDATE: Authorized clinic staff only
- DELETE: Clinic admins only

**Validation**:
- Requires patient_id, doctor_id, appointment_date
- Validates status values (scheduled, completed, cancelled, no-show)
- Allows notes field for additional information

### 5. audit_logs
**Purpose**: Compliance logging and audit trail
**Path**: `audit_logs/{clinicId}/{logId}`
**Access**:
- READ: Clinic staff can access
- WRITE: **Disabled - Cloud Functions only**
- DELETE: Disabled

**Security**: 
- Read-only for staff
- Written exclusively via server-side Cloud Functions (prevents tampering)
- Compliance with healthcare regulations

## Deployment Instructions

### Prerequisites
- Firebase CLI installed (`npm install -g firebase-tools`)
- Access to Firebase project
- Proper authentication (`firebase login`)

### Deploy Security Rules

```bash
# Deploy firestore rules only
firebase deploy --only firestore:rules

# Deploy rules and indexes
firebase deploy --only firestore

# Deploy everything
firebase deploy
```

### Verify Deployment

1. Go to Firebase Console > Firestore Database > Rules
2. Verify the latest version date matches deployment time
3. Check Rules Playground to test access scenarios

## Testing Security Rules

Use Firebase's Rules Playground to test various scenarios:

```
// Test 1: Anonymous user cannot read clinic_settings
Path: clinic_settings/clinic123
Auth: None
Result: Should DENY

// Test 2: Authenticated user can read own clinic settings
Path: clinic_settings/uid123
Auth: uid123
Custom Claims: { clinic_owner_id: 'uid123' }
Result: Should ALLOW

// Test 3: Unauthorized user cannot read other clinic data
Path: clinic_settings/other_clinic123
Auth: uid456
Custom Claims: { clinic_owner_id: 'uid456' }
Result: Should DENY
```

## Best Practices

1. **Always authenticate before data access**
   - Implement proper auth guards in React components
   - Check user authentication status before making Firestore queries

2. **Set custom claims for clinic ownership**
   ```javascript
   admin.auth().setCustomUserClaims(uid, {
     clinic_owner_id: clinicId,
     role: 'owner'
   });
   ```

3. **Validate data before Firestore writes**
   - Both client-side (UX) and server-side validation
   - Firestore rules provide secondary validation layer

4. **Monitor access patterns**
   - Enable Firestore audit logging in Google Cloud Console
   - Review access logs regularly for suspicious activity

5. **Keep sensitive data server-side only**
   - Passwords and API keys: server-side only
   - Never expose sensitive data in Firestore read operations

6. **Implement Cloud Functions for sensitive operations**
   - Complicated business logic
   - Data transformations
   - Audit logging
   - Admin-only operations

## Compliance Considerations

- **HIPAA**: Patient data is clinic-isolated and accessed only by authorized staff
- **GDPR**: User can only access own data unless admin
- **SOC 2**: Comprehensive access control and audit logging implemented

## Important Security Notes

### Password Fields
The rules explicitly block any document containing a 'password' field from being written. All passwords must be handled through Firebase Authentication or server-side Cloud Functions with bcrypt hashing.

### XSS Protection
Combined with sessionStorage (see client.ts fixes), these rules prevent XSS attacks by:
1. Blocking access to session tokens via JavaScript injection
2. Requiring authentication for all data access
3. Validating all data writes

### SQL/NoSQL Injection Prevention
- Firestore doesn't support traditional SQL/NoSQL injection
- Field-level validation prevents malformed data
- Rules-based access control prevents unauthorized queries

## Troubleshooting

### "Permission denied" errors in console
1. Check user authentication status
2. Verify custom claims are set correctly
3. Check clinic_id matches authenticated clinic
4. Review security rules in Firebase Console

### Rules deployment fails
1. Check syntax using `firebase deploy --only firestore:rules --dry-run`
2. Ensure firestore.rules file is valid
3. Check Firebase CLI version is up to date

### Indexes missing
If queries fail with "index needed" error:
1. Create indexes using Firebase Console or
2. Deploy with `firebase deploy --only firestore`
3. Wait for index creation (typically 5-10 minutes)

## References
- [Firebase Security Rules Documentation](https://firebase.google.com/docs/firestore/security/start)
- [Firestore Best Practices](https://firebase.google.com/docs/firestore/best-practices)
- [HIPAA on Google Cloud](https://cloud.google.com/security/compliance/hipaa)
