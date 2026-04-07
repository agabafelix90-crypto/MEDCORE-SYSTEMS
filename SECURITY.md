# Security hardening checklist

## 1. Secret rotation
- Any existing Supabase service role or Firebase keys that were checked into source must be revoked immediately from the provider console.
- Generate new keys and store them in local `.env` (never commit `.env`).
- After rotation, restart backend and redeploy.

## 2. Environment variables
- `.env` is ignored by `.gitignore`.
- Use `.env.example` as a template.
- `SUPABASE_SERVICE_ROLE_KEY` must only be used in backend code (not in browser).

## 3. CORS
- In production, use `CORS_ALLOWED_ORIGINS=yourdomain` (no `*`).
- Dev-only default is `http://localhost:5173`.

## 4. Rate limiting
- Auth routes are protected with express-rate-limit (5 attempts per minute per IP).

## 5. Row Level Security
- Migration `supabase/migrations/20260403122000_enable_rls_and_own_row_policies.sql` enables RLS and creates policies that require ownership of rows.

## 6. Key exposure response
- External access should be audited via Supabase and Firebase logs.
- If keys were exposed, rotate keys + invalidate old sessions.
