# Database Schema & Security Architecture

## 1. PostgreSQL Schema Summary

Migrations live in `supabase/migrations/`:

1. **`20261118000001_initial_schema.sql`**
   - `public.profiles`: User identity, savings target fields, notification preferences, and server-protected Argon2id `pin_hash` + lockout fields (`pin_failed_attempts`, `pin_locked_until`, `pin_set_at`).
   - `public.transactions`: `id`, `user_id` (FK -> `profiles.id`), `client_id` (unique partial index per user for idempotent offline sync), `type` (`'saving' | 'expense'`), `amount` (`> 0`), `category`, `note` (`<= 140`), `occurred_at`, `created_at`, `updated_at`.
   - `public.streaks`: `user_id` (PK/FK -> `profiles.id`), `current_streak`, `longest_streak`, `total_active_days`, `last_active`.
   - `public.user_badges`: `id`, `user_id`, `badge_code`, `unlocked_at` (`UNIQUE (user_id, badge_code)`).
   - `public.audit_logs`: Append-only security & admin audit trail (no client access).
   - Indexes: `(user_id, occurred_at DESC, created_at DESC)`, `(user_id, type, occurred_at DESC)`, `(user_id, created_at DESC)`, unique partial index on `(user_id, client_id)`.

2. **`20261118000002_rls_and_security.sql`**
   - `ENABLE ROW LEVEL SECURITY` and `FORCE ROW LEVEL SECURITY` on **every** table.
   - Column-level privilege revocation prevents `authenticated` / `anon` from reading or updating `pin_hash`, `pin_failed_attempts`, `pin_locked_until`, or forging `pin_set_at`.
   - `streaks` and `user_badges` grant `SELECT` only to owners; clients cannot forge streaks or badges.
   - `audit_logs` revokes all privileges from `anon` and `authenticated`.
   - `on_auth_user_created` trigger provisions `profiles` and `streaks` atomically on sign-up.

3. **`20261118000003_streaks_badges_and_rpcs.sql`**
   - `trg_transactions_gamification`: Server-authoritative trigger updating daily streaks (in `Asia/Jakarta` WIB) and unlocking milestone badges automatically upon transaction insertion.
   - `get_financial_summary(p_months INT)`: `SECURITY INVOKER` RPC computing total savings, monthly savings/expenses, 6-month trend series, and category breakdown strictly under the caller's RLS scope.

## 2. OWASP Mobile & API Security Controls

| Control | Implementation |
|---|---|
| **M1 / API2: Authentication & Session** | Supabase PKCE Google OAuth with JWT + refresh token rotation (`supabase/config.toml`). Automatic session sign-out after 15 minutes of foreground or background inactivity (`InactivitySessionGuard`). |
| **PIN Protection (Argon2id)** | Plaintext PINs are never stored on device or logged. `pin-manage` and `pin-verify` Edge Functions hash with Argon2id (`m=19456` KiB, `t=2`, `p=1`, 16-byte CSPRNG salt) and compare in constant time. |
| **API4: Rate Limiting & Brute Force** | Supabase Auth rate limits configured in `config.toml`; PIN verification locks out for 15 minutes after 5 consecutive failed attempts (`HTTP 429 PIN_LOCKED`). |
| **API1 / BOLA Isolation** | Forced PostgreSQL RLS policies (`(SELECT auth.uid()) = user_id`) verified by `supabase/tests/rls_policies.sql`. |
| **M9: Secure Local Storage** | Cached profile/transactions, offline sync queue, and inactivity timestamps stored via `FlutterSecureStorage` (`encryptedSharedPreferences` on Android, Keychain `first_unlock_this_device` on iOS). Wiped on logout. |
| **API3 / Input Validation** | Dual validation (Flutter `InputValidators` + PostgreSQL `CHECK` constraints + `transactions-api` Edge Function allowlists and text sanitization). |
| **Safe Error Handling** | `ErrorMapper` and Edge Function `jsonError` return standardized `{ "error": "code", "message": "description" }` without exposing SQL errors, stack traces, or tokens. |
