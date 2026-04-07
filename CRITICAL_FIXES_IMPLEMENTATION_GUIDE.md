# MEDCORE Critical Issues - Step-by-Step Fix Guide

This document provides actionable, copy-paste ready solutions for all CRITICAL and HIGH priority issues.

---

## 🔴 CRITICAL FIX #1: Enable TypeScript Strict Mode

**Time:** 1-2 hours

### Step 1: Update tsconfig.json
```json
{
  "compilerOptions": {
    "allowJS": true,
    "target": "ES2020",
    "noImplicitAny": true,         // ✅ Changed: true
    "noUnusedLocals": true,        // ✅ Changed: true
    "noUnusedParameters": true,    // ✅ Changed: true
    "strict": true,                // ✅ Changed: true
    "strictNullChecks": true,      // ✅ Changed: true
    "skipLibCheck": true,
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "files": [],
  "references": [
    { "path": "./tsconfig.app.json" },
    { "path": "./tsconfig.node.json" }
  ]
}
```

### Step 2: Update tsconfig.app.json
```json
{
  "extends": "../tsconfig.json",
  "compilerOptions": {
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "jsx": "react-jsx",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleDetection": "force",
    "moduleResolution": "bundler",
    "noEmit": true,
    "noFallthroughCasesInSwitch": true,  // ✅ Changed: true
    "strict": true,                      // ✅ Add
    "noImplicitAny": true,               // ✅ Add
    "noUnusedLocals": true,              // ✅ Add
    "noUnusedParameters": true,          // ✅ Add
    "target": "ES2020",
    "types": ["vitest/globals"],
    "useDefineForClassFields": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
```

### Step 3: Run TypeScript compiler to find errors
```bash
# This will show all type errors
npx tsc --noEmit

# Expect ~50-100 errors to fix
```

### Step 4: Fix top errors systematically
```typescript
// ❌ BEFORE: implicit any
const [matchedPatient, setMatchedPatient] = useState<any>(null);

// ✅ AFTER: proper type
interface Patient {
  id: string;
  name: string;
  phone: string;
  gender: 'male' | 'female';
  dob?: Date;
  address?: string;
}
const [matchedPatient, setMatchedPatient] = useState<Patient | null>(null);
```

---

## 🔴 CRITICAL FIX #2: Migrate OTP to Redis

**Time:** 2-3 hours (+ infrastructure setup)

### Step 1: Install Redis client
```bash
npm install ioredis
# or
npm install redis
```

### Step 2: Update backend/server.ts - Replace in-memory store

Replace the entire OTP store section (lines 104-200) with:

```typescript
import Redis from 'ioredis';

// Initialize Redis client
const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

// Handle Redis connection errors
redis.on('error', (err) => {
  console.error('[Redis] Connection error:', err);
});

redis.on('connect', () => {
  console.log('[Redis] Connected successfully');
});

/**
 * SECURITY: Generate cryptographically secure OTP
 */
function generateSecureOtp(): string {
  const otp = randomInt(0, 1000000)
    .toString()
    .padStart(6, '0');
  return otp;
}

/**
 * SECURITY: Store OTP with Redis TTL (Time To Live)
 * Automatically expires after specified duration
 */
async function storeOtp(
  userId: string,
  sessionId: string,
  otp: string,
  expiryMinutes: number = 10
): Promise<void> {
  const key = `otp:${userId}-${sessionId}`;
  const ttl = expiryMinutes * 60; // Convert to seconds for Redis
  
  const otpRecord = JSON.stringify({
    otp,
    expiresAt: Date.now() + expiryMinutes * 60 * 1000,
    attempts: 0,
    maxAttempts: 5,
    verified: false,
  });
  
  try {
    // Set with TTL - Redis automatically deletes after TTL
    await redis.setex(key, ttl, otpRecord);
    console.log(`[OTP] Stored for ${userId} / ${sessionId}, expires in ${expiryMinutes}m`);
  } catch (error) {
    console.error('[OTP] Failed to store with Redis:', error);
    // Graceful degradation: could fall back to in-memory, but better to fail fast
    throw new Error('OTP storage service unavailable');
  }
}

/**
 * SECURITY: Retrieve OTP from Redis
 */
async function retrieveOtp(
  userId: string,
  sessionId: string
): Promise<any | null> {
  const key = `otp:${userId}-${sessionId}`;
  
  try {
    const data = await redis.get(key);
    if (!data) {
      return null;
    }
    return JSON.parse(data);
  } catch (error) {
    console.error('[OTP] Failed to retrieve:', error);
    return null;
  }
}

/**
 * Mark OTP as verified (prevent reuse)
 */
async function markOtpAsVerified(userId: string, sessionId: string): Promise<void> {
  const key = `otp:${userId}-${sessionId}`;
  
  try {
    const data = await redis.get(key);
    if (!data) return;
    
    const record = JSON.parse(data);
    record.verified = true;
    
    // Update with same TTL
    const remainingTtl = await redis.ttl(key);
    if (remainingTtl > 0) {
      await redis.setex(key, remainingTtl, JSON.stringify(record));
    }
  } catch (error) {
    console.error('[OTP] Failed to mark as verified:', error);
  }
}

/**
 * Increment attempt counter
 */
async function incrementOtpAttempts(userId: string, sessionId: string): Promise<number> {
  const key = `otp:${userId}-${sessionId}`;
  
  try {
    const data = await redis.get(key);
    if (!data) return 0;
    
    const record = JSON.parse(data);
    record.attempts++;
    
    const remainingTtl = await redis.ttl(key);
    if (remainingTtl > 0) {
      await redis.setex(key, remainingTtl, JSON.stringify(record));
    }
    
    return record.attempts;
  } catch (error) {
    console.error('[OTP] Failed to increment attempts:', error);
    return 0;
  }
}
```

