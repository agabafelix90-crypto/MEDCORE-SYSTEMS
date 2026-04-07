# 🔒 MEDICORE SECURITY GUIDE

## Environment Variables & Credential Management

### CRITICAL RULES

1. ⚠️ **NEVER commit `.env` file to Git** (even accidentally)
2. ⚠️ **NEVER hardcode credentials in source code**
3. ⚠️ **NEVER push real credentials to public repositories**
4. ⚠️ **NEVER expose Service Role keys in browser code**
5. ⚠️ **NEVER log sensitive values (tokens, keys, passwords)**

---

## Setup Instructions

### 1. Local Development Setup

```bash
# Copy the example env file
cp .env.example .env

# Edit .env with your actual values
# Get values from:
#   - Supabase Dashboard > Project Settings > API
#   - Firebase Console > Project Settings
nano .env  # or use your editor

# Verify .env is in .gitignore (should be - don't override!)
cat .gitignore | grep "^\.env$"
```

### 2. Required Environment Variables

#### Frontend (Safe to Expose)
```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...  # Anonymous/Anon key ONLY
VITE_SUPABASE_PROJECT_ID=your-project-id

VITE_FIREBASE_API_KEY=AIzaSy...
VITE_FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=your-project
VITE_FIREBASE_STORAGE_BUCKET=your-project.appspot.com
VITE_FIREBASE_MESSAGING_SENDER_ID=123456789
VITE_FIREBASE_APP_ID=1:123456789:web:...
```

#### Backend (Secret - Keep Private!)
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...  # Service Role key. NEVER in browser!

CORS_ALLOWED_ORIGINS=http://localhost:5173,http://localhost:3000  # Dev example
AUTH_REDIRECT_URL=https://your-domain.com/auth/callback
PORT=3000
NODE_ENV=development
```

---

## Credential Security Best Practices

### Supabase Credentials

**Anonymous Key (Safe for Browser)**:
- Used by `src/integrations/supabase/client.ts`
- Restricted by Row Level Security (RLS) policies
- Users can ONLY access their own clinic's data
- Safe to expose in build bundles

**Service Role Key (Secret - Backend Only)**:
- Used by `backend/server.ts` and Supabase Edge Functions
- Has full database access - CRITICAL to keep secret
- Never expose in browser, frontend code, or build bundles
- Store in:
  - Local `.env` file (dev only)
  - CI/CD secrets (GitHub Actions, GitLab CI, etc.)
  - Secure vault (HashiCorp Vault, AWS Secrets Manager, etc.)

### Firebase Credentials

**API Key (Safe for Browser)**:
- Public by design - visible in any Firebase app
- Secured by Firestore security rules (`firestore.rules`)
- Users can ONLY read/write as defined by rules
- Safe to expose

**Security Rules**:
- Located in `firestore.rules`
- Enforced by Firebase (not bypassed by exposing API key)
- Implement role-based access control

---

## CI/CD & Deployment

### GitHub Actions (or similar)

**DO THIS**: Use GitHub Secrets

```yaml
# .github/workflows/deploy.yml
env:
  SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
  SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
  
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: npm run build
        env:
          VITE_SUPABASE_URL: ${{ secrets.VITE_SUPABASE_URL }}
          VITE_SUPABASE_PUBLISHABLE_KEY: ${{ secrets.VITE_SUPABASE_PUBLISHABLE_KEY }}
```

**DON'T DO THIS**: Commit secrets to repo

```yaml
# ❌ WRONG - Never do this
env:
  SUPABASE_SERVICE_ROLE_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### Vercel/Netlify (Recommended for Frontend)

1. Go to Project Settings > Environment Variables
2. Add `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, etc.
3. Set `Available For` = Production/Preview/Development
4. Redeploy

**Never expose service role keys in frontend deployments.**

---

## Checking for Leaked Credentials

### If credentials are accidentally exposed:

1. **Rotate all keys immediately** (in Supabase & Firebase dashboards)
2. **Audit all access logs** for suspicious activity
3. **Check Git history** for accidental commits:
   ```bash
   git log --all --full-history -- .env
   git log --all --oneline | grep -i secret  # Look for commits mentioning credentials
   ```
4. **Force-remove from history** (if committed):
   ```bash
   git filter-branch --tree-filter 'rm -f .env' HEAD
   git push origin --force --all
   ```
5. **Notify security team** and audit records

---

## Code-Level Security

### Validating Credentials at Runtime

All clients validate that required env vars are present:

- `src/integrations/supabase/client.ts`: Validates Supabase config and rejects service role keys
- `src/lib/firebase.ts`: Validates Firebase config
- `backend/server.ts`: Validates Supabase credentials and CORS config

**These checks fail fast** and print helpful error messages if configuration is missing.

### Never Log Credentials

❌ **Wrong**:
```typescript
console.log("Supabase key:", SUPABASE_SERVICE_ROLE_KEY);
console.debug("Auth token:", token);
```

✅ **Right**:
```typescript
console.log("Supabase initialized"); // No sensitive data
if (error) {
  console.error("Auth failed", error.message); // Generic error only
}
```

---

## Verification Checklist

Before deploying to production:

- [ ] `.env` is in `.gitignore` and not committed
- [ ] `.env` file exists locally with real credentials
- [ ] Frontend uses ONLY anonymous/anon keys (not service role)
- [ ] Backend stores service role keys in secure env vars (not in code)
- [ ] CORS_ALLOWED_ORIGINS is set to specific domains (not `*`)
- [ ] Rate limiting is enabled on auth endpoints
- [ ] Error messages don't leak sensitive information
- [ ] Credentials are rotated before deployment
- [ ] CI/CD uses secrets management (GitHub Secrets, vault, etc.)
- [ ] No credentials in logs, error messages, or console output
- [ ] RLS policies enforce data isolation by clinic/user
- [ ] Firestore rules are deployed and enforced

---

## Additional Resources

- [Supabase Security Best Practices](https://supabase.com/docs/guides/security/overview)
- [Firebase Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [12-Factor App - Configuration](https://12factor.net/config)

---

## Questions?

If you're unsure whether something is a security risk:
1. Assume it IS a risk
2. Check with senior engineer or security team
3. Document the decision

**When in doubt, ask!**
