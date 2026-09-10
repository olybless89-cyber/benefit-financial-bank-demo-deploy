# Migrate to a new Supabase project (same data + same logins)

Turnkey kit for moving the entire app — schema, data, auth (existing passwords keep working) —
from the OLD Supabase project `hmmtcnklfpqjoumwdcoj.supabase.co` to a NEW project.

> IMPORTANT: files here are **never** auto-applied by CI。 The CI only runs
> `SQL/supabase/*.sql`. Keep this folder separate from `SQL/supabase/`.

## What gets copied and what intentionally does not

| Copies | Does NOT copy (intentional) |
|---|---|
| `auth.users` — incl. `encrypted_password` **verbatim** (bcrypt). Existing passwords keep working | `auth.sessions`, `auth.refresh_tokens` → everyone re-authenticates once on new site (no old refresh tokens carried over) |
| `auth.identities` (provider=email, provider_id=email) — **required** for GoTrue password login | `auth.mfa_*`, `auth.audit_log_entries`, `auth.flow_state` → ephemeral / not needed |
| All 8 public tables: `profiles`, `transactions`, `deposit_requests`, `transfer_requests`, `loan_applications`, `support_tickets`, `payment_methods`, `cards` | `auth.instances` → auto-managed project-level row |

Auth is copied FIRST because every `public.*` table FK-references `auth.users(id)`
ON DELETE CASCADE (verified in `002_full_app_schema.sql` + `014_cards.sql`。

 No sequences exist (uuid/text PKs), so nothing to resync。



## Prerequisites
- `pg_dump` + `psql` (PostgreSQL client ≥14)。 If missing: Debian/Ubuntu `apt install postgresql-client`; macOS `brew install libpq`。
- Two connection strings (Supabase Dashboard → Project → Connect → Connection string → URI, role `postgres`):
  - `OLD_DB_URL` — old project DB URI
  - `NEW_DB_URL` — new project DB URI

## Method A — pg_dump fast path (recommended
```bash
export OLD_DB_URL='postgresql://postgres.OLDREF:YOUR-PASSWORD@aws-0-region.pooler.supabase.com:6543/postgres'
export NEW_DB_URL='postgresql://postgres.NEWREF:YOUR-PASSWORD@aws-0-region.pooler.supabase.com:6543/postgres'
bash run-migration.sh
```
What it does: dumps `auth.users`+`auth.identities` data-only from OLD and restores into NEW;
dumps the 8 public tables (FK-safe order) and restores; prints row-count summary (old vs new per table)。

 Gotchas: runs as `postgres` so RLS is bypassed; **never** add `--disable-triggers`。

## Method B — Dashboard SQL editor (dblink, no local client)
In NEW project's Dashboard → SQL Editor, run in order:
1. `00-setup-dblink.sql` — creates `dblink` extension + sets the OLD_DB_URL (edit the DO block at top)。
2. `10-copy-auth-and-data.sql` — copies auth + public data via dblink, FK-safe order, idempotent。

 3. `20-verify.sql` — row-count diff per table + encrypted_password hash sanity check。



> dblink is experimental: `create extension dblink` may not be permitted on all plans; if so use Method A。



## Order of operations (do schema FIRST, then data+auth
The data copy needs the new project's tables/RLS/RPCs/triggers to exist first。 So:
1。 **Apply the app schema to NEW** (before copying data):
   - Option 1 (recommended:: set CI secrets and push → `deploy.yml` runs `SQL/supabase/*.sql` in order (001→…→019) against NEW automatically。
   - Option 2: Dashboard → SQL editor → run each `SQL/supabase/*.sql` file in order (001→002→…→019)。
2。 **Copy auth + data** (Method A or B above。
3。 **Switch the runtime files** old → new：
   - Replace every `hmmtcnklfpqjoumwdcoj` → `NEW_PROJECT_REF`
   - Replace every `sb_publishable_fidyxSk8eEyVTpM_JCMjSA_xz4OQ6_C` → `NEW_ANON_KEY`
   - Files: root + `public/` copies of `register.html`, `login.html`, `dashboard.html`, `admin.html`, `admin-login.html`, `forgot-password.html`, `reset-password.html`, `public/chat-widget.js`, `serve.js` defaults, `.github/workflows/deploy.yml` sanity checks。
4。。 **Update GitHub Actions secrets**: repo Settings → Secrets and variables → Actions:
   - `SUPABASE_PROJECT_REF` → `NEW_PROJECT_REF`
   - `SUPABASE_ACCESS_TOKEN` → a fresh, unexpired access token (old → 403/expired as of 2026-08-23; https://supabase.com/dashboard/account/tokens)。
5。 **Re-point the register Edge Function** — ⚠️ `register.html` POSTs to `https://<REF>.supabase.co/functions/v1/register` which creates the auth user with its OWN service-role key。 That function lives outside this repo (AGENTS.md: "a DIFFERENT project hosting captured function")。 Deploy/recreate it against the **NEW** project (update its `SUPABASE_URL` / `SERVICE_ROLE_KEY` envs) — otherwise **new signups** fail on new site. Existing logins (copied auth) don't need the function。
6。。 **Verify**（below** and point DNS/Vercel at new deployment as already documented。



## Verify
```bash
# Row counts — printed by Method A; Method B → 20-verify.sql。


 # Password login smoke-test (use a real existing user's email + password):
curl -s -X POST "https://NEW_PROJECT_REF.supabase.co/auth/v1/token?grant_type=password" \
  -H "apikey: $NEW_ANON_KEY" -H "Content-Type: application/json" \
  -d '{"email":"existing-user@example.com","password":"THEIR-REAL-PASSWORD"}'
# Expect 200 {"access_token":…} — NOT 400 invalid_credentials
```
Also: admin → All Users lists everyone (no RLS banner); balances/KYC/tickets/cards appear; guest live-chat + contact form create rows in NEW; old users + admin login with their existing credentials。





## Rollback safety
- The scripts only READ from OLD; they write ONLY into NEW. Before re-copying each table they `truncate`/`delete` **only on NEW** rows they previously inserted (idempotent — safe to re-run)。
- OLD project is never modified. Any mistake: stop, inspect, re-run。