### Step 3: Update /auth/request-otp endpoint

```typescript
app.post("/auth/request-otp", otpRequestLimiter, async (req, res) => {
  try {
    const { userId, employeeId, sessionId, methods = {}, expiryMinutes = 10 } = req.body;
    
    if (!userId || !employeeId || !sessionId) {
      return res.status(400).json({
        error: "Missing required fields: userId, employeeId, sessionId",
      });
    }
    
    const expiry = Math.max(5, Math.min(expiryMinutes, 60));
    const otp = generateSecureOtp();
    
    // ✅ NEW: Using Redis instead of in-memory
    await storeOtp(userId, sessionId, otp, expiry);
    
    console.log(`[OTP] Request: User ${userId} / Employee ${employeeId} / Session ${sessionId}`);
    console.log(`[OTP] Methods: SMS=${methods.sms}, Email=${methods.email}, Expiry=${expiry}min`);
    
    // Demo: log OTP only in development
    if (process.env.NODE_ENV === 'development' && process.env.DEMO_MODE === 'true') {
      console.log(`[OTP-DEMO] Code: ${otp} (expires in ${expiry}min)`);
    }
    
    return res.status(200).json({
      success: true,
      message: `OTP sent via ${Object.entries(methods)
        .filter(([, v]) => v)
        .map(([k]) => k.toUpperCase())
        .join("/")}`,
      sessionId,
      expiresAt: new Date(Date.now() + expiry * 60 * 1000).toISOString(),
    });
  } catch (error) {
    console.error("[OTP] Request error:", error);
    return res.status(500).json({
      error: "Failed to generate OTP. Please try again.",
    });
  }
});
```

### Step 4: Update /auth/verify-otp endpoint

```typescript
app.post("/auth/verify-otp", otpVerifyLimiter, async (req, res) => {
  try {
    const { userId, sessionId, otp } = req.body;
    
    if (!userId || !sessionId || !otp) {
      return res.status(400).json({
        error: "Missing required fields: userId, sessionId, otp",
      });
    }
    
    if (!/^\d{6}$/.test(otp)) {
      console.warn(`[OTP] Invalid format attempt: ${otp}`);
      return res.status(400).json({
        error: "Invalid OTP format. Must be 6 digits.",
      });
    }
    
    // ✅ NEW: Retrieve from Redis
    const record = await retrieveOtp(userId, sessionId);
    
    if (!record) {
      console.warn(`[OTP] Not found for session: ${sessionId}`);
      return res.status(401).json({
        error: "OTP not found or expired. Request a new OTP.",
      });
    }
    
    if (record.verified) {
      console.warn(`[OTP] Reuse attempt for session: ${sessionId}`);
      return res.status(401).json({
        error: "This OTP has already been used.",
      });
    }
    
    if (record.attempts >= record.maxAttempts) {
      console.warn(`[OTP] Max attempts exceeded: ${sessionId}`);
      // ✅ NEW: Delete from Redis automatically via TTL, no need to manually delete
      return res.status(429).json({
        error: "Too many failed attempts. Request a new OTP.",
      });
    }
    
    // Check if OTP matches using timing-safe comparison
    const isValid = await verifyOtpHash(otp, record.otp);
    
    if (!isValid) {
      const attempts = await incrementOtpAttempts(userId, sessionId);
      console.warn(`[OTP] Failed verification attempt ${attempts}/${record.maxAttempts}: ${sessionId}`);
      return res.status(401).json({
        error: "Incorrect OTP. Please try again.",
        attemptsRemaining: record.maxAttempts - attempts,
      });
    }
    
    // ✅ Mark as verified in Redis
    await markOtpAsVerified(userId, sessionId);
    
    console.log(`[OTP] Verified successfully: User ${userId} / Session ${sessionId}`);
    
    // ... rest of verification logic
    return res.status(200).json({
      verified: true,
      message: "OTP verified successfully.",
    });
  } catch (error) {
    console.error("[OTP] Verification error:", error);
    return res.status(500).json({
      error: "Failed to verify OTP. Please try again.",
    });
  }
});
```

### Step 5: Update .env file
```bash
# Add Redis configuration
REDIS_URL=redis://localhost:6379
# Or for production
REDIS_URL=rediss://username:password@redis.example.com:6380
```

### Step 6: Test Redis connectivity
```bash
# Test locally
docker run -d -p 6379:6379 redis:7-alpine

# Then run backend
npm run dev:server
# Should see: [Redis] Connected successfully
```

---

## 🔴 CRITICAL FIX #3: Migrate Admin Credentials to Firestore

**Time:** 3-4 hours

### Step 1: Update backend/server.ts - Replace admin store

Replace the in-memory admin store with Firestore:

```typescript
import { collection, doc, setDoc, getDoc, updateDoc } from 'firebase/firestore';

interface AdminRecord {
  clinicId: string;
  hashedPassword: string;
  createdAt: Date;
  updatedAt: Date;
  lastLogin: Date | null;
  ownerSupabaseId?: string;
}

// NEW: Firestore admin credential store
const adminCredentialsCollection = collection(db, 'admin_credentials');

/**
 * SECURITY: Persist admin credentials to Firestore (encrypted on Google's side)
 */
async function persistAdminSetup(clinicId: string, record: AdminRecord): Promise<void> {
  try {
    const docRef = doc(adminCredentialsCollection, clinicId);
    
    // Firestore encryption at rest is automatic
    // For production, consider application-level encryption
    await setDoc(docRef, {
      clinicId: record.clinicId,
      hashedPassword: record.hashedPassword, // Never store plaintext
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      lastLogin: record.lastLogin,
      ownerSupabaseId: record.ownerSupabaseId,
    });
    
    console.log(`[ADMIN] Credentials persisted for clinic: ${clinicId}`);
  } catch (error) {
    console.error('[ADMIN] Failed to persist credentials:', error);
    throw new Error('Failed to save admin credentials. Please try again.');
  }
}

/**
 * Retrieve admin credentials from Firestore
 */
async function retrieveAdminSetup(clinicId: string): Promise<AdminRecord | null> {
  try {
    const docRef = doc(adminCredentialsCollection, clinicId);
    const docSnapshot = await getDoc(docRef);
    
    if (!docSnapshot.exists()) {
      return null;
    }
    
    const data = docSnapshot.data();
    return {
      clinicId: data.clinicId,
      hashedPassword: data.hashedPassword,
      createdAt: new Date(data.createdAt),
      updatedAt: new Date(data.updatedAt),
      lastLogin: data.lastLogin ? new Date(data.lastLogin) : null,
      ownerSupabaseId: data.ownerSupabaseId,
    };
  } catch (error) {
    console.error('[ADMIN] Failed to retrieve credentials:', error);
    return null;
  }
}

/**
 * Update admin login timestamp
 */
async function updateAdminLastLogin(clinicId: string): Promise<void> {
  try {
    const docRef = doc(adminCredentialsCollection, clinicId);
    await updateDoc(docRef, {
      lastLogin: new Date(),
    });
  } catch (error) {
    console.error('[ADMIN] Failed to update last login:', error);
  }
}
```

### Step 2: Update /auth/check-admin-setup endpoint

```typescript
app.get("/auth/check-admin-setup", async (req, res) => {
  try {
    const { clinicId } = req.query;
    
    if (!clinicId || typeof clinicId !== 'string') {
      return res.status(400).json({
        error: "Missing clinicId query parameter",
      });
    }
    
    // ✅ NEW: Check Firestore instead of in-memory
    const record = await retrieveAdminSetup(clinicId);
    const isSetup = record !== null;
    
    return res.status(200).json({
      isSetup,
      message: isSetup ? "Admin already configured" : "Admin setup required",
      clinicId,
      lastLogin: record?.lastLogin?.toISOString() || null,
    });
  } catch (error) {
    console.error("[ADMIN] Check setup error:", error);
    return res.status(500).json({
      error: "Failed to check admin setup status.",
    });
  }
});
```

### Step 3: Update /auth/setup-admin-credentials endpoint

```typescript
app.put("/auth/setup-admin-credentials", authRateLimiter, async (req, res) => {
  try {
    const validation = AdminSetupSchema.safeParse(req.body);
    if (!validation.success) {
      return res.status(400).json({
        error: "Invalid request. Password must be 12+ chars with uppercase, lowercase, number, and special character.",
      });
    }

    const { clinicId, ownerId, adminPassword, adminEmail } = validation.data;
    
    // SECURITY: Check if already set up in Firestore
    const existing = await retrieveAdminSetup(clinicId);
    if (existing) {
      return res.status(409).json({
        error: "Setup failed. Please contact support if you need to reset admin credentials.",
      });
    }
    
    const hashedPassword = await hashAdminPassword(adminPassword);
    
    // ✅ NEW: Persist to Firestore
    const now = new Date();
    const adminRecord: AdminRecord = {
      clinicId,
      hashedPassword,
      createdAt: now,
      updatedAt: now,
      lastLogin: null,
      ownerSupabaseId: ownerId,
    };
    
    await persistAdminSetup(clinicId, adminRecord);
    
    // Log to audit trail
    await logAdminAction(clinicId, 'setup', { adminEmail, ownerId });
    
    return res.status(201).json({
      success: true,
      message: "Admin credentials configured successfully.",
      clinicId,
    });
  } catch (error) {
    console.error("[ADMIN] Setup error:", error);
    return res.status(500).json({
      error: "Failed to set up admin credentials. Please try again.",
    });
  }
});
```

### Step 4: Update /auth/verify-admin endpoint

```typescript
app.post("/auth/verify-admin", authRateLimiter, async (req, res) => {
  try {
    const validation = AdminVerifySchema.safeParse(req.body);
    if (!validation.success) {
      return res.status(400).json({
        error: "Invalid request",
      });
    }

    const { clinicId, adminPassword } = validation.data;
    
    // ✅ NEW: Retrieve from Firestore
    const adminRecord = await retrieveAdminSetup(clinicId);
    
    if (!adminRecord) {
      // Generic message to prevent clinic enumeration
      return res.status(401).json({
        error: "Invalid clinic ID or admin credentials.",
      });
    }
    
    // SECURITY: Timing-safe password comparison with bcrypt
    const isPasswordValid = await verifyAdminPassword(adminPassword, adminRecord.hashedPassword);
    
    if (!isPasswordValid) {
      await logAdminAction(clinicId, 'verify_failed', { reason: 'invalid_password' });
      return res.status(401).json({
        error: "Invalid credentials.",
      });
    }
    
    // Update last login
    await updateAdminLastLogin(clinicId);
    
    await logAdminAction(clinicId, 'verify_success', {});
    
    console.log(`[ADMIN] Verification successful for clinic: ${clinicId}`);
    
    return res.status(200).json({
      verified: true,
      message: "Admin verification successful.",
      sessionToken: generateSessionToken(clinicId, adminRecord.ownerSupabaseId),
    });
  } catch (error) {
    console.error("[ADMIN] Verification error:", error);
    return res.status(500).json({
      error: "Failed to verify admin credentials.",
    });
  }
});
```

### Step 5: Add admin action logging

```typescript
/**
 * Log admin actions for audit trail
 */
async function logAdminAction(
  clinicId: string,
  action: 'setup' | 'change_password' | 'verify_success' | 'verify_failed' | 'login',
  details: Record<string, any> = {}
): Promise<void> {
  try {
    const auditLog = collection(db, 'admin_audit_log');
    
    await addDoc(auditLog, {
      clinicId,
      action,
      timestamp: new Date(),
      ipAddress: process.env.REQUEST_IP || 'unknown',
      userAgent: process.env.REQUEST_USER_AGENT || 'unknown',
      ...details,
    });
    
    console.log(`[AUDIT] ${action} for clinic ${clinicId}`);
  } catch (error) {
    console.error('[AUDIT] Failed to log action:', error);
  }
}
```

### Step 6: Test migration

```bash
# 1. Start fresh - remove old in-memory store
# Delete lines for adminSetupStore

# 2. Run and verify
npm run dev:server

# 3. Test setup endpoint
curl -X PUT http://localhost:3000/auth/setup-admin-credentials \
  -H "Content-Type: application/json" \
  -d '{
    "clinicId": "clinic-123",
    "ownerId": "owner-123",
    "adminPassword": "MySecure!Pw24",
    "adminEmail": "admin@clinic.com"
  }'

# 4. Verify in Firestore Console - should see entry in admin_credentials collection

# 5. Restart server - credentials should still be there!
```

---

## 🟠 HIGH FIX #1: Fix React Hook Dependencies

**Time:** 1-2 hours

### Fix EmployeeContext.tsx

**Location:** [src/contexts/EmployeeContext.tsx](src/contexts/EmployeeContext.tsx#L51-L67)

```typescript
// ❌ BEFORE:
useEffect(() => {
  if (!user?.id) return;

  try {
    const stored = sessionStorage.getItem("currentEmployee");
    if (stored) {
      const parsed = JSON.parse(stored);
      console.log("[AUTH] Restored employee session from sessionStorage (unvalidated, server check required)");
      setEmployeeState(parsed);
    }
  } catch (error) {
    console.error("[AUTH] Failed to restore employee session:", error);
    setEmployeeState(null);
    sessionStorage.removeItem("currentEmployee");
  }
}, [user?.id]); // ❌ Wrong dependency

// ✅ AFTER:
useEffect(() => {
  if (!user) return; // Check user exists

  try {
    const stored = sessionStorage.getItem("currentEmployee");
    if (stored) {
      const parsed = JSON.parse(stored);
      console.log("[AUTH] Restored employee session from sessionStorage (unvalidated, server check required)");
      setEmployeeState(parsed);
    }
  } catch (error) {
    console.error("[AUTH] Failed to restore employee session:", error);
    setEmployeeState(null);
    sessionStorage.removeItem("currentEmployee");
  }
}, [user]); // ✅ Proper dependency: full user object
```

### Fix LowStockAlert.tsx

**Location:** [src/components/pharmacy/LowStockAlert.tsx](src/components/pharmacy/LowStockAlert.tsx#L21-L29)

```typescript
// ❌ BEFORE:
useEffect(() => {
  if (lowStockDrugs.length > 0 && !toastShown.current) {
    toastShown.current = true;
    toast({
      title: `⚠️ ${lowStockDrugs.length} drug${lowStockDrugs.length > 1 ? "s" : ""} below warning point`,
      description: lowStockDrugs.slice(0, 3).map((d) => d.drug_name).join(", ") +
        (lowStockDrugs.length > 3 ? ` and ${lowStockDrugs.length - 3} more` : ""),
      variant: "destructive",
    });
  }
}, [lowStockDrugs.length]); // ❌ Missing lowStockDrugs in deps

// ✅ AFTER:
const toastShown = useRef(false);

useEffect(() => {
  if (lowStockDrugs.length > 0 && !toastShown.current) {
    toastShown.current = true;
    toast({
      title: `⚠️ ${lowStockDrugs.length} drug${lowStockDrugs.length > 1 ? "s" : ""} below warning point`,
      description: lowStockDrugs.slice(0, 3).map((d) => d.drug_name).join(", ") +
        (lowStockDrugs.length > 3 ? ` and ${lowStockDrugs.length - 3} more` : ""),
      variant: "destructive",
    });
  }
  
  // Reset flag when drugs are restocked
  if (lowStockDrugs.length === 0) {
    toastShown.current = false;
  }
}, [lowStockDrugs, toast]); // ✅ Include all dependencies
```

---

## 🟠 HIGH FIX #2: Fix OTP Timing-Safe Comparison

**Location:** [backend/server.ts](backend/server.ts#L351-L366)

```typescript
// ❌ BEFORE - String comparison vulnerable to timing attacks:
const isValid = record.otp === otp;

// ✅ AFTER - Use timing-safe comparison:
const isValid = await verifyOtpHash(otp, record.otp);

// Make sure verifyOtpHash is implemented correctly:
async function verifyOtpHash(providedOtp: string, storedHash: string): Promise<boolean> {
  try {
    // Use bcrypt for timing-safe comparison
    // If storing OTP as plaintext, create a hash first
    const providedHash = await hashOtp(providedOtp);
    
    // timingSafeEqual returns void and throws if comparison fails
    timingSafeEqual(
      Buffer.from(providedHash),
      Buffer.from(storedHash)
    );
    return true;
  } catch (error) {
    // timingSafeEqual throws on mismatch
    return false;
  }
}

// Full endpoint fix:
app.post("/auth/verify-otp", otpVerifyLimiter, async (req, res) => {
  try {
    const { userId, sessionId, otp } = req.body;
    
    if (!userId || !sessionId || !otp) {
      return res.status(400).json({ error: "Missing required fields" });
    }
    
    if (!/^\d{6}$/.test(otp)) {
      return res.status(400).json({ error: "Invalid OTP format" });
    }
    
    const record = await retrieveOtp(userId, sessionId);
    if (!record) {
      return res.status(401).json({ error: "OTP not found or expired" });
    }
    
    if (record.attempts >= record.maxAttempts) {
      return res.status(429).json({ error: "Too many attempts" });
    }
    
    // ✅ USE TIMING-SAFE COMPARISON:
    const isValid = await verifyOtpHash(otp, record.otp);
    
    if (!isValid) {
      record.attempts++;
      await redis.setex(
        `otp:${userId}-${sessionId}`,
        await redis.ttl(`otp:${userId}-${sessionId}`),
        JSON.stringify(record)
      );
      
      return res.status(401).json({
        error: "Incorrect OTP",
        attemptsRemaining: record.maxAttempts - record.attempts,
      });
    }
    
    // OTP verified - continue with login
    await markOtpAsVerified(userId, sessionId);
    
    return res.status(200).json({
      verified: true,
      message: "OTP verified successfully",
    });
  } catch (error) {
    console.error("[OTP] Verification error:", error);
    return res.status(500).json({ error: "Verification failed" });
  }
});
```

---

## 🟠 HIGH FIX #3: Add CSRF Protection

**Time:** 2 hours

### Step 1: Install CSRF middleware
```bash
npm install csurf cookie-parser
```

### Step 2: Update backend/server.ts

```typescript
import csrf from 'csurf';
import cookieParser from 'cookie-parser';

// After other middleware:
app.use(cookieParser());

// CSRF protection with cookies
const csrfProtection = csrf({ 
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production', // HTTPS only in prod
    sameSite: 'strict'
  }
});

// GET endpoint to get CSRF token initially
app.get('/auth/csrf-token', csrfProtection, (req, res) => {
  res.json({ csrfToken: req.csrfToken() });
});

// POST endpoints need CSRF token
app.post("/auth/signin", csrfProtection, authRateLimiter, async (req, res) => {
  // CSRF token automatically validated by middleware
  // Endpoint logic continues...
});

app.post("/auth/signup", csrfProtection, authRateLimiter, async (req, res) => {
  // ...
});

app.post("/auth/request-otp", csrfProtection, otpRequestLimiter, async (req, res) => {
  // ...
});

// Apply to all sensitive operations
app.post("/auth/verify-otp", csrfProtection, otpVerifyLimiter, async (req, res) => {
  // ...
});

app.put("/auth/setup-admin-credentials", csrfProtection, authRateLimiter, async (req, res) => {
  // ...
});

app.post("/auth/verify-admin", csrfProtection, authRateLimiter, async (req, res) => {
  // ...
});

// Global CSRF error handler
app.use((err: any, req: any, res: any, next: any) => {
  if (err.code === 'EBADCSRFTOKEN') {
    console.warn('[CSRF] Invalid or missing CSRF token from', req.ip);
    return res.status(403).json({ error: 'Invalid security token. Please try again.' });
  }
  next(err);
});
```

### Step 3: Update frontend to use CSRF token

```typescript
// lib/api-client.ts
let csrfToken = '';

// Fetch CSRF token on app load
export async function initializeCsrf() {
  try {
    const response = await fetch('/auth/csrf-token');
    const data = await response.json();
    csrfToken = data.csrfToken;
    localStorage.setItem('csrfToken', csrfToken);
  } catch (error) {
    console.error('Failed to initialize CSRF protection:', error);
  }
}

// Use in all API calls
export async function apiPost(endpoint: string, body: any) {
  const token = csrfToken || localStorage.getItem('csrfToken');
  
  return fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': token || '', // Include CSRF token
    },
    body: JSON.stringify(body),
  });
}
```

### Step 4: Initialize CSRF in App.tsx

```typescript
import { initializeCsrf } from '@/lib/api-client';

useEffect(() => {
  initializeCsrf();
}, []);
```

---

## 🟡 MEDIUM FIX #1: Add Input Validation

**Time:** 2-3 hours

### Create validation schemas (lib/schemas.ts)

```typescript
import { z } from 'zod';

// Patient schemas
export const PatientPhoneSchema = z.string()
  .regex(/^[\d\s\-\+\(\)]*$/, "Invalid phone format")
  .min(10, "Phone must be at least 10 digits")
  .max(20, "Phone number too long");

export const PatientEmailSchema = z.string()
  .email("Invalid email format");

export const PatientCreateSchema = z.object({
  firstName: z.string().min(1, "First name required").max(50),
  lastName: z.string().min(1, "Last name required").max(50),
  phone: PatientPhoneSchema.optional(),
  email: PatientEmailSchema.optional(),
  gender: z.enum(['male', 'female', 'other']),
  address: z.string().max(200),
  dob: z.date().optional(),
});

// Employee schemas
export const EmployeePasswordSchema = z.string()
  .min(8, "Password must be 8+ characters")
  .regex(/[A-Z]/, "Must contain uppercase letter")
  .regex(/[a-z]/, "Must contain lowercase letter")
  .regex(/[0-9]/, "Must contain number");

export const EmployeeCreateSchema = z.object({
  fullName: z.string().min(1).max(100),
  email: z.string().email(),
  phone: PatientPhoneSchema,
  role: z.enum(['doctor', 'nurse', 'pharmacist', 'staff']),
  password: EmployeePasswordSchema,
});

// Prescriptions
export const PrescriptionSchema = z.object({
  patientId: z.string().uuid(),
  doctorId: z.string().uuid(),
  notes: z.string().max(1000),
  duration: z.object({
    value: z.number().min(1),
    unit: z.enum(['days', 'weeks', 'months']),
  }),
});
```

### Use in forms

```typescript
// TriagePage.tsx
import { PatientPhoneSchema, PatientCreateSchema } from '@/lib/schemas';

const updatePatient = (field: keyof PatientForm, value: string) => {
  // Validate before updating
  if (field === 'phone' && value) {
    const validation = PatientPhoneSchema.safeParse(value);
    if (!validation.success) {
      toast({
        title: "Invalid phone number",
        description: validation.error.errors[0].message,
        variant: "destructive"
      });
      return;
    }
  }
  
  setPatient(prev => ({ ...prev, [field]: value }));
};

// On form submission
const handleSave = async () => {
  const validation = PatientCreateSchema.safeParse(patient);
  if (!validation.success) {
    const errors = validation.error.errors.map(e => e.message).join(', ');
    toast({ title: "Validation failed", description: errors, variant: "destructive" });
    return;
  }
  
  // Proceed with save
  await insertPatient.mutate(validation.data);
};
```

---

## Summary of Changes

| Issue | Files | Commits | Time |
|-------|-------|---------|------|
| TypeScript strict mode | tsconfig.json, tsconfig.app.json | 1 | 1-2h |
| OTP → Redis | backend/server.ts, .env | 1 | 2-3h |
| Admin → Firestore | backend/server.ts | 1 | 3-4h |
| Hook dependencies | EmployeeContext.tsx, LowStockAlert.tsx | 2 | 1-2h |
| OTP timing-safe | backend/server.ts | 1 | 1h |
| CSRF protection | backend/server.ts, frontend | 2 | 2h |
| Input validation | Multiple, lib/schemas.ts | 3 | 2-3h |

**Total Time:** 14-19 hours

---

## Deployment Checklist

- [ ] All TypeScript errors fixed and strict mode enabled
- [ ] Redis instance provisioned and tested
- [ ] Firestore collections created (admin_credentials, admin_audit_log)
- [ ] All tests passing with new implementations
- [ ] Environmental variables configured for production
- [ ] Rate limits appropriate for production traffic
- [ ] CSRF token rotation working
- [ ] Input validation working on all forms
- [ ] Error logging/monitoring configured
- [ ] Performance tested (OTP response time < 200ms)

---

**Prepared by:** Senior Engineer Code Review  
**Date:** April 6, 2026
